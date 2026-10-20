package catalog

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const sha = "0b63b09233e7e926d182f091f23d1db51e701a9873c5ea2f1ed716505febf7e4"

func base() *Catalog {
	c := New("https://example.test/")
	c.UpsertAmbient(Ambient{ID: "sea", Title: "Moře", Path: "ambient/sea.opus", DurationS: 90, Bytes: 4, SHA256: sha, Free: true, License: "CC0", Source: "test"})
	c.Presets = []Preset{{ID: "plaz-vecer", Title: "Pláž večer", Layers: []Layer{{Ambient: "sea", Volume: 0.8}}}}
	t := c.UpsertTale(Tale{ID: "zlatovlaska", Title: "Zlatovláska", Age: "5+", Setting: "more", Ambient: "sea"})
	t.UpsertScript(Script{LengthMin: 10, Path: "scripts/zlatovlaska.10.md", SHA256: sha, Bytes: 10, EstDurationS: 600})
	return c
}

func TestFinalizeVersionBump(t *testing.T) {
	now := time.Date(2026, 10, 20, 3, 0, 0, 0, time.UTC)
	c := base()
	if !c.Finalize(nil, now) || c.Version != 1 {
		t.Fatalf("first finalize: version %d", c.Version)
	}
	// Same content → no bump, timestamp kept.
	same := c.Clone()
	if same.Finalize(c, now.Add(time.Hour)) || same.Version != 1 || same.GeneratedAt != c.GeneratedAt {
		t.Fatalf("unchanged catalog bumped: v%d %s", same.Version, same.GeneratedAt)
	}
	// Re-upserting identical metadata/script is still no change.
	again := c.Clone()
	tl := again.UpsertTale(Tale{ID: "zlatovlaska", Title: "Zlatovláska", Age: "5+", Setting: "more", Ambient: "sea"})
	tl.UpsertScript(Script{LengthMin: 10, Path: "scripts/zlatovlaska.10.md", SHA256: sha, Bytes: 10, EstDurationS: 600})
	if again.Finalize(c, now) {
		t.Fatal("idempotent upsert changed catalog")
	}
	if len(again.Tale("zlatovlaska").Scripts) != 1 {
		t.Fatal("duplicate script")
	}
	// New tale → bump, sorted.
	n := c.Clone()
	n.UpsertTale(Tale{ID: "cervena-karkulka", Title: "Červená Karkulka"}).
		UpsertScript(Script{LengthMin: 10, Path: "scripts/cervena-karkulka.10.md", SHA256: sha, Bytes: 1, EstDurationS: 1})
	if !n.Finalize(c, now.Add(time.Hour)) || n.Version != 2 {
		t.Fatalf("new tale: version %d", n.Version)
	}
	if n.Tales[0].ID != "cervena-karkulka" {
		t.Error("tales not sorted")
	}
	// Changed sha → bump; existing scripts kept on metadata update.
	m := n.Clone()
	m.Tale("zlatovlaska").UpsertScript(Script{LengthMin: 10, Path: "scripts/zlatovlaska.10.md", SHA256: strings.Repeat("a", 64), Bytes: 10, EstDurationS: 600})
	m.UpsertTale(Tale{ID: "zlatovlaska", Title: "Zlatovláska", Free: true})
	if !m.Finalize(n, now) || m.Version != 3 || len(m.Tale("zlatovlaska").Scripts) != 1 {
		t.Fatalf("sha change: v%d", m.Version)
	}
}

func TestValidate(t *testing.T) {
	c := base()
	c.Finalize(nil, time.Now())
	if errs := c.Validate("", nil); len(errs) != 0 {
		t.Fatalf("valid catalog: %v", errs)
	}
	bad := c.Clone()
	bad.Schema = 1
	bad.Tales[0].Scripts[0].Path = "scripts/x.md"
	bad.Tales[0].Scripts[0].SHA256 = "xyz"
	bad.Tales[0].Scripts[0].EstDurationS = 0
	bad.Presets = []Preset{{ID: "Bad_Id", Layers: []Layer{{Ambient: "sea", Volume: 1.5}}}}
	bad.UpsertTale(Tale{ID: "bez-skriptu", Title: "Bez skriptu", Ambient: "rain"})
	errs := bad.Validate("", c)
	for _, want := range []string{"schema must be 2", "path", "invalid sha256", "est_duration_s", "not kebab-case", "out of 0–1",
		"at least one script", "unknown ambient \"rain\"", "reused with different content"} {
		found := false
		for _, e := range errs {
			found = found || strings.Contains(e, want)
		}
		if !found {
			t.Errorf("missing error %q in %v", want, errs)
		}
	}
	older := c.Clone()
	older.Version = 0
	newer := c.Clone()
	newer.Version = 5
	if errs := newer.Validate("", older); len(errs) != 0 {
		t.Errorf("newer version rejected: %v", errs)
	}
	newer.Version = 4
	if errs := newer.Validate("", &Catalog{Version: 5}); len(errs) != 1 || !strings.Contains(errs[0], "lower") {
		t.Errorf("lower version: %v", errs)
	}
	// File checks against a root dir.
	dir := t.TempDir()
	p := filepath.Join(dir, "scripts/zlatovlaska.10.md")
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte("0123456789"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "ambient"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "ambient/sea.opus"), []byte("1234"), 0o644); err != nil {
		t.Fatal(err)
	}
	if errs := c.Validate(dir, nil); len(errs) != 0 {
		t.Errorf("file check: %v", errs)
	}
	if err := os.WriteFile(p, []byte("short"), 0o644); err != nil {
		t.Fatal(err)
	}
	if errs := c.Validate(dir, nil); len(errs) != 1 {
		t.Errorf("size mismatch not detected: %v", errs)
	}
}

func TestLoadSchema1(t *testing.T) {
	p := filepath.Join(t.TempDir(), "catalog.json")
	old := `{"schema":1,"version":7,"generated_at":"2026-10-19T00:00:00Z","base_url":"https://example.test/",
"voices":[{"id":"mama","label":"Měkký","free":true}],
"tales":[{"id":"a","title":"A","tracks":[{"voice":"mama","length_min":10,"path":"audio/a/mama/10.opus"}]}],
"ambient":[],"presets":[]}`
	if err := os.WriteFile(p, []byte(old), 0o644); err != nil {
		t.Fatal(err)
	}
	prev, err := Load(p, "")
	if err != nil {
		t.Fatal(err)
	}
	c := New(prev.BaseURL)
	c.UpsertTale(Tale{ID: "a", Title: "A"}).UpsertScript(Script{LengthMin: 10, Path: "scripts/a.10.md", SHA256: sha, Bytes: 1, EstDurationS: 1})
	if !c.Finalize(prev, time.Now()) || c.Version != 8 || c.Schema != 2 {
		t.Fatalf("migration: v%d schema %d", c.Version, c.Schema)
	}
	if errs := c.Validate("", prev); len(errs) != 0 {
		t.Error(errs)
	}
}

func TestSaveLoadRoundTrip(t *testing.T) {
	c := base()
	c.Finalize(nil, time.Now())
	p := filepath.Join(t.TempDir(), "catalog.json")
	if err := c.Save(p); err != nil {
		t.Fatal(err)
	}
	l, err := Load(p, "")
	if err != nil {
		t.Fatal(err)
	}
	if l.Clone().Finalize(c, time.Now()) {
		t.Error("round trip changed content")
	}
	if missing, _ := Load(filepath.Join(t.TempDir(), "nope.json"), "u"); missing.Version != 0 || missing.BaseURL != "u" {
		t.Error("missing catalog should be empty")
	}
}
