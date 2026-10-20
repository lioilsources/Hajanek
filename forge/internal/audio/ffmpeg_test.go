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
	in2 := filepath.Join(dir, "in2.wav")
	if _, err := Run("-f", "lavfi", "-i", "sine=f=330:d=1:r=24000", in2); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dir, "clip.m4a")
	// (2 s + 0.5 s gap + 1 s) / tempo 0.875 = 4 s
	d, err := EncodeClip([]string{in, in2}, 0.5, 0.875, out, ClipOpts{LUFS: -23, TruePeak: -3, LRA: 20, Bitrate: "64k", SampleRate: 48000})
	if err != nil {
		t.Fatal(err)
	}
	if math.Abs(d-4) > 0.1 {
		t.Errorf("duration %.3f, want ≈4", d)
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

func TestEncodeClipSilent(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed")
	}
	dir := t.TempDir()
	o := ClipOpts{LUFS: -23, TruePeak: -3, LRA: 20, Bitrate: "64k", SampleRate: 48000}
	// A 0.3 s word is shorter than the 400 ms EBU R128 block, still measurable.
	word := filepath.Join(dir, "word.wav")
	if _, err := Run("-f", "lavfi", "-i", "sine=f=220:d=0.3", word); err != nil {
		t.Fatal(err)
	}
	d, l, err := MeasureTake(word)
	if err != nil || math.Abs(d-0.3) > 0.05 || l < -30 {
		t.Errorf("MeasureTake(word) = %.2f s, %.1f LUFS, %v", d, l, err)
	}
	if d, err := EncodeClip([]string{word}, 0, 1, filepath.Join(dir, "w.m4a"), o); err != nil || d > 0.45 {
		t.Errorf("EncodeClip(word) = %.2f s, %v (must not be padded)", d, err)
	}
	silent := filepath.Join(dir, "silent.wav")
	if _, err := Run("-f", "lavfi", "-i", "anullsrc=r=24000:cl=mono", "-t", "1", silent); err != nil {
		t.Fatal(err)
	}
	if _, err := EncodeClip([]string{silent}, 0, 1, filepath.Join(dir, "s.m4a"), o); err == nil {
		t.Error("want error for silence")
	}
	if _, l, _ := MeasureTake(silent); l > -70 {
		t.Errorf("MeasureTake(silent) = %.1f LUFS", l)
	}
}
