package pipeline

import (
	"os"
	"path/filepath"

	"github.com/lioilsources/hajanek/forge/internal/audio"
)

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
