package pipeline

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/catalog"
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

func writeFile(t *testing.T, path, data string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(data), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestPublishScripts(t *testing.T) {
	fixture, err := os.ReadFile(filepath.Join(repoRoot(t), "forge/testdata/content/scripts/test-pohadka.2.md"))
	if err != nil {
		t.Fatal(err)
	}
	src := string(fixture)
	retitle := func(id, status string) string {
		s := strings.Replace(src, "id: test-pohadka", "id: "+id, 1)
		return strings.Replace(s, "status: reviewed", "status: "+status, 1)
	}
	content := t.TempDir()
	writeFile(t, filepath.Join(content, "scripts/test-pohadka.2.md"), src)
	writeFile(t, filepath.Join(content, "scripts/navrh.2.md"), retitle("navrh", "draft"))
	writeFile(t, filepath.Join(content, "scripts/gold/zlata.2.md"), retitle("zlata", "gold"))
	// A draft in scripts/ shadows the gold copy (lookup order, CONTRACTS §2).
	writeFile(t, filepath.Join(content, "scripts/stin.2.md"), retitle("stin", "draft"))
	writeFile(t, filepath.Join(content, "scripts/gold/stin.2.md"), retitle("stin", "gold"))
	writeFile(t, filepath.Join(content, "presets/presets.json"), `[{"id":"louka","title":"Louka","layers":[{"ambient":"night-meadow","volume":0.6}]}]`)

	e := testEnv(t, content)
	pages := t.TempDir()
	now := time.Date(2026, 10, 20, 3, 0, 0, 0, time.UTC)
	res, err := e.Publish(PublishOpts{PagesDir: pages, Now: now})
	if err != nil {
		t.Fatal(err)
	}
	if !res.Changed || res.Version != 1 || len(res.Scripts) != 2 || len(res.Skipped) != 2 {
		t.Fatalf("result %+v", res)
	}
	cat, err := catalog.Load(filepath.Join(pages, "catalog.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	if cat.Schema != 2 || len(cat.Tales) != 2 || cat.Tales[0].ID != "test-pohadka" || cat.Tales[1].ID != "zlata" {
		t.Fatalf("catalog %+v", cat)
	}
	tl := cat.Tales[0]
	sc := tl.Scripts[0]
	if tl.Ambient != "" || len(cat.Presets) != 0 {
		t.Error("unpublished ambient must be cleared and its presets dropped")
	}
	if sc.Path != "scripts/test-pohadka.2.md" || sc.Bytes != int64(len(fixture)) || len(sc.SHA256) != 64 {
		t.Errorf("script %+v", sc)
	}
	// est = speech at judge speeds + gaps + 54 s of pauses; roughly the 2 min target.
	if sc.EstDurationS < 90 || sc.EstDurationS > 150 {
		t.Errorf("est_duration_s %d", sc.EstDurationS)
	}
	if b, _ := os.ReadFile(filepath.Join(pages, sc.Path)); string(b) != src {
		t.Error("script not copied verbatim")
	}
	// Re-publish without changes keeps the version.
	if res, err = e.Publish(PublishOpts{PagesDir: pages, Now: now.Add(time.Hour)}); err != nil || res.Changed || res.Version != 1 {
		t.Fatalf("idempotent publish: %+v %v", res, err)
	}
	// Changing a script bumps the version.
	writeFile(t, filepath.Join(content, "scripts/test-pohadka.2.md"), strings.Replace(src, "title: Testovací pohádka", "title: Jiný název", 1))
	if res, err = e.Publish(PublishOpts{PagesDir: pages, Now: now.Add(2 * time.Hour)}); err != nil || !res.Changed || res.Version != 2 {
		t.Fatalf("changed publish: %+v %v", res, err)
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
