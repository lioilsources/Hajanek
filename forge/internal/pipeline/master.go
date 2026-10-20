package pipeline

import (
	"fmt"
	"math"
	"os"
	"path/filepath"

	"github.com/lioilsources/hajanek/forge/internal/audio"
)

type MasterReport struct {
	Stamp  string              `json:"stamp"`
	Input  string              `json:"input"`
	Output string              `json:"output"`
	Result *audio.MasterResult `json:"result"`
	OK     bool                `json:"ok"`
	Errors []string            `json:"errors"`
}

func (e *Env) masterOpts() audio.MasterOpts {
	m := e.Cfg.Master
	return audio.MasterOpts{HighpassHz: m.HighpassHz, LowpassHz: m.LowpassHz, Deesser: m.Deesser, Reverb: m.Reverb,
		Aecho: m.Aecho, AfirIRS: m.AfirIRS, AfirWet: m.AfirWet, LUFS: m.LUFS, TruePeak: m.TruePeak, LRA: m.LRA, Bitrate: m.Bitrate}
}

// Master turns voice.wav into master.opus (CONTRACTS §5).
func (e *Env) Master(tale, voice string, length int) (*MasterReport, error) {
	dir := e.TrackDir(tale, voice, length)
	var vm VoiceManifest
	if err := readJSON(filepath.Join(dir, "voice.json"), &vm); err != nil {
		return nil, fmt.Errorf("master: run `forge voice` first: %w", err)
	}
	in := filepath.Join(dir, "voice.wav")
	out := filepath.Join(dir, "master.opus")
	repPath := filepath.Join(dir, "master.json")
	opts := e.masterOpts()
	stamp := hashParts("master/v1", vm.Stamp, opts)
	var prev MasterReport
	if !e.Force && readJSON(repPath, &prev) == nil && prev.Stamp == stamp && prev.OK && fileExists(out) {
		e.Log.Printf("master: %s up to date", out)
		return &prev, nil
	}
	tmp := filepath.Join(dir, "master.tmp.opus")
	res, err := audio.Master(in, tmp, opts)
	if err != nil {
		return nil, err
	}
	if err := os.Rename(tmp, out); err != nil {
		return nil, err
	}
	rep := &MasterReport{Stamp: stamp, Input: in, Output: out, Result: res, Errors: []string{}}
	l := res.Measured
	if math.Abs(l.IntegratedLUFS-opts.LUFS) > 1.0 {
		rep.Errors = append(rep.Errors, fmt.Sprintf("integrated %.1f LUFS, target %.0f", l.IntegratedLUFS, opts.LUFS))
	}
	if l.TruePeakDBTP > opts.TruePeak+0.5 {
		rep.Errors = append(rep.Errors, fmt.Sprintf("true peak %.1f dBTP > %.0f", l.TruePeakDBTP, opts.TruePeak))
	}
	if p := res.Probe; p.Codec != "opus" || p.Channels != 1 || p.SampleRate != 48000 {
		rep.Errors = append(rep.Errors, fmt.Sprintf("unexpected format %s %dch %dHz", p.Codec, p.Channels, p.SampleRate))
	}
	rep.OK = len(rep.Errors) == 0
	if err := writeJSON(repPath, rep); err != nil {
		return nil, err
	}
	e.Log.Printf("master: %s %.1fs, %.1f LUFS, TP %.1f dBTP (%s)", out, res.Probe.DurationS, l.IntegratedLUFS, l.TruePeakDBTP, res.NormType)
	if !rep.OK {
		return rep, fmt.Errorf("master: %v", rep.Errors)
	}
	return rep, nil
}

// MasterAmbient makes a seamless −30 LUFS stereo Opus loop.
func (e *Env) MasterAmbient(in, out string) (*audio.MasterResult, error) {
	a := e.Cfg.Ambient
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
		return nil, err
	}
	res, err := audio.AmbientLoop(in, out, audio.AmbientOpts{CrossfadeS: a.CrossfadeS, LUFS: a.LUFS, TruePeak: a.TruePeak, LRA: a.LRA, Bitrate: a.Bitrate})
	if err != nil {
		return nil, err
	}
	e.Log.Printf("master-ambient: %s %.1fs, %.1f LUFS, TP %.1f dBTP", out, res.Probe.DurationS, res.Measured.IntegratedLUFS, res.Measured.TruePeakDBTP)
	return res, nil
}
