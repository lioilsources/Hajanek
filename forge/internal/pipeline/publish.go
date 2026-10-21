package pipeline

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/audio"
	"github.com/lioilsources/hajanek/forge/internal/catalog"
	"github.com/lioilsources/hajanek/forge/internal/script"
)

// AmbientTitles are the UI names from CONTRACTS §4.
var AmbientTitles = map[string]string{
	"sea": "Moře", "rain": "Déšť na střechu", "stream": "Potůček", "fireplace": "Krb",
	"wind": "Vítr v korunách", "night-meadow": "Noční louka", "pink-noise": "Růžový šum", "brown-noise": "Hnědý šum",
}

type PublishOpts struct {
	PagesDir string
	Commit   bool
	Now      time.Time
	// Drafts publishes status: draft scripts too (testing before review).
	Drafts bool
	// MinVersion raises the new catalog version to at least this, so it beats
	// the copy bundled in the app.
	MinVersion int
}

type PublishResult struct {
	Changed bool     `json:"changed"`
	Version int      `json:"version"`
	Scripts []string `json:"scripts"`
	Copied  []string `json:"copied"`
	Skipped []string `json:"skipped"`
	Notes   []string `json:"notes"`
}

// reconcile keeps the catalog acceptable for hajanek-api: no references to
// ambient loops that are not published.
func (e *Env) reconcile(cat *catalog.Catalog, res *PublishResult) {
	amb := map[string]bool{}
	for _, a := range cat.Ambient {
		amb[a.ID] = true
	}
	for i := range cat.Tales {
		t := &cat.Tales[i]
		if t.Ambient != "" && !amb[t.Ambient] {
			res.Notes = append(res.Notes, fmt.Sprintf("tale %s: ambient %q not published, left empty", t.ID, t.Ambient))
			t.Ambient = ""
		}
	}
	presets := cat.Presets[:0]
	for _, p := range cat.Presets {
		ok := true
		for _, l := range p.Layers {
			ok = ok && amb[l.Ambient]
		}
		if !ok {
			res.Notes = append(res.Notes, "preset skipped (ambient not published): "+p.ID)
			continue
		}
		presets = append(presets, p)
	}
	cat.Presets = presets
	for _, n := range res.Notes {
		e.Log.Printf("publish: %s", n)
	}
}

type scriptRef struct {
	Tale   string
	Length int
}

var reScriptName = regexp.MustCompile(`^([a-z0-9]+(?:-[a-z0-9]+)*)\.(\d+)\.md$`)

// scriptRefs lists every {tale}.{len}.md in content/scripts and scripts/gold.
func (e *Env) scriptRefs() []scriptRef {
	seen := map[scriptRef]bool{}
	var out []scriptRef
	for _, dir := range []string{filepath.Join(e.Content, "scripts"), filepath.Join(e.Content, "scripts", "gold")} {
		ents, _ := os.ReadDir(dir)
		for _, en := range ents {
			m := reScriptName.FindStringSubmatch(en.Name())
			if en.IsDir() || m == nil {
				continue
			}
			l, _ := strconv.Atoi(m[2])
			r := scriptRef{m[1], l}
			if !seen[r] {
				seen[r] = true
				out = append(out, r)
			}
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Tale != out[j].Tale {
			return out[i].Tale < out[j].Tale
		}
		return out[i].Length < out[j].Length
	})
	return out
}

// Publish copies reviewed/gold scripts (plus drafts with o.Drafts) and ambient loops into the pages repo
// and rebuilds catalog.json (schema 2, CONTRACTS §3).
func (e *Env) Publish(o PublishOpts) (*PublishResult, error) {
	if o.Now.IsZero() {
		o.Now = time.Now()
	}
	pages, err := filepath.Abs(o.PagesDir)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(pages, 0o755); err != nil {
		return nil, err
	}
	catPath := filepath.Join(pages, "catalog.json")
	prev, err := catalog.Load(catPath, e.Cfg.Publish.BaseURL)
	if err != nil {
		return nil, err
	}
	cat := catalog.New(prev.BaseURL)
	cat.Schema = catalog.Schema
	if cat.BaseURL == "" {
		cat.BaseURL = e.Cfg.Publish.BaseURL
	}
	res := &PublishResult{Scripts: []string{}, Copied: []string{}, Skipped: []string{}, Notes: []string{}}

	for _, ref := range e.scriptRefs() {
		src, err := e.ScriptPath(ref.Tale, ref.Length)
		if err != nil {
			return nil, err
		}
		b, err := os.ReadFile(src)
		if err != nil {
			return nil, err
		}
		s, perr := script.Parse(b)
		name := fmt.Sprintf("%s.%d.md", ref.Tale, ref.Length)
		switch {
		case perr != nil:
			res.Skipped = append(res.Skipped, fmt.Sprintf("%s (parse: %v)", name, perr))
			continue
		case !publishable(s.Meta.Status, o.Drafts):
			res.Skipped = append(res.Skipped, fmt.Sprintf("%s (status %q)", name, s.Meta.Status))
			continue
		case s.Meta.ID != ref.Tale || s.Meta.LengthMin != ref.Length:
			res.Skipped = append(res.Skipped, fmt.Sprintf("%s (front matter id/length_min mismatch)", name))
			continue
		}
		rel := "scripts/" + name
		dst := filepath.Join(pages, filepath.FromSlash(rel))
		sum := sha256.Sum256(b)
		sha := hex.EncodeToString(sum[:])
		if dsha, _, err := fileSHA256(dst); err != nil || dsha != sha {
			if err := copyFile(src, dst); err != nil {
				return nil, err
			}
			res.Copied = append(res.Copied, rel)
		}
		est := e.Prosody().Estimate(s, script.EstimateParams{WPM: e.Cfg.Judge.WPM, RefSpeed: e.Cfg.Judge.RefSpeed, GapS: e.Cfg.Speech.GapS})
		free := e.Cfg.Publish.DefaultFree
		if old := prev.Tale(ref.Tale); old != nil {
			free = old.Free
		}
		if s.Meta.Free != nil {
			free = *s.Meta.Free
		}
		t := cat.Tale(ref.Tale)
		if t == nil {
			t = cat.UpsertTale(catalog.Tale{ID: ref.Tale, Title: s.Meta.Title, Age: s.Meta.Age, Setting: s.Meta.Setting,
				Ambient: s.Meta.Ambient, Free: free})
		}
		t.UpsertScript(catalog.Script{LengthMin: ref.Length, Path: rel, SHA256: sha, Bytes: int64(len(b)),
			EstDurationS: int(math.Round(est.TotalS))})
		res.Scripts = append(res.Scripts, rel)
	}

	if err := e.publishAmbient(cat, pages, res); err != nil {
		return nil, err
	}
	if err := e.loadPresets(cat); err != nil {
		return nil, err
	}
	e.reconcile(cat, res)

	res.Changed = cat.Finalize(prev, o.Now)
	if cat.Version < o.MinVersion {
		cat.Version, res.Changed = o.MinVersion, true
		cat.GeneratedAt = o.Now.UTC().Format(time.RFC3339)
	}
	res.Version = cat.Version
	if errs := cat.Validate(pages, prev); len(errs) > 0 {
		return res, fmt.Errorf("catalog invalid: %s", strings.Join(errs, "; "))
	}
	if res.Changed || len(res.Copied) > 0 {
		if err := cat.Save(catPath); err != nil {
			return nil, err
		}
		e.Log.Printf("publish: catalog v%d (%d tales, %d scripts, %d files copied)", cat.Version, len(cat.Tales), len(res.Scripts), len(res.Copied))
	} else {
		e.Log.Printf("publish: nothing changed (catalog v%d)", cat.Version)
	}
	if o.Commit && (res.Changed || len(res.Copied) > 0) {
		if err := gitCommit(pages, fmt.Sprintf("catalog v%d: %d scripts", cat.Version, len(res.Scripts))); err != nil {
			return res, err
		}
	}
	return res, nil
}

// publishAmbient copies content/ambient/{id}.opus with metadata from
// content/ambient/ambient.json ([{id,title,license,source,free}]) when present.
func (e *Env) publishAmbient(cat *catalog.Catalog, pages string, res *PublishResult) error {
	dir := filepath.Join(e.Content, "ambient")
	files, _ := filepath.Glob(filepath.Join(dir, "*.opus"))
	if len(files) == 0 {
		return nil
	}
	meta := map[string]catalog.Ambient{}
	var list []catalog.Ambient
	if b, err := os.ReadFile(filepath.Join(dir, "ambient.json")); err == nil {
		if err := json.Unmarshal(b, &list); err != nil {
			return fmt.Errorf("ambient.json: %w", err)
		}
		for _, a := range list {
			meta[a.ID] = a
		}
	}
	sort.Strings(files)
	for _, f := range files {
		id := strings.TrimSuffix(filepath.Base(f), ".opus")
		sha, size, err := fileSHA256(f)
		if err != nil {
			return err
		}
		rel := "ambient/" + id + ".opus"
		dst := filepath.Join(pages, rel)
		if dsha, _, err := fileSHA256(dst); err != nil || dsha != sha {
			if err := copyFile(f, dst); err != nil {
				return err
			}
			res.Copied = append(res.Copied, rel)
		}
		p, err := audio.Probe(dst)
		if err != nil {
			return err
		}
		a := meta[id]
		a.ID, a.Path, a.Bytes, a.SHA256 = id, rel, size, sha
		a.DurationS = math.Round(p.DurationS*10) / 10
		if a.Title == "" {
			a.Title = AmbientTitles[id]
		}
		cat.UpsertAmbient(a)
	}
	return nil
}

func (e *Env) loadPresets(cat *catalog.Catalog) error {
	b, err := os.ReadFile(filepath.Join(e.Content, "presets", "presets.json"))
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var ps []catalog.Preset
	if err := json.Unmarshal(b, &ps); err != nil {
		return fmt.Errorf("presets.json: %w", err)
	}
	cat.Presets = ps
	return nil
}

func gitCommit(dir, msg string) error {
	run := func(args ...string) error {
		cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
		cmd.Stdout, cmd.Stderr = os.Stderr, os.Stderr
		return cmd.Run()
	}
	args := []string{"add", "catalog.json", "scripts"}
	if _, err := os.Stat(filepath.Join(dir, "ambient")); err == nil {
		args = append(args, "ambient")
	}
	if err := run(args...); err != nil {
		return err
	}
	return run("commit", "-m", msg)
}

// publishable: reviewed and gold scripts, drafts only on request.
func publishable(status string, drafts bool) bool {
	return status == "reviewed" || status == "gold" || drafts && status == "draft"
}
