package audio

import (
	"math"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestEncodeClip(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed")
	}
	dir := t.TempDir()
	in := filepath.Join(dir, "in.wav")
	if _, err := Run("-f", "lavfi", "-i", "sine=f=220:d=2:r=24000", "-af", "volume=-12dB", in); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dir, "clip.m4a")
	d, err := EncodeClip(in, out, ClipOpts{LUFS: -23, TruePeak: -3, LRA: 20, Bitrate: "64k", SampleRate: 48000})
	if err != nil {
		t.Fatal(err)
	}
	if math.Abs(d-2) > 0.1 {
		t.Errorf("duration %.3f, want ≈2", d)
	}
	p, err := Probe(out)
	if err != nil {
		t.Fatal(err)
	}
	if p.Codec != "aac" || p.Channels != 1 || p.SampleRate != 48000 {
		t.Errorf("format %+v", p)
	}
	l, err := MeasureEBUR128(out)
	if err != nil {
		t.Fatal(err)
	}
	if math.Abs(l.IntegratedLUFS+23) > 1.5 {
		t.Errorf("loudness %.1f LUFS, want ≈ −23", l.IntegratedLUFS)
	}
}
