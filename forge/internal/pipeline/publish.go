package pipeline

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/audio"
	"github.com/lioilsources/hajanek/forge/internal/catalog"
)

// AmbientTitles are the UI names from CONTRACTS §4.
var AmbientTitles = map[string]string{
	"sea": "Moře", "rain": "Déšť na střechu", "stream": "Potůček", "fireplace": "Krb",
	"wind": "Vítr v korunách", "night-meadow": "Noční louka", "pink-noise": "Růžový šum", "brown-noise": "Hnědý šum",
}

type PublishOpts struct {
	PagesDir string
	Commit   bool
	Only     *TrackID // publish only this track (still keeps the others in the catalog)
	Now      time.Time
}

type TrackID struct {
	Tale, Voice string
	Length      int
}

type PublishResult struct {
	Changed bool     `json:"changed"`
	Version int      `json:"version"`
	Tracks  []string `json:"tracks"`
	Copied  []string `json:"copied"`
	Skipped []string `json:"skipped"`
	Notes   []string `json:"notes"`
}

// reconcile keeps the catalog acceptable for hajanek-api: no tales without
// tracks, no references to ambient loops that are not published yet.
func (e *Env) reconcile(cat *catalog.Catalog, res *PublishResult) {
	amb := map[string]bool{}
	for _, a := range cat.Ambient {
		amb[a.ID] = true
	}
	tales := cat.Tales[:0]
	for _, t := range cat.Tales {
		if len(t.Tracks) == 0 {
			res.Notes = append(res.Notes, "dropped tale without tracks: "+t.ID)
			continue
		}
		if t.Ambient != "" && !amb[t.Ambient] {
			res.Notes = append(res.Notes, fmt.Sprintf("tale %s: ambient %q not published, left empty", t.ID, t.Ambient))
			t.Ambient = ""
		}
		tales = append(tales, t)
	}
	cat.Tales = tales
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

// readyTracks lists work dirs with master.opus and a passing qa.json.
func (e *Env) readyTracks() ([]TrackID, []string) {
	var ok []TrackID
	var skipped []string
	matches, _ := filepath.Glob(filepath.Join(e.Work, "*", "*", "*", "master.opus"))
	sort.Strings(matches)
	for _, m := range matches {
		dir := filepath.Dir(m)
		l, err := strconv.Atoi(filepath.Base(dir))
		if err != nil {
			continue
		}
		id := TrackID{Tale: filepath.Base(filepath.Dir(filepath.Dir(dir))), Voice: filepath.Base(filepath.Dir(dir)), Length: l}
		var q QAReport
		if readJSON(filepath.Join(dir, "qa.json"), &q) != nil || !q.OK {
			skipped = append(skipped, fmt.Sprintf("%s/%s/%d (qa missing or failed)", id.Tale, id.Voice, id.Length))
			continue
		}
		ok = append(ok, id)
	}
	return ok, skipped
}

// Publish copies passing tracks into the pages repo and merges catalog.json.
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
	cat := prev.Clone()
	if cat.BaseURL == "" {
		cat.BaseURL = e.Cfg.Publish.BaseURL
	}
	res := &PublishResult{Tracks: []string{}, Copied: []string{}, Skipped: []string{}, Notes: []string{}}

	cat.Voices = cat.Voices[:0]
	for _, v := range e.Cfg.Voices {
		cat.Voices = append(cat.Voices, catalog.Voice{ID: v.ID, Label: v.Label, Free: v.Free})
	}

	tracks, skipped := e.readyTracks()
	res.Skipped = append(res.Skipped, skipped...)
	for _, id := range tracks {
		if o.Only != nil && *o.Only != id {
			continue
		}
		dir := e.TrackDir(id.Tale, id.Voice, id.Length)
		var vm VoiceManifest
		if err := readJSON(filepath.Join(dir, "voice.json"), &vm); err != nil {
			return nil, err
		}
		src := filepath.Join(dir, "master.opus")
		sha, size, err := fileSHA256(src)
		if err != nil {
			return nil, err
		}
		rel := fmt.Sprintf("audio/%s/%s/%d.opus", id.Tale, id.Voice, id.Length)
		dst := filepath.Join(pages, filepath.FromSlash(rel))
		if dsha, _, err := fileSHA256(dst); err != nil || dsha != sha {
			if err := copyFile(src, dst); err != nil {
				return nil, err
			}
			res.Copied = append(res.Copied, rel)
		}
		p, err := audio.Probe(dst)
		if err != nil {
			return nil, err
		}
		free := e.Cfg.Publish.DefaultFree
		if old := prev.Tale(id.Tale); old != nil {
			free = old.Free
		}
		if vm.Meta.Free != nil {
			free = *vm.Meta.Free
		}
		t := cat.UpsertTale(catalog.Tale{ID: id.Tale, Title: vm.Meta.Title, Age: vm.Meta.Age, Setting: vm.Meta.Setting,
			Ambient: vm.Meta.Ambient, Free: free})
		t.UpsertTrack(catalog.Track{Voice: id.Voice, LengthMin: id.Length, Path: rel,
			DurationS: math.Round(p.DurationS*10) / 10, Bytes: size, SHA256: sha})
		res.Tracks = append(res.Tracks, rel)
	}

	if err := e.publishAmbient(cat, pages, res); err != nil {
		return nil, err
	}
	if err := e.loadPresets(cat); err != nil {
		return nil, err
	}
	e.reconcile(cat, res)

	res.Changed = cat.Finalize(prev, o.Now)
	res.Version = cat.Version
	if errs := cat.Validate(pages); len(errs) > 0 {
		return res, fmt.Errorf("catalog invalid: %s", strings.Join(errs, "; "))
	}
	if res.Changed || len(res.Copied) > 0 {
		if err := cat.Save(catPath); err != nil {
			return nil, err
		}
		e.Log.Printf("publish: catalog v%d (%d tracks, %d copied)", cat.Version, len(res.Tracks), len(res.Copied))
	} else {
		e.Log.Printf("publish: nothing changed (catalog v%d)", cat.Version)
	}
	if o.Commit && (res.Changed || len(res.Copied) > 0) {
		if err := gitCommit(pages, fmt.Sprintf("catalog v%d: %d tracks", cat.Version, len(res.Tracks))); err != nil {
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
	if err := run("add", "catalog.json", "audio", "ambient"); err != nil {
		// ambient/ may not exist yet
		if err := run("add", "catalog.json", "audio"); err != nil {
			return err
		}
	}
	return run("commit", "-m", msg)
}
