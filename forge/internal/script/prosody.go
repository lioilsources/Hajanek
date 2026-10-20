package script

// Prosody maps tones to speech speed (CONTRACTS §2) and models the linear
// slow-down in RampSection. Volume is handled by the player in the app.
type Prosody struct {
	Speeds      map[Tone]float64
	RampSection string
	RampSpeedTo float64
}

// Speed returns the tone's speed, falling back to soft.
func (p Prosody) Speed(t Tone) float64 {
	if v := p.Speeds[t]; v > 0 {
		return v
	}
	return p.Speeds[Soft]
}

// Plan returns the per-item speed (0 for pauses): the tone speed, lowered by
// the linear ramp in RampSection (the ramp never makes an utterance faster).
func (p Prosody) Plan(s *Script) []float64 {
	out := make([]float64, len(s.Items))
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
	base := p.Speed(Soft)
	for i, it := range s.Items {
		if it.Kind != Utterance {
			continue
		}
		sp := p.Speed(it.Tone)
		if t, ok := rampPos[i]; ok && p.RampSpeedTo > 0 {
			sp = min(sp, base+(p.RampSpeedTo-base)*t)
		}
		out[i] = sp
	}
	return out
}

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
			wps := ep.WPM / 60 * plan[i] / ep.RefSpeed
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
