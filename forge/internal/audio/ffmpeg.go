// Package audio wraps ffmpeg/ffprobe for ambient loops, voice clips and measurement.
package audio

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// Run executes ffmpeg and returns stderr.
func Run(args ...string) (string, error) {
	full := append([]string{"-hide_banner", "-nostdin", "-y"}, args...)
	cmd := exec.Command("ffmpeg", full...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		s := stderr.String()
		if len(s) > 2000 {
			s = s[len(s)-2000:]
		}
		return stderr.String(), fmt.Errorf("ffmpeg %s: %w\n%s", strings.Join(args, " "), err, s)
	}
	return stderr.String(), nil
}

type ProbeInfo struct {
	DurationS  float64 `json:"duration_s"`
	Codec      string  `json:"codec"`
	SampleRate int     `json:"sample_rate"`
	Channels   int     `json:"channels"`
	BitRate    int     `json:"bit_rate"`
	Bytes      int64   `json:"bytes"`
}

func Probe(path string) (ProbeInfo, error) {
	out, err := exec.Command("ffprobe", "-v", "error", "-print_format", "json",
		"-show_format", "-show_streams", path).Output()
	if err != nil {
		return ProbeInfo{}, fmt.Errorf("ffprobe %s: %w", path, err)
	}
	var p struct {
		Streams []struct {
			CodecName  string `json:"codec_name"`
			SampleRate string `json:"sample_rate"`
			Channels   int    `json:"channels"`
		} `json:"streams"`
		Format struct {
			Duration string `json:"duration"`
			BitRate  string `json:"bit_rate"`
			Size     string `json:"size"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &p); err != nil {
		return ProbeInfo{}, err
	}
	info := ProbeInfo{}
	info.DurationS, _ = strconv.ParseFloat(p.Format.Duration, 64)
	info.BitRate, _ = strconv.Atoi(p.Format.BitRate)
	info.Bytes, _ = strconv.ParseInt(p.Format.Size, 10, 64)
	if len(p.Streams) > 0 {
		info.Codec = p.Streams[0].CodecName
		info.SampleRate, _ = strconv.Atoi(p.Streams[0].SampleRate)
		info.Channels = p.Streams[0].Channels
	}
	return info, nil
}

type Loudness struct {
	IntegratedLUFS float64 `json:"integrated_lufs"`
	TruePeakDBTP   float64 `json:"true_peak_dbtp"`
	LRA            float64 `json:"lra"`
}

var (
	reI    = regexp.MustCompile(`(?m)^\s*I:\s+(-?[\d.]+|-inf) LUFS`)
	reLRA  = regexp.MustCompile(`(?m)^\s*LRA:\s+(-?[\d.]+) LU`)
	rePeak = regexp.MustCompile(`(?m)^\s*Peak:\s+(-?[\d.]+|-inf) dBFS`)
)

// MeasureEBUR128 measures integrated loudness, true peak and LRA with ffmpeg ebur128.
func MeasureEBUR128(path string) (Loudness, error) {
	s, err := Run("-nostats", "-i", path, "-filter_complex", "ebur128=peak=true", "-f", "null", "-")
	if err != nil {
		return Loudness{}, err
	}
	// Use the summary block (last occurrence).
	if i := strings.LastIndex(s, "Summary:"); i >= 0 {
		s = s[i:]
	}
	var l Loudness
	if m := reI.FindStringSubmatch(s); m != nil {
		l.IntegratedLUFS = parseF(m[1])
	}
	if m := reLRA.FindStringSubmatch(s); m != nil {
		l.LRA = parseF(m[1])
	}
	if m := rePeak.FindStringSubmatch(s); m != nil {
		l.TruePeakDBTP = parseF(m[1])
	}
	return l, nil
}

func parseF(s string) float64 {
	if s == "-inf" {
		return -999
	}
	f, _ := strconv.ParseFloat(s, 64)
	return f
}

type loudnormStats struct {
	InputI       string `json:"input_i"`
	InputTP      string `json:"input_tp"`
	InputLRA     string `json:"input_lra"`
	InputThresh  string `json:"input_thresh"`
	TargetOffset string `json:"target_offset"`
	NormType     string `json:"normalization_type"`
}

func loudnormFirstPass(filterComplex, in, out string, extraInputs []string, lufs, tp, lra float64) (loudnormStats, error) {
	fc := filterComplex + fmt.Sprintf(";[pre]loudnorm=I=%g:TP=%g:LRA=%g:print_format=json[%s]", lufs, tp, lra, out)
	args := append([]string{"-i", in}, extraInputs...)
	args = append(args, "-filter_complex", fc, "-map", "["+out+"]", "-f", "null", "-")
	s, err := Run(args...)
	if err != nil {
		return loudnormStats{}, err
	}
	i := strings.LastIndex(s, "{")
	j := strings.LastIndex(s, "}")
	if i < 0 || j < i {
		return loudnormStats{}, fmt.Errorf("loudnorm: no stats in output")
	}
	var st loudnormStats
	if err := json.Unmarshal([]byte(s[i:j+1]), &st); err != nil {
		return st, fmt.Errorf("loudnorm stats: %w", err)
	}
	return st, nil
}

func loudnormSecond(st loudnormStats, lufs, tp, lra float64) string {
	return fmt.Sprintf("loudnorm=I=%g:TP=%g:LRA=%g:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true:print_format=json",
		lufs, tp, lra, st.InputI, st.InputTP, st.InputLRA, st.InputThresh, st.TargetOffset)
}

// ClipOpts sets the voice clip format (CONTRACTS §8: AAC mono 48 kHz, −23 LUFS).
type ClipOpts struct {
	LUFS       float64
	TruePeak   float64
	LRA        float64
	Bitrate    string
	SampleRate int
}

// EncodeClip normalizes a TTS output with two-pass linear loudnorm and encodes
// it as AAC in an .m4a container. Returns the output duration in seconds.
func EncodeClip(in, out string, o ClipOpts) (float64, error) {
	g := fmt.Sprintf("[0:a]aresample=%d,aformat=channel_layouts=mono[pre]", o.SampleRate)
	st, err := loudnormFirstPass(g, in, "ln", nil, o.LUFS, o.TruePeak, o.LRA)
	if err != nil {
		return 0, err
	}
	fc := g + ";[pre]" + loudnormSecond(st, o.LUFS, o.TruePeak, o.LRA) + fmt.Sprintf(",aresample=%d[out]", o.SampleRate)
	if _, err := Run("-i", in, "-filter_complex", fc, "-map", "[out]",
		"-c:a", "aac", "-b:a", o.Bitrate, "-ac", "1", "-ar", strconv.Itoa(o.SampleRate),
		"-map_metadata", "-1", "-movflags", "+faststart", "-f", "mp4", out); err != nil {
		return 0, err
	}
	p, err := Probe(out)
	if err != nil {
		return 0, err
	}
	return p.DurationS, nil
}
