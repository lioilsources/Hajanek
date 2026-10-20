package script

import (
	"encoding/json"
	"math"
	"os"
	"reflect"
	"strings"
	"testing"
)

const header = `---
id: test
title: Test
length_min: 10
status: reviewed
---
`

const valid = header + `
<!-- comment
spanning lines -->
## uvod
[soft] Lehni si, {{osloveni|broučku}}.
[pause 3s]
Druhá věta.

## vstup
[slow] Pomalá věta.
Pořád pomalá.
[pause 1.5s]

## pribeh
Zase měkce.
[whisper]
Šeptem bez značky na řádku.

## dojezd
[slow] Usínáme.
Ještě pomalu.
[whisper] Dobrou noc, {{ osloveni | broučku }}.
[pause 10s]
`

func TestParseValid(t *testing.T) {
	s, err := Parse([]byte(valid))
	if err != nil {
		t.Fatal(err)
	}
	if s.Meta.ID != "test" || s.Meta.LengthMin != 10 || s.Meta.Status != "reviewed" {
		t.Fatalf("meta: %+v", s.Meta)
	}
	type exp struct {
		sec  string
		tone Tone
		text string
	}
	want := []exp{
		{"uvod", Soft, "Lehni si, broučku."},
		{"uvod", Soft, "Druhá věta."},
		{"vstup", Slow, "Pomalá věta."},
		{"vstup", Slow, "Pořád pomalá."}, // tone persists within section
		{"pribeh", Soft, "Zase měkce."},  // resets at section boundary
		{"pribeh", Whisper, "Šeptem bez značky na řádku."},
		{"dojezd", Slow, "Usínáme."},
		{"dojezd", Slow, "Ještě pomalu."},
		{"dojezd", Whisper, "Dobrou noc, broučku."},
	}
	us := s.Utterances()
	if len(us) != len(want) {
		t.Fatalf("got %d utterances, want %d", len(us), len(want))
	}
	for i, w := range want {
		if us[i].Section != w.sec || us[i].Tone != w.tone || us[i].Text != w.text {
			t.Errorf("utt %d = %s/%s/%q, want %s/%s/%q", i, us[i].Section, us[i].Tone, us[i].Text, w.sec, w.tone, w.text)
		}
	}
	if !us[0].HasPlaceholder || us[1].HasPlaceholder {
		t.Error("placeholder flag wrong")
	}
	var pauses []float64
	for _, it := range s.Items {
		if it.Kind == Pause {
			pauses = append(pauses, it.PauseS)
		}
	}
	if len(pauses) != 3 || pauses[1] != 1.5 || pauses[2] != 10 {
		t.Errorf("pauses = %v", pauses)
	}
	// Line numbers survive comment stripping.
	if us[0].Line != 11 {
		t.Errorf("first utterance line = %d, want 11", us[0].Line)
	}
}

func TestParseErrors(t *testing.T) {
	cases := map[string]string{
		"order":          header + "## vstup\nA.\n## uvod\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"missing":        header + "## uvod\nA.\n## vstup\nB.\n## pribeh\nC.\n",
		"placeholder":    header + "## uvod\nA.\n## vstup\nB.\n## pribeh\nAhoj {{osloveni|broučku}}.\n## dojezd\nD.\n",
		"unknown ph":     header + "## uvod\n{{jmeno|Ty}} spinkáš.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"no fallback":    header + "## uvod\nAhoj {{osloveni}}.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"inline pause":   header + "## uvod\nA. [pause 2s]\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"unknown tag":    header + "## uvod\n[loud] A.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"empty section":  header + "## uvod\n[pause 2s]\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"before section": header + "Úvodní text.\n## uvod\nA.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"bad heading":    header + "# Titulek\n## uvod\nA.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"no front":       "## uvod\nA.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
		"bad status":     strings.Replace(header, "reviewed", "done", 1) + "## uvod\nA.\n## vstup\nB.\n## pribeh\nC.\n## dojezd\nD.\n",
	}
	for name, src := range cases {
		if _, err := Parse([]byte(src)); err == nil {
			t.Errorf("%s: expected error", name)
		}
	}
}

func testProsody() Prosody {
	return Prosody{Speeds: map[Tone]float64{Soft: 0.85, Slow: 0.78, Whisper: 0.75}, RampSection: "dojezd", RampSpeedTo: 0.75}
}

func TestPlanRamp(t *testing.T) {
	src := header + "## uvod\nA.\n## vstup\n[slow] B.\n## pribeh\n[whisper] C.\n## dojezd\nD1.\nD2.\nD3.\n[whisper] D4.\n"
	s, err := Parse([]byte(src))
	if err != nil {
		t.Fatal(err)
	}
	p := testProsody().Plan(s)
	var got []float64
	for i, it := range s.Items {
		if it.Kind == Utterance {
			got = append(got, p[i])
		}
	}
	want := []float64{
		0.85, 0.78, 0.75, // tone mapping outside dojezd
		0.85, 0.85 - 0.1/3, 0.85 - 0.2/3, // linear ramp in dojezd
		0.75, // whisper never faster than its tone
	}
	for i, w := range want {
		if math.Abs(got[i]-w) > 1e-9 {
			t.Errorf("utt %d: speed %.4f, want %.4f", i, got[i], w)
		}
	}
}

func TestEstimate(t *testing.T) {
	// 19 words at soft (0.85 = ref speed, 95 wpm) = 12 s, + 2 gaps of 0.5 s + 3 s pause.
	src := header + "## uvod\njedna dva tři čtyři pět šest sedm osm devět deset.\n[pause 3s]\n## vstup\na b c d e f g h i.\n## pribeh\n## dojezd\n"
	s, _ := Parse([]byte(src))
	p := testProsody()
	p.RampSection = ""
	e := p.Estimate(s, EstimateParams{WPM: 95, RefSpeed: 0.85, GapS: 0.5})
	if e.Words != 19 {
		t.Fatalf("words = %d", e.Words)
	}
	if math.Abs(e.TotalS-(12+1+3)) > 1e-6 {
		t.Errorf("total = %.3f, want 16", e.TotalS)
	}
	if math.Abs(e.SectionsS["uvod"]-(10*60.0/95+0.5+3)) > 1e-6 {
		t.Errorf("uvod = %.3f", e.SectionsS["uvod"])
	}
	// Slower tone → longer estimate.
	s2, _ := Parse([]byte(strings.Replace(src, "## vstup\n", "## vstup\n[slow] ", 1)))
	if e2 := p.Estimate(s2, EstimateParams{WPM: 95, RefSpeed: 0.85, GapS: 0.5}); e2.TotalS <= e.TotalS {
		t.Errorf("slow tone should lengthen estimate: %.2f <= %.2f", e2.TotalS, e.TotalS)
	}
}

func TestWords(t *testing.T) {
	if n := len(Words("Šššš… Klap, klap. A všechno je v pořádku!")); n != 8 {
		t.Errorf("Words = %d, want 8", n)
	}
}

// TestGoldenUtterances checks the sequence and keys against the shared golden
// file that the Dart parser in app/ is tested against too (CONTRACTS §7).
func TestGoldenUtterances(t *testing.T) {
	b, err := os.ReadFile("../../../docs/testdata/utterances.golden.json")
	if err != nil {
		t.Fatal(err)
	}
	var g struct {
		VoiceID string `json:"voice_id"`
		Script  string `json:"script"`
		Items   []Step `json:"items"`
	}
	if err := json.Unmarshal(b, &g); err != nil {
		t.Fatal(err)
	}
	s, err := Parse([]byte(g.Script))
	if err != nil {
		t.Fatal(err)
	}
	got := s.Sequence(g.VoiceID)
	if len(got) != len(g.Items) {
		t.Fatalf("got %d items, want %d", len(got), len(g.Items))
	}
	for i := range got {
		if !reflect.DeepEqual(got[i], g.Items[i]) {
			t.Errorf("item %d:\n got %+v\nwant %+v", i, got[i], g.Items[i])
		}
	}
}

func TestNormalizeText(t *testing.T) {
	// "S" + combining caron (NFD) → "Š" (NFC); tabs/NBSP-free runs collapse.
	if got := NormalizeText("  S\u030cel \t\tdál  "); got != "\u0160el dál" {
		t.Errorf("NormalizeText = %q", got)
	}
	if UtteranceKey("v", Soft, "a") == UtteranceKey("v", Slow, "a") {
		t.Error("tone must be part of the key")
	}
}
