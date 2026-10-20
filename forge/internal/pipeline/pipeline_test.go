package pipeline

import (
	"context"
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/tts"
	"github.com/lioilsources/hajanek/forge/internal/wavio"
)

func repoRoot(t *testing.T) string {
	r, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func testEnv(t *testing.T, content string) *Env {
	e, err := NewEnv(repoRoot(t), content, "")
	if err != nil {
		t.Fatal(err)
	}
	e.Work = t.TempDir()
	return e
}

// GenerateScript against a fake OpenAI-compatible server returning a gold script.
func TestGenerateScriptFakeLLM(t *testing.T) {
	content := filepath.Join(repoRoot(t), "content")
	gold, err := os.ReadFile(filepath.Join(content, "scripts/gold/zlatovlaska.10.md"))
	if err != nil {
		t.Skip("content/ gold scripts not present")
	}
	if _, err := os.Stat(filepath.Join(content, "prompts/script_template.md")); err != nil {
		t.Skip("template not present")
	}
	var got struct {
		Messages []struct{ Role, Content string } `json:"messages"`
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" || r.Header.Get("Authorization") != "Bearer k" {
			http.Error(w, "bad request", 400)
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
			t.Error(err)
		}
		if err := json.NewEncoder(w).Encode(map[string]any{"choices": []any{map[string]any{"message": map[string]string{
			"role": "assistant", "content": "<think>hmm</think>```markdown\n" + string(gold) + "```"}}}}); err != nil {
			t.Error(err)
		}
	}))
	defer srv.Close()
	t.Setenv("LLM_BASE_URL", srv.URL)
	t.Setenv("LLM_API_KEY", "k")
	t.Setenv("LLM_MODEL", "m")
	e := testEnv(t, content)
	e.Cfg.Judge.LLM = "off"
	out := filepath.Join(t.TempDir(), "zlatovlaska.10.md")
	path, rep, err := e.GenerateScript(context.Background(), ScriptOpts{Tale: "zlatovlaska", Length: 10, Out: out})
	if err != nil {
		t.Fatal(err)
	}
	if !rep.OK {
		t.Fatalf("judge: %v", rep.Errors)
	}
	b, _ := os.ReadFile(path)
	if !strings.Contains(string(b), "status: draft") || strings.Contains(string(b), "status: gold") {
		t.Error("generated script must be status: draft")
	}
	if got.Messages[0].Role != "system" || len(got.Messages) != 4 {
		t.Fatalf("expected system + 1 few-shot pair + user, got %d messages", len(got.Messages))
	}
	last := got.Messages[len(got.Messages)-1].Content
	if !strings.Contains(last, "zlatovlaska") || strings.Contains(last, "{{tale_text}}") || !strings.Contains(last, "Jiřík") {
		t.Error("user prompt not rendered with tale vars")
	}
	if !strings.Contains(got.Messages[2].Content, "id: cervena-karkulka") {
		t.Error("few-shot should be the other gold script")
	}
}

type fakeSynth struct{ calls int }

func (f *fakeSynth) Synthesize(r tts.Request) (tts.Response, error) {
	f.calls++
	w, err := wavio.Create(r.OutPath, 24000)
	if err != nil {
		return tts.Response{}, err
	}
	s := make([]int16, 24000/2) // 0.5 s tone
	for i := range s {
		s[i] = int16(3000 * math.Sin(float64(i)*0.05))
	}
	if err := w.Write(s); err != nil {
		_ = w.Close()
		return tts.Response{}, err
	}
	return tts.Response{OK: true, DurationS: 0.5}, w.Close()
}
func (f *fakeSynth) Close() error { return nil }

func TestVoiceAssembly(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed")
	}
	e := testEnv(t, filepath.Join(repoRoot(t), "forge/testdata/content"))
	fs := &fakeSynth{}
	m, err := e.Voice(VoiceOpts{Tale: "test-pohadka", Voice: "mama", Length: 2, Synth: fs})
	if err != nil {
		t.Fatal(err)
	}
	if fs.calls != 15 {
		t.Errorf("synth calls = %d, want 15", fs.calls)
	}
	// 15 × (0.5 s + 0.6 s gap) + 54 s of pauses
	if want := 15*1.1 + 54; math.Abs(m.DurationS-want) > 0.05 {
		t.Errorf("duration %.3f, want %.3f", m.DurationS, want)
	}
	last := m.Silences[len(m.Silences)-1]
	if math.Abs(last[1]-m.DurationS) > 1e-6 || math.Abs(last[1]-last[0]-6.6) > 0.01 {
		t.Errorf("final silence %v", last)
	}
	// Second run with --force hits the cache only.
	e.Force = true
	fs2 := &fakeSynth{}
	m2, err := e.Voice(VoiceOpts{Tale: "test-pohadka", Voice: "mama", Length: 2, Synth: fs2})
	if err != nil {
		t.Fatal(err)
	}
	if fs2.calls != 0 || m2.CacheHits != 15 {
		t.Errorf("cache: calls %d hits %d", fs2.calls, m2.CacheHits)
	}
	// Drafts are refused without AllowDraft.
	draftDir := t.TempDir()
	src, _ := os.ReadFile(filepath.Join(e.Content, "scripts/test-pohadka.2.md"))
	p := filepath.Join(draftDir, "d.md")
	if err := os.WriteFile(p, []byte(strings.Replace(string(src), "status: reviewed", "status: draft", 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := e.Voice(VoiceOpts{Tale: "test-pohadka", Voice: "mama", Length: 2, ScriptPath: p, Synth: fs2}); err == nil {
		t.Error("draft should be refused")
	}
}

func TestNextDeadline(t *testing.T) {
	loc, _ := time.LoadLocation("Europe/Prague")
	now := time.Date(2026, 10, 20, 22, 0, 0, 0, loc)
	d, err := nextDeadline(now, "07:00", "Europe/Prague")
	if err != nil || !d.Equal(time.Date(2026, 10, 21, 7, 0, 0, 0, loc)) {
		t.Errorf("deadline %v %v", d, err)
	}
	d, _ = nextDeadline(time.Date(2026, 10, 21, 3, 0, 0, 0, loc), "07:00", "Europe/Prague")
	if !d.Equal(time.Date(2026, 10, 21, 7, 0, 0, 0, loc)) {
		t.Errorf("deadline after midnight %v", d)
	}
}

func TestScriptPathFallback(t *testing.T) {
	e := testEnv(t, t.TempDir())
	if err := os.MkdirAll(filepath.Join(e.Content, "scripts/gold"), 0o755); err != nil {
		t.Fatal(err)
	}
	gold := filepath.Join(e.Content, "scripts/gold/a.10.md")
	if err := os.WriteFile(gold, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if p, err := e.ScriptPath("a", 10); err != nil || p != gold {
		t.Errorf("fallback: %s %v", p, err)
	}
	main := filepath.Join(e.Content, "scripts/a.10.md")
	if err := os.WriteFile(main, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if p, _ := e.ScriptPath("a", 10); p != main {
		t.Errorf("primary: %s", p)
	}
}

func TestForceDraft(t *testing.T) {
	if s := forceDraft("---\nid: a\nstatus: gold\n---\n## uvod\n"); !strings.Contains(s, "status: draft") || strings.Contains(s, "gold") {
		t.Error(s)
	}
	if s := forceDraft("---\nid: a\n---\n## uvod\n"); !strings.Contains(s, "status: draft\n---\n## uvod") {
		t.Error(s)
	}
}
