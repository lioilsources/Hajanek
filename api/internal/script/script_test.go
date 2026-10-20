package script

import (
	"encoding/json"
	"os"
	"testing"
)

type golden struct {
	VoiceID string `json:"voice_id"`
	Script  string `json:"script"`
	Items   []struct {
		Type    string  `json:"type"`
		Section string  `json:"section"`
		Tone    string  `json:"tone"`
		Text    string  `json:"text"`
		Key     string  `json:"key"`
		Seconds float64 `json:"seconds"`
	} `json:"items"`
}

func TestGolden(t *testing.T) {
	b, err := os.ReadFile("../../../docs/testdata/utterances.golden.json")
	if err != nil {
		t.Fatal(err)
	}
	var g golden
	if err := json.Unmarshal(b, &g); err != nil {
		t.Fatal(err)
	}
	s, err := Parse([]byte(g.Script))
	if err != nil {
		t.Fatal(err)
	}
	if len(s.Items) != len(g.Items) {
		t.Fatalf("items: got %d want %d: %+v", len(s.Items), len(g.Items), s.Items)
	}
	for i, want := range g.Items {
		got := s.Items[i]
		if string(got.Type) != want.Type {
			t.Fatalf("item %d: type %q want %q", i, got.Type, want.Type)
		}
		if got.Type == Pause {
			if got.Seconds != want.Seconds {
				t.Errorf("item %d: pause %g want %g", i, got.Seconds, want.Seconds)
			}
			continue
		}
		if got.Section != want.Section || string(got.Tone) != want.Tone || got.Text != want.Text {
			t.Errorf("item %d: got %s/%s/%q want %s/%s/%q", i, got.Section, got.Tone, got.Text, want.Section, want.Tone, want.Text)
		}
		if k := Key(g.VoiceID, got.Tone, got.Text); k != want.Key {
			t.Errorf("item %d: key %s want %s", i, k, want.Key)
		}
	}
	if n := len(s.Keys(g.VoiceID)); n != 9 {
		t.Errorf("distinct keys: %d", n)
	}
}

func TestNormalizeNFC(t *testing.T) {
	// "\u010D" decomposed (c + combining caron) must key like the precomposed form.
	if Normalize("  c\u030Cau \t svete ") != "\u010Dau svete" {
		t.Fatalf("got %q", Normalize("c\u030Cau"))
	}
}

func TestParseErrors(t *testing.T) {
	for name, src := range map[string]string{
		"missing sections": "## uvod\nAhoj.\n",
		"wrong order":      "## vstup\nAhoj.\n",
		"bad pause":        "## uvod\n[pause 2]\n",
		"before section":   "Ahoj.\n## uvod\n",
		"unterminated fm":  "---\nid: x\n",
	} {
		if _, err := Parse([]byte(src)); err == nil {
			t.Errorf("%s: expected error", name)
		}
	}
}
