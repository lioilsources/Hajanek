package script

import "math"

type ToneParams struct {
	Speed     float64
	GainDB    float64
	LowpassHz float64 // fallback when the engine has no native style
}

type Prosody struct {
	Tones        map[Tone]ToneParams
	RampSection  string
	RampSpeedTo  float64
	RampGainToDB float64
}

// Plan returns per-item TTS parameters (zero value for pauses), applying the
// tone mapping and the linear ramp in RampSection. The ramp never makes an
// utterance faster/louder than its tone (min of both).
func (p Prosody) Plan(s *Script) []ToneParams {
	out := make([]ToneParams, len(s.Items))
	base := p.Tones[Soft]
	var rampIdx []int
	for i, it := range s.Items {
		if it.Kind == Utterance && it.Section == p.RampSection {
			rampIdx = append(rampIdx, i)
		}
	}
	rampPos := map[int]float64{}
	for k, i := range rampIdx {
		t := 1.0
		if len(rampIdx) > 1 {
			t = float64(k) / float64(len(rampIdx)-1)
		}
		rampPos[i] = t
	}
	for i, it := range s.Items {
		if it.Kind != Utterance {
			continue
		}
		tp := p.Tones[it.Tone]
		if tp.Speed == 0 {
			tp.Speed = base.Speed
		}
		if t, ok := rampPos[i]; ok && p.RampSpeedTo > 0 {
			tp.Speed = math.Min(tp.Speed, lerp(base.Speed, p.RampSpeedTo, t))
			tp.GainDB = math.Min(tp.GainDB, lerp(base.GainDB, p.RampGainToDB, t))
		}
		out[i] = tp
	}
	return out
}

func lerp(a, b, t float64) float64 { return a + (b-a)*t }

type EstimateParams struct {
	WPM      float64 // words per minute at RefSpeed
	RefSpeed float64
	GapS     float64 // silence after each utterance
}

type Estimate struct {
	TotalS    float64            `json:"total_s"`
	SpeechS   float64            `json:"speech_s"`
	PauseS    float64            `json:"pause_s"`
	Words     int                `json:"words"`
	SectionsS map[string]float64 `json:"sections_s"`
}

// Estimate predicts the spoken duration from word counts, tone speeds and pauses.
func (p Prosody) Estimate(s *Script, ep EstimateParams) Estimate {
	plan := p.Plan(s)
	e := Estimate{SectionsS: map[string]float64{}}
	for i, it := range s.Items {
		var d float64
		switch it.Kind {
		case Pause:
			d = it.PauseS
			e.PauseS += d
		case Utterance:
			n := len(Words(it.Text))
			e.Words += n
			wps := ep.WPM / 60 * plan[i].Speed / ep.RefSpeed
			sp := float64(n) / wps
			e.SpeechS += sp
			d = sp + ep.GapS
			e.PauseS += ep.GapS
		}
		e.SectionsS[it.Section] += d
		e.TotalS += d
	}
	return e
}
