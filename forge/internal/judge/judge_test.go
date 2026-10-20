package judge

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/lioilsources/hajanek/forge/internal/llm"
	"github.com/lioilsources/hajanek/forge/internal/script"
)

func cfg(length int) Config {
	return Config{
		LengthMin: length, WPM: 95, RefSpeed: 0.85, GapS: 0.6, Tolerance: 0.15, MaxSentenceWords: 18,
		Budgets10: map[string][2]float64{"uvod": {50, 100}, "vstup": {40, 80}, "pribeh": {270, 450}, "dojezd": {70, 130}},
		Prosody: script.Prosody{
			Tones: map[script.Tone]script.ToneParams{
				script.Soft: {Speed: 0.85}, script.Slow: {Speed: 0.78, GainDB: -3}, script.Whisper: {Speed: 0.75, GainDB: -10},
			},
			RampSection: "dojezd", RampSpeedTo: 0.75, RampGainToDB: -6,
		},
	}
}

func fixture(t *testing.T) []byte {
	b, err := os.ReadFile("../../testdata/content/scripts/test-pohadka.2.md")
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func hasErr(r *Report, sub string) bool {
	for _, e := range r.Errors {
		if strings.Contains(e, sub) {
			return true
		}
	}
	return false
}

func TestFixturePasses(t *testing.T) {
	r := Check("fixture", fixture(t), cfg(2))
	if !r.OK {
		t.Fatalf("fixture should pass: %v", r.Errors)
	}
}

func TestGoldScriptsPass(t *testing.T) {
	files, _ := filepath.Glob("../../../content/scripts/gold/*.md")
	if len(files) == 0 {
		t.Skip("no gold scripts in content/")
	}
	forb := LoadForbidden("../../../content/prompts/forbidden_words.txt")
	for _, f := range files {
		b, _ := os.ReadFile(f)
		c := cfg(0)
		c.Forbidden = forb
		if r := Check(f, b, c); !r.OK {
			t.Errorf("%s: %v", f, r.Errors)
		}
	}
}

func TestRules(t *testing.T) {
	base := string(fixture(t))
	cases := []struct {
		name, from, to, want string
	}{
		{"forbidden prefix", "Měsíc svítí a louka spinká.", "Měsíc svítí a vlk ho chce sníst.", "forbidden word"},
		{"forbidden stem", "Měsíc svítí a louka spinká.", "Ježek měl strachy.", "forbidden word"},
		{"question", "Měsíc svítí a louka spinká.", "Slyšíš cvrčky?", "question mark"},
		{"long sentence", "Měsíc svítí a louka spinká.",
			"Měsíc svítí a louka spinká a tráva voní a cvrčci cvrkají a vítr fouká a ježek spí a my taky.", "sentence has"},
		{"no whisper", "[whisper] A Hajánek", "A Hajánek", "no [whisper]"},
		{"placeholder in pribeh", "Na louce bydlí malý ježek.", "Na louce bydlí malý ježek, {{osloveni|broučku}}.", "only allowed in uvod and dojezd"},
		{"pauses shrink", "[pause 6s]\n", "[pause 1s]\n", "pauses must grow"},
		{"too long", "Měsíc svítí a louka spinká.\n[pause 5s]", "Měsíc svítí a louka spinká.\n[pause 40s]", "deviates"},
		{"length mismatch", "length_min: 2", "length_min: 5", "length_min=5"},
	}
	for _, c := range cases {
		src := strings.Replace(base, c.from, c.to, 1)
		if src == base {
			t.Fatalf("%s: replacement did not apply", c.name)
		}
		r := Check(c.name, []byte(src), cfg(2))
		if r.OK || !hasErr(r, c.want) {
			t.Errorf("%s: want error containing %q, got %v", c.name, c.want, r.Errors)
		}
	}
}

func TestMatchForbidden(t *testing.T) {
	forb := []string{"strach", "zlá", "umře=", "do pece"}
	if h := matchForbidden("Zlatá rybka plave.", forb); len(h) != 0 {
		t.Errorf("zlatá must not match zlá: %v", h)
	}
	if h := matchForbidden("Neumřel, umřelo.", forb); len(h) != 0 {
		t.Errorf("exact entry matched a prefix: %v", h)
	}
	if h := matchForbidden("Strachy a umře, pak šel do pece.", forb); len(h) != 3 {
		t.Errorf("hits = %v", h)
	}
}

type fakeChat struct{ out string }

func (f fakeChat) Chat(context.Context, []llm.Message, float64) (string, error) { return f.out, nil }

func TestLLMJudge(t *testing.T) {
	checklist := "<!-- note -->\n## SYSTEM\nHodnoť.\n"
	ok := LLMJudge(context.Background(), fakeChat{"```json\n{\"scores\":{\"calm\":5,\"no_tension\":4},\"blockers\":[],\"suggestions\":[]}\n```"}, checklist, "x", 4)
	if !ok.Pass || ok.Error != "" {
		t.Errorf("expected pass: %+v", ok)
	}
	low := LLMJudge(context.Background(), fakeChat{`{"scores":{"calm":3},"blockers":[]}`}, checklist, "x", 4)
	if low.Pass {
		t.Error("score 3 < 4 should fail")
	}
	blk := LLMJudge(context.Background(), fakeChat{`{"scores":{"calm":5},"blockers":["vlk straší"]}`}, checklist, "x", 4)
	if blk.Pass {
		t.Error("blockers should fail")
	}
	bad := LLMJudge(context.Background(), fakeChat{"nevím"}, checklist, "x", 4)
	if bad.Error == "" {
		t.Error("unparseable output should set Error")
	}
}
