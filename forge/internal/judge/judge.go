// Package judge runs deterministic quality checks on meditation scripts.
package judge

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/lioilsources/hajanek/forge/internal/script"
)

// DefaultForbidden is used when content/prompts/forbidden_words.txt is missing.
// Entries are case-insensitive word prefixes (stems); entries containing a space
// are matched as substrings; a trailing "=" (e.g. "umře=") requires an exact word.
var DefaultForbidden = []string{
	"pozor", "strach", "strašn", "straš", "bojí", "bál", "lekl", "vyděs", "hrůz",
	"krev", "krvav", "krve", "zabi", "zabít", "zabij", "sežr", "sníst", "snědl", "spolkl",
	"smrt", "umř", "umře", "mrtv", "zemř", "zemře", "křič", "křik", "řval", "nebezpe",
	"honem", "rychle", "najednou", "utíkej", "uteč", "pláč", "plakal", "zlý", "zlá", "zlé", "zlou",
	"bolest", "bolí", "ublíž", "zbraň", "střel", "zranil",
}

type Config struct {
	LengthMin        int
	WPM              float64
	RefSpeed         float64
	GapS             float64
	Tolerance        float64
	MaxSentenceWords int
	Budgets10        map[string][2]float64
	Forbidden        []string
	Prosody          script.Prosody
}

type Report struct {
	File      string          `json:"file"`
	OK        bool            `json:"ok"`
	Errors    []string        `json:"errors"`
	Warnings  []string        `json:"warnings"`
	LengthMin int             `json:"length_min"`
	TargetS   float64         `json:"target_s"`
	Estimate  script.Estimate `json:"estimate"`
	Pauses    map[string]any  `json:"pauses,omitempty"`
	LLM       *LLMResult      `json:"llm,omitempty"`
}

func (r *Report) errf(f string, a ...any)  { r.Errors = append(r.Errors, fmt.Sprintf(f, a...)) }
func (r *Report) warnf(f string, a ...any) { r.Warnings = append(r.Warnings, fmt.Sprintf(f, a...)) }

// LoadForbidden reads a word list (one per line, '#' comments); falls back to DefaultForbidden.
func LoadForbidden(path string) []string {
	f, err := os.Open(path)
	if err != nil {
		return DefaultForbidden
	}
	defer func() { _ = f.Close() }()
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		l := strings.TrimSpace(sc.Text())
		if l == "" || strings.HasPrefix(l, "#") {
			continue
		}
		out = append(out, strings.ToLower(l))
	}
	if len(out) == 0 {
		return DefaultForbidden
	}
	return out
}

var reSentenceEnd = regexp.MustCompile(`[.!?…]+`)

// Check runs all deterministic checks. src is the raw script file content.
func Check(file string, src []byte, cfg Config) *Report {
	r := &Report{File: file, Errors: []string{}, Warnings: []string{}}
	s, err := script.Parse(src)
	if err != nil {
		if es, ok := err.(script.Errors); ok {
			for _, e := range es {
				r.errf("parse: %s", e.Error())
			}
		} else {
			r.errf("parse: %v", err)
		}
	}
	if s == nil {
		return r
	}
	length := cfg.LengthMin
	if length == 0 {
		length = s.Meta.LengthMin
	}
	if cfg.LengthMin != 0 && s.Meta.LengthMin != 0 && s.Meta.LengthMin != cfg.LengthMin {
		r.errf("front matter length_min=%d but target is %d", s.Meta.LengthMin, cfg.LengthMin)
	}
	r.LengthMin = length
	r.TargetS = float64(length) * 60

	// Duration estimate.
	r.Estimate = cfg.Prosody.Estimate(s, script.EstimateParams{WPM: cfg.WPM, RefSpeed: cfg.RefSpeed, GapS: cfg.GapS})
	if r.TargetS > 0 {
		dev := (r.Estimate.TotalS - r.TargetS) / r.TargetS
		if math.Abs(dev) > cfg.Tolerance {
			r.errf("estimated duration %.0fs deviates %+.0f%% from target %.0fs (max ±%.0f%%)",
				r.Estimate.TotalS, dev*100, r.TargetS, cfg.Tolerance*100)
		}
		scale := float64(length) / 10
		for _, sec := range script.Sections {
			b, ok := cfg.Budgets10[sec]
			if !ok {
				continue
			}
			lo, hi := b[0]*scale, b[1]*scale
			got := r.Estimate.SectionsS[sec]
			if got < lo || got > hi {
				r.errf("section %s estimated %.0fs outside budget %.0f–%.0fs", sec, got, lo, hi)
			}
		}
	}

	forb := cfg.Forbidden
	if forb == nil {
		forb = DefaultForbidden
	}
	whisperInLast := false
	for _, it := range s.Items {
		if it.Kind != script.Utterance {
			continue
		}
		if it.Section == "dojezd" && it.Tone == script.Whisper {
			whisperInLast = true
		}
		if strings.Contains(it.Text, "?") {
			r.errf("line %d: question mark not allowed: %q", it.Line, it.Text)
		}
		for _, w := range matchForbidden(it.Text, forb) {
			r.errf("line %d: forbidden word %q", it.Line, w)
		}
		for _, sent := range reSentenceEnd.Split(it.Text, -1) {
			if n := len(script.Words(sent)); n > cfg.MaxSentenceWords {
				r.errf("line %d: sentence has %d words (max %d): %q", it.Line, n, cfg.MaxSentenceWords, strings.TrimSpace(sent))
			}
		}
	}
	if !whisperInLast {
		r.errf("section dojezd has no [whisper] utterance")
	}
	checkPauses(s, r)
	r.OK = len(r.Errors) == 0
	return r
}

func matchForbidden(text string, forb []string) []string {
	var hits []string
	lower := strings.ToLower(text)
	words := script.Words(lower)
	for _, f := range forb {
		switch {
		case strings.Contains(f, " "):
			if strings.Contains(lower, f) {
				hits = append(hits, f)
			}
		case strings.HasSuffix(f, "="):
			exact := strings.TrimSuffix(f, "=")
			for _, w := range words {
				if w == exact {
					hits = append(hits, w)
					break
				}
			}
		default:
			for _, w := range words {
				if strings.HasPrefix(w, f) {
					hits = append(hits, w)
					break
				}
			}
		}
	}
	// dedupe
	sort.Strings(hits)
	out := hits[:0]
	for i, h := range hits {
		if i == 0 || hits[i-1] != h {
			out = append(out, h)
		}
	}
	return out
}

// checkPauses verifies the dynamics slow down toward the end: dojezd pauses
// are on average at least as long as in the story and contain the longest one.
func checkPauses(s *script.Script, r *Report) {
	per := map[string][]float64{}
	for _, it := range s.Items {
		if it.Kind == script.Pause {
			per[it.Section] = append(per[it.Section], it.PauseS)
		}
	}
	stats := map[string]any{}
	avg := map[string]float64{}
	mx := map[string]float64{}
	for _, sec := range script.Sections {
		p := per[sec]
		if len(p) == 0 {
			continue
		}
		sum := 0.0
		for _, v := range p {
			sum += v
			mx[sec] = math.Max(mx[sec], v)
		}
		avg[sec] = sum / float64(len(p))
		stats[sec] = map[string]float64{"count": float64(len(p)), "avg_s": round1(avg[sec]), "max_s": mx[sec]}
	}
	r.Pauses = stats
	if len(per["dojezd"]) == 0 {
		r.errf("dojezd has no pauses")
		return
	}
	if avg["dojezd"] < avg["pribeh"] {
		r.errf("pauses must grow toward the end: avg dojezd %.1fs < avg pribeh %.1fs", avg["dojezd"], avg["pribeh"])
	}
	if mx["dojezd"] < mx["pribeh"] || mx["dojezd"] < mx["uvod"] || mx["dojezd"] < mx["vstup"] {
		r.errf("longest pause must be in dojezd (dojezd max %.1fs)", mx["dojezd"])
	}
	// Within dojezd the trend should not decrease.
	if p := per["dojezd"]; len(p) >= 3 && slope(p) < 0 {
		r.warnf("pauses in dojezd get shorter toward the end (slope %.2f)", slope(p))
	}
	if p := per["pribeh"]; len(p) >= 4 {
		h := len(p) / 2
		if mean(p[h:]) < mean(p[:h])*0.8 {
			r.warnf("pauses in second half of pribeh are shorter than in first half")
		}
	}
	last := s.Items[len(s.Items)-1]
	if last.Kind != script.Pause {
		r.warnf("script should end with a [pause]")
	}
}

func mean(v []float64) float64 {
	s := 0.0
	for _, x := range v {
		s += x
	}
	return s / float64(len(v))
}

func slope(v []float64) float64 {
	n := float64(len(v))
	mx, my := (n-1)/2, mean(v)
	var num, den float64
	for i, y := range v {
		num += (float64(i) - mx) * (y - my)
		den += (float64(i) - mx) * (float64(i) - mx)
	}
	return num / den
}

func round1(f float64) float64 { return math.Round(f*10) / 10 }
