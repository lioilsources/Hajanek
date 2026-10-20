// Package catalog models catalog.json schema 2 (CONTRACTS §3) and merges published scripts into it.
package catalog

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Schema is the catalog schema version this package writes (CONTRACTS §3).
const Schema = 2

// Script is one published script length of a tale.
type Script struct {
	LengthMin    int    `json:"length_min"`
	Path         string `json:"path"`
	SHA256       string `json:"sha256"`
	Bytes        int64  `json:"bytes"`
	EstDurationS int    `json:"est_duration_s"`
}

type Tale struct {
	ID      string   `json:"id"`
	Title   string   `json:"title"`
	Age     string   `json:"age"`
	Setting string   `json:"setting"`
	Ambient string   `json:"ambient"`
	Free    bool     `json:"free"`
	Scripts []Script `json:"scripts"`
}

type Ambient struct {
	ID        string  `json:"id"`
	Title     string  `json:"title"`
	Path      string  `json:"path"`
	DurationS float64 `json:"duration_s"`
	Bytes     int64   `json:"bytes"`
	SHA256    string  `json:"sha256"`
	Free      bool    `json:"free"`
	License   string  `json:"license"`
	Source    string  `json:"source"`
}

type Layer struct {
	Ambient string  `json:"ambient"`
	Volume  float64 `json:"volume"`
}

type Preset struct {
	ID     string  `json:"id"`
	Title  string  `json:"title"`
	Layers []Layer `json:"layers"`
}

type Catalog struct {
	Schema      int       `json:"schema"`
	Version     int       `json:"version"`
	GeneratedAt string    `json:"generated_at"`
	BaseURL     string    `json:"base_url"`
	Tales       []Tale    `json:"tales"`
	Ambient     []Ambient `json:"ambient"`
	Presets     []Preset  `json:"presets"`
}

func New(baseURL string) *Catalog {
	return &Catalog{Schema: Schema, Version: 0, BaseURL: baseURL,
		Tales: []Tale{}, Ambient: []Ambient{}, Presets: []Preset{}}
}

// Load reads a catalog; a missing file yields an empty catalog. Fields of
// older schemas (voices, tracks) are dropped; the version is kept.
func Load(path, baseURL string) (*Catalog, error) {
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return New(baseURL), nil
	}
	if err != nil {
		return nil, err
	}
	c := New(baseURL)
	if err := json.Unmarshal(b, c); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return c, nil
}

// Clone returns a deep copy.
func (c *Catalog) Clone() *Catalog {
	b, _ := json.Marshal(c)
	n := &Catalog{}
	_ = json.Unmarshal(b, n)
	return n
}

// UpsertTale merges tale metadata (keeping existing scripts) and returns the tale.
func (c *Catalog) UpsertTale(t Tale) *Tale {
	for i := range c.Tales {
		if c.Tales[i].ID == t.ID {
			scripts := c.Tales[i].Scripts
			c.Tales[i] = t
			c.Tales[i].Scripts = scripts
			return &c.Tales[i]
		}
	}
	t.Scripts = []Script{}
	c.Tales = append(c.Tales, t)
	return &c.Tales[len(c.Tales)-1]
}

func (c *Catalog) Tale(id string) *Tale {
	for i := range c.Tales {
		if c.Tales[i].ID == id {
			return &c.Tales[i]
		}
	}
	return nil
}

func (t *Tale) UpsertScript(sc Script) {
	for i := range t.Scripts {
		if t.Scripts[i].LengthMin == sc.LengthMin {
			t.Scripts[i] = sc
			return
		}
	}
	t.Scripts = append(t.Scripts, sc)
}

func (c *Catalog) UpsertAmbient(a Ambient) {
	for i := range c.Ambient {
		if c.Ambient[i].ID == a.ID {
			c.Ambient[i] = a
			return
		}
	}
	c.Ambient = append(c.Ambient, a)
}

func (c *Catalog) sortAll() {
	sort.SliceStable(c.Tales, func(i, j int) bool { return c.Tales[i].ID < c.Tales[j].ID })
	for i := range c.Tales {
		sc := c.Tales[i].Scripts
		sort.SliceStable(sc, func(a, b int) bool { return sc[a].LengthMin < sc[b].LengthMin })
	}
	sort.SliceStable(c.Ambient, func(i, j int) bool { return c.Ambient[i].ID < c.Ambient[j].ID })
}

// contentKey is the catalog serialized without version/generated_at.
func (c *Catalog) contentKey() []byte {
	n := c.Clone()
	n.sortAll()
	n.Version, n.GeneratedAt = 0, ""
	b, _ := json.Marshal(n)
	return b
}

// Finalize bumps version and generated_at only if content differs from prev.
// Returns whether anything changed.
func (c *Catalog) Finalize(prev *Catalog, now time.Time) bool {
	c.sortAll()
	if prev != nil && bytes.Equal(c.contentKey(), prev.contentKey()) {
		c.Version, c.GeneratedAt = prev.Version, prev.GeneratedAt
		return false
	}
	base := 0
	if prev != nil {
		base = prev.Version
	}
	c.Version = base + 1
	c.GeneratedAt = now.UTC().Format(time.RFC3339)
	return true
}

func (c *Catalog) Save(path string) error {
	b, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, append(b, '\n'), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

var reKebab = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
var reSHA = regexp.MustCompile(`^[0-9a-f]{64}$`)

// Validate mirrors api/internal/catalog Validate (CONTRACTS §3); when root != ""
// it also checks that files exist with matching size. prev (may be nil) is the
// last accepted catalog: the version must grow, or stay with identical content.
func (c *Catalog) Validate(root string, prev *Catalog) []string {
	var errs []string
	e := func(f string, a ...any) { errs = append(errs, fmt.Sprintf(f, a...)) }
	if c.Schema != Schema {
		e("schema must be %d", Schema)
	}
	if c.Version < 1 {
		e("version must be >= 1")
	}
	if prev != nil && prev.Version > 0 {
		switch {
		case c.Version < prev.Version:
			e("version %d lower than last accepted %d", c.Version, prev.Version)
		case c.Version == prev.Version && !bytes.Equal(c.contentKey(), prev.contentKey()):
			e("version %d reused with different content", c.Version)
		}
	}
	if _, err := time.Parse(time.RFC3339, c.GeneratedAt); err != nil {
		e("generated_at not RFC 3339: %q", c.GeneratedAt)
	}
	if u, err := url.Parse(c.BaseURL); err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" || !strings.HasSuffix(c.BaseURL, "/") {
		e("base_url must be an absolute http(s) URL ending with '/': %q", c.BaseURL)
	}
	if c.Tales == nil || c.Ambient == nil || c.Presets == nil {
		e("tales, ambient and presets are required arrays")
	}
	id := func(kind, v string, seen map[string]bool) {
		switch {
		case !reKebab.MatchString(v):
			e("%s id %q not kebab-case", kind, v)
		case seen[v]:
			e("duplicate %s %q", kind, v)
		}
		seen[v] = true
	}
	amb := map[string]bool{}
	for _, a := range c.Ambient {
		id("ambient", a.ID, amb)
		if a.Title == "" || a.License == "" {
			e("ambient %s: title and license required", a.ID)
		}
		if a.DurationS <= 0 {
			e("%s: duration_s must be > 0", a.Path)
		}
		checkFile(root, a.Path, a.Bytes, a.SHA256, e)
	}
	tales := map[string]bool{}
	for _, t := range c.Tales {
		id("tale", t.ID, tales)
		if t.Title == "" {
			e("tale %s: empty title", t.ID)
		}
		if t.Ambient != "" && !amb[t.Ambient] {
			e("tale %s: unknown ambient %q", t.ID, t.Ambient)
		}
		if len(t.Scripts) == 0 {
			e("tale %s: at least one script required", t.ID)
		}
		seen := map[int]bool{}
		for _, sc := range t.Scripts {
			if sc.LengthMin <= 0 {
				e("tale %s: invalid length_min %d", t.ID, sc.LengthMin)
			}
			if seen[sc.LengthMin] {
				e("tale %s: duplicate script length %d", t.ID, sc.LengthMin)
			}
			seen[sc.LengthMin] = true
			want := fmt.Sprintf("scripts/%s.%d.md", t.ID, sc.LengthMin)
			if sc.Path != want {
				e("tale %s: path %q, want %q", t.ID, sc.Path, want)
			}
			if sc.EstDurationS <= 0 {
				e("%s: est_duration_s must be > 0", sc.Path)
			}
			checkFile(root, sc.Path, sc.Bytes, sc.SHA256, e)
		}
	}
	presets := map[string]bool{}
	for _, p := range c.Presets {
		id("preset", p.ID, presets)
		if p.Title == "" {
			e("preset %s: title required", p.ID)
		}
		if len(p.Layers) < 1 || len(p.Layers) > 3 {
			e("preset %s: 1–3 layers required", p.ID)
		}
		for _, l := range p.Layers {
			if l.Volume < 0 || l.Volume > 1 {
				e("preset %s: volume %.2f out of 0–1", p.ID, l.Volume)
			}
			if !amb[l.Ambient] {
				e("preset %s: unknown ambient %q", p.ID, l.Ambient)
			}
		}
	}
	return errs
}

func checkFile(root, rel string, size int64, sha string, e func(string, ...any)) {
	if rel == "" || strings.HasPrefix(rel, "/") || strings.Contains(rel, "://") || strings.Contains(rel, "..") {
		e("%q: path must be relative to base_url", rel)
	}
	if size <= 0 {
		e("%s: bytes must be > 0", rel)
	}
	if !reSHA.MatchString(sha) {
		e("%s: invalid sha256", rel)
	}
	if root == "" {
		return
	}
	st, err := os.Stat(filepath.Join(root, filepath.FromSlash(rel)))
	if err != nil {
		e("%s: missing file", rel)
		return
	}
	if st.Size() != size {
		e("%s: bytes %d != file size %d", rel, size, st.Size())
	}
}
