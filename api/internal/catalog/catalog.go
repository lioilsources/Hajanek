// Package catalog validates catalog.json (CONTRACTS.md §3) and keeps the
// last known-good copy fetched from GitHub Pages.
package catalog

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// SchemaVersion is the only catalog schema this service understands.
const SchemaVersion = 2

type Catalog struct {
	Schema      int       `json:"schema"`
	Version     int64     `json:"version"`
	GeneratedAt string    `json:"generated_at"`
	BaseURL     string    `json:"base_url"`
	Tales       []Tale    `json:"tales"`
	Ambient     []Ambient `json:"ambient"`
	Presets     []Preset  `json:"presets"`
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

// Script is the published text of one tale at one length (CONTRACTS.md §2).
type Script struct {
	LengthMin    int     `json:"length_min"`
	Path         string  `json:"path"`
	SHA256       string  `json:"sha256"`
	Bytes        int64   `json:"bytes"`
	EstDurationS float64 `json:"est_duration_s"`
}

// Script returns the script of tale at length, if published.
func (c *Catalog) Script(tale string, length int) (Script, bool) {
	for _, t := range c.Tales {
		if t.ID != tale {
			continue
		}
		for _, s := range t.Scripts {
			if s.LengthMin == length {
				return s, true
			}
		}
	}
	return Script{}, false
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

type Preset struct {
	ID     string  `json:"id"`
	Title  string  `json:"title"`
	Layers []Layer `json:"layers"`
}

type Layer struct {
	Ambient string   `json:"ambient"`
	Volume  *float64 `json:"volume"`
}

var (
	kebabRe  = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
	sha256Re = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// IsKebab reports whether s is a kebab-case ASCII identifier.
func IsKebab(s string) bool { return kebabRe.MatchString(s) }

// Parse decodes and validates a catalog. Unknown fields are ignored so that
// additive changes in forge don't break older API deployments.
func Parse(body []byte) (*Catalog, error) {
	var c Catalog
	if err := json.Unmarshal(body, &c); err != nil {
		return nil, fmt.Errorf("decode catalog: %w", err)
	}
	if err := c.Validate(); err != nil {
		return nil, err
	}
	return &c, nil
}

// Validate returns all contract violations joined into one error.
func (c *Catalog) Validate() error {
	var v validator

	if c.Schema != SchemaVersion {
		v.addf("schema: want %d, got %d", SchemaVersion, c.Schema)
	}
	if c.Version < 1 {
		v.addf("version: must be >= 1")
	}
	if _, err := time.Parse(time.RFC3339, c.GeneratedAt); err != nil {
		v.addf("generated_at: not RFC 3339: %q", c.GeneratedAt)
	}
	if u, err := url.Parse(c.BaseURL); err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
		v.addf("base_url: not an absolute http(s) URL: %q", c.BaseURL)
	} else if !strings.HasSuffix(c.BaseURL, "/") {
		v.addf("base_url: must end with '/'")
	}
	if c.Tales == nil || c.Ambient == nil || c.Presets == nil {
		v.addf("tales, ambient and presets are required arrays")
	}

	ambient := map[string]bool{}
	for i, a := range c.Ambient {
		p := fmt.Sprintf("ambient[%d]", i)
		v.id(p, a.ID, ambient)
		v.required(p+".title", a.Title)
		v.file(p, a.Path, a.Bytes, a.SHA256)
		if a.DurationS <= 0 {
			v.addf("%s.duration_s: must be > 0", p)
		}
		v.required(p+".license", a.License)
	}

	tales := map[string]bool{}
	for i, t := range c.Tales {
		p := fmt.Sprintf("tales[%d]", i)
		v.id(p, t.ID, tales)
		v.required(p+".title", t.Title)
		if t.Ambient != "" && !ambient[t.Ambient] {
			v.addf("%s.ambient: unknown ambient %q", p, t.Ambient)
		}
		if len(t.Scripts) == 0 {
			v.addf("%s.scripts: at least one script required", p)
		}
		seen := map[int]bool{}
		for j, sc := range t.Scripts {
			sp := fmt.Sprintf("%s.scripts[%d]", p, j)
			if sc.LengthMin < 1 {
				v.addf("%s.length_min: must be >= 1", sp)
			}
			if seen[sc.LengthMin] {
				v.addf("%s: duplicate length_min %d", sp, sc.LengthMin)
			}
			seen[sc.LengthMin] = true
			v.file(sp, sc.Path, sc.Bytes, sc.SHA256)
			if sc.EstDurationS <= 0 {
				v.addf("%s.est_duration_s: must be > 0", sp)
			}
		}
	}

	presets := map[string]bool{}
	for i, pr := range c.Presets {
		p := fmt.Sprintf("presets[%d]", i)
		v.id(p, pr.ID, presets)
		v.required(p+".title", pr.Title)
		if n := len(pr.Layers); n < 1 || n > 3 {
			v.addf("%s.layers: want 1–3 layers, got %d", p, n)
		}
		for j, l := range pr.Layers {
			lp := fmt.Sprintf("%s.layers[%d]", p, j)
			if !ambient[l.Ambient] {
				v.addf("%s.ambient: unknown ambient %q", lp, l.Ambient)
			}
			if l.Volume == nil {
				v.addf("%s.volume: required", lp)
			} else if *l.Volume < 0 || *l.Volume > 1 {
				v.addf("%s.volume: must be within 0..1, got %g", lp, *l.Volume)
			}
		}
	}

	return v.err()
}

type validator struct{ errs []error }

func (v *validator) addf(format string, args ...any) {
	v.errs = append(v.errs, fmt.Errorf(format, args...))
}

func (v *validator) required(field, val string) {
	if strings.TrimSpace(val) == "" {
		v.addf("%s: required", field)
	}
}

func (v *validator) id(prefix, id string, seen map[string]bool) {
	switch {
	case id == "":
		v.addf("%s.id: required", prefix)
	case !IsKebab(id):
		v.addf("%s.id: not kebab-case: %q", prefix, id)
	case seen[id]:
		v.addf("%s.id: duplicate %q", prefix, id)
	}
	seen[id] = true
}

func (v *validator) file(prefix, path string, size int64, sum string) {
	switch {
	case path == "":
		v.addf("%s.path: required", prefix)
	case strings.HasPrefix(path, "/") || strings.Contains(path, "://") || strings.Contains(path, ".."):
		v.addf("%s.path: must be relative to base_url: %q", prefix, path)
	}
	if size <= 0 {
		v.addf("%s.bytes: must be > 0", prefix)
	}
	if !sha256Re.MatchString(sum) {
		v.addf("%s.sha256: want 64 lowercase hex chars", prefix)
	}
}

func (v *validator) err() error {
	const max = 20
	if len(v.errs) > max {
		extra := len(v.errs) - max
		v.errs = append(v.errs[:max], fmt.Errorf("…and %d more", extra))
	}
	return errors.Join(v.errs...)
}
