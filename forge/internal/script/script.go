// Package script parses meditation scripts (CONTRACTS §2).
package script

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"gopkg.in/yaml.v3"
)

type Tone string

const (
	Soft    Tone = "soft"
	Slow    Tone = "slow"
	Whisper Tone = "whisper"
)

// Sections in mandatory order.
var Sections = []string{"uvod", "vstup", "pribeh", "dojezd"}

// PlaceholderName is the only allowed placeholder ({{osloveni|fallback}}).
const PlaceholderName = "osloveni"

// placeholderSections are the sections where the placeholder may appear.
var placeholderSections = map[string]bool{"uvod": true, "dojezd": true}

type Meta struct {
	ID              string   `yaml:"id" json:"id"`
	Title           string   `yaml:"title" json:"title"`
	Source          string   `yaml:"source" json:"source,omitempty"`
	Age             string   `yaml:"age" json:"age,omitempty"`
	Setting         string   `yaml:"setting" json:"setting,omitempty"`
	Ambient         string   `yaml:"ambient" json:"ambient,omitempty"`
	LengthMin       int      `yaml:"length_min" json:"length_min"`
	TensionOriginal int      `yaml:"tension_original" json:"tension_original"`
	Characters      []string `yaml:"characters" json:"characters,omitempty"`
	Free            *bool    `yaml:"free" json:"free,omitempty"`
	Status          string   `yaml:"status" json:"status,omitempty"` // draft | reviewed | gold
}

type Kind int

const (
	Utterance Kind = iota
	Pause
)

type Item struct {
	Kind    Kind
	Section string
	Line    int
	// Utterance fields.
	Tone           Tone
	Text           string // rendered with placeholder fallbacks
	Raw            string // text as written (without tone marker)
	HasPlaceholder bool
	// Pause field.
	PauseS float64
}

type Script struct {
	Meta  Meta
	Items []Item
}

type Error struct {
	Line int
	Msg  string
}

func (e Error) Error() string { return fmt.Sprintf("line %d: %s", e.Line, e.Msg) }

type Errors []Error

func (es Errors) Error() string {
	s := make([]string, len(es))
	for i, e := range es {
		s[i] = e.Error()
	}
	return strings.Join(s, "; ")
}

var (
	reComment     = regexp.MustCompile(`(?s)<!--.*?-->`)
	rePause       = regexp.MustCompile(`^\[pause\s+(\d+(?:\.\d+)?)\s*s\]$`)
	reTone        = regexp.MustCompile(`^\[(soft|slow|whisper)\]\s*`)
	rePlaceholder = regexp.MustCompile(`\{\{\s*([^{}|]*?)\s*(?:\|([^{}]*))?\}\}`)
	reHeading     = regexp.MustCompile(`^#+\s*(.*?)\s*$`)
)

// Parse parses a script. On error it returns the partially parsed script and Errors.
func Parse(src []byte) (*Script, error) {
	text := strings.ReplaceAll(string(src), "\r\n", "\n")
	text = strings.TrimPrefix(text, "\uFEFF")
	// Strip comments but keep line numbering.
	text = reComment.ReplaceAllStringFunc(text, func(m string) string {
		return strings.Repeat("\n", strings.Count(m, "\n"))
	})
	lines := strings.Split(text, "\n")
	s := &Script{}
	var errs Errors
	add := func(line int, f string, a ...any) { errs = append(errs, Error{line, fmt.Sprintf(f, a...)}) }

	start := 0
	if len(lines) == 0 || strings.TrimSpace(lines[0]) != "---" {
		add(1, "missing YAML front matter (must start with ---)")
	} else {
		end := -1
		for i := 1; i < len(lines); i++ {
			if strings.TrimSpace(lines[i]) == "---" {
				end = i
				break
			}
		}
		if end < 0 {
			add(1, "unterminated front matter")
			return s, errs
		}
		fm := strings.Join(lines[1:end], "\n")
		if err := yaml.Unmarshal([]byte(fm), &s.Meta); err != nil {
			add(2, "front matter: %v", err)
		}
		if s.Meta.ID == "" {
			add(2, "front matter: missing id")
		}
		if s.Meta.Title == "" {
			add(2, "front matter: missing title")
		}
		switch s.Meta.Status {
		case "", "draft", "reviewed", "gold":
		default:
			add(2, "front matter: invalid status %q (draft|reviewed|gold)", s.Meta.Status)
		}
		if s.Meta.LengthMin <= 0 {
			add(2, "front matter: missing/invalid length_min")
		}
		start = end + 1
	}

	secIdx := -1
	section := ""
	tone := Soft
	counts := map[string]int{}
	for i := start; i < len(lines); i++ {
		ln := i + 1
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "#") {
			m := reHeading.FindStringSubmatch(line)
			name := strings.ToLower(m[1])
			if !strings.HasPrefix(line, "## ") {
				add(ln, "only '## section' headings allowed, got %q", line)
				continue
			}
			if secIdx+1 >= len(Sections) || name != Sections[secIdx+1] {
				want := "end of script"
				if secIdx+1 < len(Sections) {
					want = Sections[secIdx+1]
				}
				add(ln, "unexpected section %q, expected %q", name, want)
				// Resync if the name is a known later section.
				for j := secIdx + 1; j < len(Sections); j++ {
					if Sections[j] == name {
						secIdx = j
						section = name
						tone = Soft
					}
				}
				continue
			}
			secIdx++
			section = name
			tone = Soft
			continue
		}
		if section == "" {
			add(ln, "content before first section")
			continue
		}
		if m := rePause.FindStringSubmatch(line); m != nil {
			v, _ := strconv.ParseFloat(m[1], 64)
			if v <= 0 {
				add(ln, "pause must be > 0")
			}
			s.Items = append(s.Items, Item{Kind: Pause, Section: section, Line: ln, PauseS: v})
			continue
		}
		if strings.Contains(line, "[pause") {
			add(ln, "[pause Ns] must be on its own line and well-formed")
			continue
		}
		if m := reTone.FindStringSubmatch(line); m != nil {
			tone = Tone(m[1])
			line = strings.TrimSpace(line[len(m[0]):])
			if line == "" {
				continue // bare tone marker switches tone only
			}
		}
		if strings.ContainsAny(line, "[]") {
			add(ln, "unknown or misplaced markup in %q", line)
			continue
		}
		raw := line
		hasPH := false
		rendered := rePlaceholder.ReplaceAllStringFunc(line, func(ph string) string {
			m := rePlaceholder.FindStringSubmatch(ph)
			hasPH = true
			if m[1] != PlaceholderName {
				add(ln, "unknown placeholder %q (only {{%s|fallback}})", m[1], PlaceholderName)
			}
			if strings.TrimSpace(m[2]) == "" {
				add(ln, "placeholder without fallback")
			}
			return strings.TrimSpace(m[2])
		})
		if strings.Contains(rendered, "{{") || strings.Contains(rendered, "}}") {
			add(ln, "malformed placeholder")
		}
		if hasPH && !placeholderSections[section] {
			add(ln, "{{%s}} only allowed in uvod and dojezd (found in %s)", PlaceholderName, section)
		}
		counts[section]++
		s.Items = append(s.Items, Item{Kind: Utterance, Section: section, Line: ln, Tone: tone,
			Text: rendered, Raw: raw, HasPlaceholder: hasPH})
	}
	if secIdx < len(Sections)-1 {
		add(len(lines), "missing sections: %s", strings.Join(Sections[secIdx+1:], ", "))
	}
	for _, sec := range Sections[:secIdx+1] {
		if counts[sec] == 0 {
			add(len(lines), "section %s has no utterances", sec)
		}
	}
	if len(errs) > 0 {
		return s, errs
	}
	return s, nil
}

// Utterances returns only utterance items.
func (s *Script) Utterances() []Item {
	var out []Item
	for _, it := range s.Items {
		if it.Kind == Utterance {
			out = append(out, it)
		}
	}
	return out
}

// PlainText returns the spoken text (fallbacks applied), one utterance per line.
func (s *Script) PlainText() string {
	var b strings.Builder
	for _, u := range s.Utterances() {
		b.WriteString(u.Text)
		b.WriteByte('\n')
	}
	return b.String()
}

// Words splits text into word tokens (letters/digits only).
func Words(text string) []string {
	return strings.FieldsFunc(text, func(r rune) bool {
		return !isLetter(r) && (r < '0' || r > '9')
	})
}

func isLetter(r rune) bool { return unicode.IsLetter(r) }
