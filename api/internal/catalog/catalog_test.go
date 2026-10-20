package catalog

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func validCatalog(t *testing.T) *Catalog {
	t.Helper()
	b, err := os.ReadFile("testdata/valid.json")
	if err != nil {
		t.Fatal(err)
	}
	c, err := Parse(b)
	if err != nil {
		t.Fatalf("fixture must be valid: %v", err)
	}
	return c
}

func ptr[T any](v T) *T { return &v }

func TestValidate(t *testing.T) {
	tests := []struct {
		name    string
		mutate  func(c *Catalog)
		wantErr string // substring; empty = valid
	}{
		{"valid fixture", func(c *Catalog) {}, ""},
		{"volume bounds inclusive", func(c *Catalog) {
			c.Presets[0].Layers[0].Volume = ptr(0.0)
			c.Presets[0].Layers[1].Volume = ptr(1.0)
		}, ""},
		{"three layers", func(c *Catalog) {
			c.Presets[0].Layers = append(c.Presets[0].Layers, Layer{Ambient: "wind", Volume: ptr(0.1)})
		}, ""},
		{"empty lists allowed", func(c *Catalog) {
			c.Tales, c.Presets = []Tale{}, []Preset{}
		}, ""},
		{"wrong schema", func(c *Catalog) { c.Schema = 2 }, "schema"},
		{"missing schema", func(c *Catalog) { c.Schema = 0 }, "schema"},
		{"zero version", func(c *Catalog) { c.Version = 0 }, "version"},
		{"bad generated_at", func(c *Catalog) { c.GeneratedAt = "yesterday" }, "generated_at"},
		{"relative base_url", func(c *Catalog) { c.BaseURL = "hajanek-content/" }, "base_url"},
		{"base_url without slash", func(c *Catalog) { c.BaseURL = "https://example.com/x" }, "base_url"},
		{"missing tales array", func(c *Catalog) { c.Tales = nil }, "required arrays"},
		{"tale id not kebab", func(c *Catalog) { c.Tales[0].ID = "Cervena_Karkulka" }, "kebab-case"},
		{"tale id diacritics", func(c *Catalog) { c.Tales[0].ID = "červená-karkulka" }, "kebab-case"},
		{"tale id trailing dash", func(c *Catalog) { c.Tales[0].ID = "karkulka-" }, "kebab-case"},
		{"tale missing title", func(c *Catalog) { c.Tales[0].Title = " " }, "tales[0].title: required"},
		{"duplicate ambient id", func(c *Catalog) { c.Ambient[1].ID = "sea" }, "duplicate"},
		{"voice missing id", func(c *Catalog) { c.Voices[0].ID = "" }, "voices[0].id: required"},
		{"track unknown voice", func(c *Catalog) { c.Tales[0].Tracks[0].Voice = "deda" }, "unknown voice"},
		{"tale unknown ambient", func(c *Catalog) { c.Tales[0].Ambient = "lava" }, "unknown ambient"},
		{"tale without tracks", func(c *Catalog) { c.Tales[0].Tracks = nil }, "at least one track"},
		{"absolute path", func(c *Catalog) { c.Ambient[0].Path = "/ambient/sea.opus" }, "relative"},
		{"path traversal", func(c *Catalog) { c.Ambient[0].Path = "../x.opus" }, "relative"},
		{"bad sha256", func(c *Catalog) { c.Ambient[0].SHA256 = "…" }, "sha256"},
		{"zero bytes", func(c *Catalog) { c.Tales[0].Tracks[0].Bytes = 0 }, "bytes"},
		{"zero layers", func(c *Catalog) { c.Presets[0].Layers = nil }, "1–3 layers"},
		{"four layers", func(c *Catalog) {
			l := Layer{Ambient: "sea", Volume: ptr(0.5)}
			c.Presets[0].Layers = []Layer{l, l, l, l}
		}, "1–3 layers"},
		{"volume above 1", func(c *Catalog) { c.Presets[0].Layers[0].Volume = ptr(1.01) }, "0..1"},
		{"volume negative", func(c *Catalog) { c.Presets[0].Layers[0].Volume = ptr(-0.1) }, "0..1"},
		{"volume missing", func(c *Catalog) { c.Presets[0].Layers[0].Volume = nil }, "volume: required"},
		{"layer unknown ambient", func(c *Catalog) { c.Presets[0].Layers[0].Ambient = "lava" }, "unknown ambient"},
		{"preset id not kebab", func(c *Catalog) { c.Presets[0].ID = "Plaz Vecer" }, "kebab-case"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := validCatalog(t)
			tt.mutate(c)
			err := c.Validate()
			switch {
			case tt.wantErr == "" && err != nil:
				t.Fatalf("unexpected error: %v", err)
			case tt.wantErr != "" && err == nil:
				t.Fatalf("expected error containing %q", tt.wantErr)
			case tt.wantErr != "" && !strings.Contains(err.Error(), tt.wantErr):
				t.Fatalf("error %q does not contain %q", err, tt.wantErr)
			}
		})
	}
}

func TestParse(t *testing.T) {
	if _, err := Parse([]byte(`{"schema":1,`)); err == nil {
		t.Fatal("expected decode error")
	}
	// Unknown fields are tolerated for forward compatibility.
	c := validCatalog(t)
	b, _ := json.Marshal(c)
	b = append([]byte(`{"future_field":true,`), b[1:]...)
	if _, err := Parse(b); err != nil {
		t.Fatalf("unknown field rejected: %v", err)
	}
}
