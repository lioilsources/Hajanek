package pipeline

import (
	"fmt"
	"math"
	"os"
	"path/filepath"

	"github.com/lioilsources/hajanek/forge/internal/audio"
	"github.com/lioilsources/hajanek/forge/internal/script"
	"github.com/lioilsources/hajanek/forge/internal/tts"
	"github.com/lioilsources/hajanek/forge/internal/wavio"
)

type ManifestItem struct {
	Kind    string  `json:"kind"`
	Section string  `json:"section"`
	Line    int     `json:"line"`
	Tone    string  `json:"tone,omitempty"`
	Text    string  `json:"text,omitempty"`
	Speed   float64 `json:"speed,omitempty"`
	GainDB  float64 `json:"gain_db,omitempty"`
	Lowpass float64 `json:"lowpass_hz,omitempty"`
	Key     string  `json:"key,omitempty"`
	StartS  float64 `json:"start_s"`
	EndS    float64 `json:"end_s"`
}

// VoiceManifest is written next to voice.wav and consumed by qa/publish.
type VoiceManifest struct {
	Stamp      string         `json:"stamp"`
	Script     string         `json:"script"`
	Meta       script.Meta    `json:"meta"`
	Engine     string         `json:"engine"`
	Voice      string         `json:"voice"`
	LengthMin  int            `json:"length_min"`
	DurationS  float64        `json:"duration_s"`
	Text       string         `json:"text"`
	Silences   [][2]float64   `json:"silences"` // intended silence spans (gaps + pauses)
	Items      []ManifestItem `json:"items"`
	CacheHits  int            `json:"cache_hits"`
	Synthesize int            `json:"synthesized"`
}

type VoiceOpts struct {
	Tale, Voice string
	Length      int
	AllowDraft  bool
	ScriptPath  string // optional override
	Synth       tts.Synthesizer
}

func round3(f float64) float64 { return math.Round(f*1000) / 1000 }

// Voice synthesizes all utterances (cached) and assembles voice.wav with silences.
func (e *Env) Voice(o VoiceOpts) (*VoiceManifest, error) {
	path := o.ScriptPath
	var err error
	if path == "" {
		if path, err = e.ScriptPath(o.Tale, o.Length); err != nil {
			return nil, err
		}
	}
	src, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	s, err := script.Parse(src)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if s.Meta.ID != o.Tale {
		return nil, fmt.Errorf("%s: id %q does not match tale %q", path, s.Meta.ID, o.Tale)
	}
	switch s.Meta.Status {
	case "reviewed", "gold":
	default:
		if !o.AllowDraft {
			return nil, fmt.Errorf("%s: status %q awaits human review (set status: reviewed or pass --allow-draft)", path, s.Meta.Status)
		}
	}
	v, ok := e.Cfg.Voice(o.Voice)
	if !ok {
		return nil, fmt.Errorf("unknown voice %q (see config.yaml voices)", o.Voice)
	}
	engine := e.Cfg.TTS.Engine
	rate := e.Cfg.TTS.SampleRate
	gap := e.Cfg.TTS.GapS
	prosody := e.Prosody()
	plan := prosody.Plan(s)

	dir := e.TrackDir(o.Tale, o.Voice, o.Length)
	outWav := filepath.Join(dir, "voice.wav")
	manPath := filepath.Join(dir, "voice.json")
	stamp := hashParts("voice/v1", string(src), engine, v, rate, gap, prosody)
	var prev VoiceManifest
	if !e.Force && readJSON(manPath, &prev) == nil && prev.Stamp == stamp {
		if _, err := os.Stat(outWav); err == nil {
			e.Log.Printf("voice: %s up to date", outWav)
			return &prev, nil
		}
	}

	ref := v.Ref
	if ref != "" && !filepath.IsAbs(ref) {
		ref = filepath.Join(e.Forge, ref)
	}
	cacheDir := filepath.Join(e.Work, "_cache", "tts", engine, o.Voice)
	prepDir := filepath.Join(dir, "utt")
	for _, d := range []string{cacheDir, prepDir} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return nil, err
		}
	}
	synth := o.Synth
	defer func() {
		if synth != nil && o.Synth == nil {
			// Shutting down the TTS worker; outputs are already written and verified.
			_ = synth.Close()
		}
	}()

	m := &VoiceManifest{Stamp: stamp, Script: path, Meta: s.Meta, Engine: engine, Voice: o.Voice,
		LengthMin: o.Length, Text: s.PlainText()}
	preps := make([]string, len(s.Items))
	for i, it := range s.Items {
		if it.Kind != script.Utterance {
			continue
		}
		p := plan[i]
		speed := round3(p.Speed)
		key := tts.CacheKey(engine, o.Voice, it.Text, speed, string(it.Tone))
		raw := filepath.Join(cacheDir, key+".wav")
		meta := filepath.Join(cacheDir, key+".json")
		var resp tts.Response
		if readJSON(meta, &resp) == nil && fileExists(raw) {
			m.CacheHits++
		} else {
			if synth == nil {
				w, err := tts.Start(e.Cfg.Python.Cmd, e.forgePath(e.Cfg.Python.TTSWorker), engine)
				if err != nil {
					return nil, err
				}
				synth = w
			}
			resp, err = synth.Synthesize(tts.Request{Text: it.Text, Speed: speed, Style: string(it.Tone), VoiceRef: ref, OutPath: raw})
			if err != nil {
				return nil, fmt.Errorf("line %d: %w", it.Line, err)
			}
			if err := writeJSON(meta, resp); err != nil {
				return nil, err
			}
			m.Synthesize++
		}
		lp := 0.0
		if !resp.StyleApplied {
			lp = p.LowpassHz
		}
		prep := filepath.Join(prepDir, fmt.Sprintf("%s_%+.2f_%.0f.wav", key[:16], p.GainDB, lp))
		if !fileExists(prep) {
			if err := audio.PrepUtterance(raw, prep+".tmp.wav", rate, p.GainDB, lp); err != nil {
				return nil, err
			}
			if err := os.Rename(prep+".tmp.wav", prep); err != nil {
				return nil, err
			}
		}
		preps[i] = prep
		m.Items = append(m.Items, ManifestItem{Kind: "utterance", Section: it.Section, Line: it.Line, Tone: string(it.Tone),
			Text: it.Text, Speed: speed, GainDB: round3(p.GainDB), Lowpass: lp, Key: key})
	}
	if synth != nil && o.Synth == nil {
		if err := synth.Close(); err != nil {
			e.Log.Printf("voice: tts worker exit: %v", err)
		}
		synth = nil
	}

	// Assemble.
	tmp := outWav + ".tmp"
	w, err := wavio.Create(tmp, rate)
	if err != nil {
		return nil, err
	}
	now := func() float64 { return float64(w.Samples()) / float64(rate) }
	var silStart = -1.0
	closeSilence := func() {
		if silStart >= 0 {
			m.Silences = append(m.Silences, [2]float64{round3(silStart), round3(now())})
			silStart = -1
		}
	}
	openSilence := func() {
		if silStart < 0 {
			silStart = now()
		}
	}
	ui := 0
	for i, it := range s.Items {
		switch it.Kind {
		case script.Utterance:
			closeSilence()
			pcm, err := wavio.Read(preps[i])
			if err != nil {
				_ = w.Close()
				return nil, err
			}
			if pcm.SampleRate != rate {
				_ = w.Close()
				return nil, fmt.Errorf("%s: sample rate %d != %d", preps[i], pcm.SampleRate, rate)
			}
			start := now()
			if err := w.Write(pcm.Samples); err != nil {
				_ = w.Close()
				return nil, err
			}
			m.Items[ui].StartS, m.Items[ui].EndS = round3(start), round3(now())
			ui++
			openSilence()
			if err := w.Silence(gap); err != nil {
				_ = w.Close()
				return nil, err
			}
		case script.Pause:
			openSilence()
			start := now()
			if err := w.Silence(it.PauseS); err != nil {
				_ = w.Close()
				return nil, err
			}
			m.Items = append(m.Items[:ui], append([]ManifestItem{{Kind: "pause", Section: it.Section, Line: it.Line,
				StartS: round3(start), EndS: round3(now())}}, m.Items[ui:]...)...)
			ui++
		}
	}
	closeSilence()
	m.DurationS = round3(now())
	if err := w.Close(); err != nil {
		return nil, err
	}
	if err := os.Rename(tmp, outWav); err != nil {
		return nil, err
	}
	if err := writeJSON(manPath, m); err != nil {
		return nil, err
	}
	e.Log.Printf("voice: %s %.1fs (%d synthesized, %d cached)", outWav, m.DurationS, m.Synthesize, m.CacheHits)
	return m, nil
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
