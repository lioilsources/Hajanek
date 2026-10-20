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
	c.Voices = []Voice{{ID: "mama", Label: "Měkký", Free: true}, {ID: "tata", Label: "Hluboký", Free: true}}
	c.UpsertAmbient(Ambient{ID: "sea", Title: "Moře", Path: "ambient/sea.opus", DurationS: 90, Bytes: 4, SHA256: sha, Free: true, License: "CC0", Source: "test"})
	c.Presets = []Preset{{ID: "plaz-vecer", Title: "Pláž večer", Layers: []Layer{{Ambient: "sea", Volume: 0.8}}}}
	t := c.UpsertTale(Tale{ID: "zlatovlaska", Title: "Zlatovláska", Age: "5+", Setting: "more", Ambient: "sea"})
	t.UpsertTrack(Track{Voice: "mama", LengthMin: 10, Path: "audio/zlatovlaska/mama/10.opus", DurationS: 600, Bytes: 10, SHA256: sha})
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
	// Re-upserting identical metadata/track is still no change.
	again := c.Clone()
	tl := again.UpsertTale(Tale{ID: "zlatovlaska", Title: "Zlatovláska", Age: "5+", Setting: "more", Ambient: "sea"})
	tl.UpsertTrack(Track{Voice: "mama", LengthMin: 10, Path: "audio/zlatovlaska/mama/10.opus", DurationS: 600, Bytes: 10, SHA256: sha})
	if again.Finalize(c, now) {
		t.Fatal("idempotent upsert changed catalog")
	}
	if len(again.Tale("zlatovlaska").Tracks) != 1 {
		t.Fatal("duplicate track")
	}
	// New track → bump.
	n := c.Clone()
	n.UpsertTale(Tale{ID: "cervena-karkulka", Title: "Červená Karkulka"}).
		UpsertTrack(Track{Voice: "tata", LengthMin: 10, Path: "audio/cervena-karkulka/tata/10.opus", DurationS: 1, Bytes: 1, SHA256: sha})
	if !n.Finalize(c, now.Add(time.Hour)) || n.Version != 2 {
		t.Fatalf("new track: version %d", n.Version)
	}
	if n.Tales[0].ID != "cervena-karkulka" {
		t.Error("tales not sorted")
	}
	// Changed sha → bump; existing tracks kept on metadata update.
	m := n.Clone()
	m.Tale("zlatovlaska").UpsertTrack(Track{Voice: "mama", LengthMin: 10, Path: "audio/zlatovlaska/mama/10.opus", DurationS: 600, Bytes: 10, SHA256: strings.Repeat("a", 64)})
	m.UpsertTale(Tale{ID: "zlatovlaska", Title: "Zlatovláska", Free: true})
	if !m.Finalize(n, now) || m.Version != 3 || len(m.Tale("zlatovlaska").Tracks) != 1 {
		t.Fatalf("sha change: v%d", m.Version)
	}
}

func TestValidate(t *testing.T) {
	c := base()
	c.Finalize(nil, time.Now())
	if errs := c.Validate(""); len(errs) != 0 {
		t.Fatalf("valid catalog: %v", errs)
	}
	bad := c.Clone()
	bad.Tales[0].Tracks[0].Voice = "nobody"
	bad.Tales[0].Tracks[0].Path = "audio/x.opus"
	bad.Tales[0].Tracks[0].SHA256 = "xyz"
	bad.Presets = []Preset{{ID: "Bad_Id", Layers: []Layer{{Ambient: "sea", Volume: 1.5}}}}
	bad.UpsertTale(Tale{ID: "bez-audia", Title: "Bez audia", Ambient: "rain"})
	errs := bad.Validate("")
	for _, want := range []string{"unknown voice", "path", "invalid sha256", "not kebab-case", "out of 0–1",
		"at least one track", "unknown ambient \"rain\""} {
		found := false
		for _, e := range errs {
			found = found || strings.Contains(e, want)
		}
		if !found {
			t.Errorf("missing error %q in %v", want, errs)
		}
	}
	// File checks against a root dir.
	dir := t.TempDir()
	p := filepath.Join(dir, "audio/zlatovlaska/mama/10.opus")
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
	if errs := c.Validate(dir); len(errs) != 0 {
		t.Errorf("file check: %v", errs)
	}
	if err := os.WriteFile(p, []byte("short"), 0o644); err != nil {
		t.Fatal(err)
	}
	if errs := c.Validate(dir); len(errs) != 1 {
		t.Errorf("size mismatch not detected: %v", errs)
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
