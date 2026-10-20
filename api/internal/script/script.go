// Package script extracts utterances from a meditation script
// (CONTRACTS.md §2) and computes their utterance keys (§7).
//
// The API only needs what is spoken and in which tone, so this parser is
// deliberately smaller than forge's: front matter is skipped, not decoded.
// The rules that affect utterance keys (tone reset per section, osloveni →
// fallback, whitespace collapse, NFC) must stay identical to forge and app;
// all three are tested against docs/testdata/utterances.golden.json.
package script

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"golang.org/x/text/unicode/norm"
)

type Tone string

const (
	Soft    Tone = "soft"
	Slow    Tone = "slow"
	Whisper Tone = "whisper"
)

// Sections in their mandatory order.
var Sections = []string{"uvod", "vstup", "pribeh", "dojezd"}

type ItemType string

const (
	Utterance ItemType = "utterance"
	Pause     ItemType = "pause"
)

// Item is one utterance or pause, in script order.
type Item struct {
	Type    ItemType
	Section string
	Tone    Tone    // utterance only
	Text    string  // utterance only, normalized (§7)
	Seconds float64 // pause only
}

type Script struct {
	Items []Item
}

var (
	reComment     = regexp.MustCompile(`(?s)<!--.*?-->`)
	rePause       = regexp.MustCompile(`^\[pause\s+(\d+(?:\.\d+)?)\s*s\]$`)
	reTone        = regexp.MustCompile(`^\[(soft|slow|whisper)\]`)
	rePlaceholder = regexp.MustCompile(`\{\{[^{}|]*\|([^{}]*)\}\}`)
	reHeading     = regexp.MustCompile(`^##\s+(\S+)\s*$`)
)

// Parse extracts utterances and pauses. It fails on structural errors that
// would make keys ambiguous (wrong sections, malformed pauses).
func Parse(src []byte) (*Script, error) {
	text := strings.TrimPrefix(strings.ReplaceAll(string(src), "\r\n", "\n"), "\uFEFF")
	text = reComment.ReplaceAllString(text, "\n")
	lines := strings.Split(text, "\n")

	start := 0
	if len(lines) > 0 && strings.TrimSpace(lines[0]) == "---" {
		end := -1
		for i := 1; i < len(lines); i++ {
			if strings.TrimSpace(lines[i]) == "---" {
				end = i
				break
			}
		}
		if end < 0 {
			return nil, fmt.Errorf("unterminated front matter")
		}
		start = end + 1
	}

	s := &Script{}
	secIdx := -1
	tone := Soft
	for i := start; i < len(lines); i++ {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "#") {
			m := reHeading.FindStringSubmatch(line)
			if m == nil || secIdx+1 >= len(Sections) || strings.ToLower(m[1]) != Sections[secIdx+1] {
				return nil, fmt.Errorf("line %d: unexpected heading %q", i+1, line)
			}
			secIdx++
			tone = Soft // tone resets at every section
			continue
		}
		if secIdx < 0 {
			return nil, fmt.Errorf("line %d: content before first section", i+1)
		}
		section := Sections[secIdx]
		if m := rePause.FindStringSubmatch(line); m != nil {
			v, err := strconv.ParseFloat(m[1], 64)
			if err != nil || v <= 0 {
				return nil, fmt.Errorf("line %d: invalid pause", i+1)
			}
			s.Items = append(s.Items, Item{Type: Pause, Section: section, Seconds: v})
			continue
		}
		if strings.HasPrefix(line, "[pause") {
			return nil, fmt.Errorf("line %d: malformed pause %q", i+1, line)
		}
		if m := reTone.FindStringSubmatch(line); m != nil {
			tone = Tone(m[1])
			line = line[len(m[0]):]
		}
		line = rePlaceholder.ReplaceAllStringFunc(line, func(ph string) string {
			return rePlaceholder.FindStringSubmatch(ph)[1]
		})
		norm := Normalize(line)
		if norm == "" {
			continue // a bare tone marker only switches the tone
		}
		s.Items = append(s.Items, Item{Type: Utterance, Section: section, Tone: tone, Text: norm})
	}
	if secIdx != len(Sections)-1 {
		return nil, fmt.Errorf("missing sections: %s", strings.Join(Sections[secIdx+1:], ", "))
	}
	return s, nil
}

// Normalize trims, collapses whitespace runs to one space and applies NFC.
func Normalize(text string) string {
	return norm.NFC.String(strings.Join(strings.Fields(text), " "))
}

// Key is the utterance key from CONTRACTS.md §7.
func Key(voiceID string, tone Tone, text string) string {
	sum := sha256.Sum256([]byte(voiceID + "\x1f" + string(tone) + "\x1f" + text))
	return hex.EncodeToString(sum[:])
}

// Keys returns the distinct utterance keys of the script for voiceID, in
// first-occurrence order (repeated lines share one clip).
func (s *Script) Keys(voiceID string) []string {
	seen := map[string]bool{}
	var out []string
	for _, it := range s.Items {
		if it.Type != Utterance {
			continue
		}
		k := Key(voiceID, it.Tone, it.Text)
		if !seen[k] {
			seen[k] = true
			out = append(out, k)
		}
	}
	return out
}
