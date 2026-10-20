package audio

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// MasterResult describes a mastered file: loudnorm first pass, measurement and probe.
type MasterResult struct {
	FirstPass   map[string]string `json:"first_pass"`
	NormType    string            `json:"normalization_type"`
	Measured    Loudness          `json:"measured"`
	Probe       ProbeInfo         `json:"probe"`
	FilterGraph string            `json:"filter_graph"`
}

func normType(stderr string) string {
	i := strings.LastIndex(stderr, "\"normalization_type\"")
	if i < 0 {
		return ""
	}
	rest := stderr[i+len("\"normalization_type\""):]
	parts := strings.SplitN(rest, "\"", 3)
	if len(parts) >= 2 {
		return parts[1]
	}
	return ""
}

type AmbientOpts struct {
	CrossfadeS float64
	LUFS       float64
	TruePeak   float64
	LRA        float64
	Bitrate    string
}

// AmbientLoop makes a seamless loop: the last N seconds are crossfaded into the
// start, so the output (length L-N) ends exactly where its head continues.
func AmbientLoop(in, out string, o AmbientOpts) (*MasterResult, error) {
	p, err := Probe(in)
	if err != nil {
		return nil, err
	}
	L, N := p.DurationS, o.CrossfadeS
	if L < 2*N+1 {
		return nil, fmt.Errorf("input too short (%.1fs) for %.1fs crossfade", L, N)
	}
	f := func(x float64) string { return strconv.FormatFloat(x, 'f', 4, 64) }
	g := "[0:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,asplit=3[a][b][c];" +
		"[a]atrim=start=0:duration=" + f(N) + ",asetpts=PTS-STARTPTS,afade=t=in:st=0:d=" + f(N) + ":curve=qsin[h];" +
		"[c]atrim=start=" + f(L-N) + ":duration=" + f(N) + ",asetpts=PTS-STARTPTS,afade=t=out:st=0:d=" + f(N) + ":curve=qsin[t];" +
		"[h][t]amix=inputs=2:normalize=0:duration=shortest[x];" +
		"[b]atrim=start=" + f(N) + ":end=" + f(L-N) + ",asetpts=PTS-STARTPTS[body];" +
		"[x][body]concat=n=2:v=0:a=1[pre]"
	st, err := loudnormFirstPass(g, in, "ln", nil, o.LUFS, o.TruePeak, o.LRA)
	if err != nil {
		return nil, err
	}
	fc := g + ";[pre]" + loudnormSecond(st, o.LUFS, o.TruePeak, o.LRA) + ",aresample=48000[out]"
	s, err := Run("-i", in, "-filter_complex", fc, "-map", "[out]",
		"-c:a", "libopus", "-b:a", o.Bitrate, "-vbr", "on", "-application", "audio",
		"-ac", "2", "-ar", "48000", "-map_metadata", "-1", out)
	if err != nil {
		return nil, err
	}
	res := &MasterResult{FilterGraph: fc, NormType: normType(s)}
	b, _ := json.Marshal(st)
	_ = json.Unmarshal(b, &res.FirstPass)
	if res.Measured, err = MeasureEBUR128(out); err != nil {
		return nil, err
	}
	if res.Probe, err = Probe(out); err != nil {
		return nil, err
	}
	return res, nil
}
