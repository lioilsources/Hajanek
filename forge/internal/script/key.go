package script

import (
	"crypto/sha256"
	"encoding/hex"
)

// UtteranceKey identifies a voiced clip (CONTRACTS §7):
// hex(sha256(voice_id + 0x1F + tone + 0x1F + text)), text already normalized.
func UtteranceKey(voiceID string, tone Tone, text string) string {
	h := sha256.Sum256([]byte(voiceID + "\x1f" + string(tone) + "\x1f" + text))
	return hex.EncodeToString(h[:])
}

// Step is one element of the playback sequence: an utterance or a pause.
type Step struct {
	Type    string  `json:"type"` // utterance | pause
	Section string  `json:"section,omitempty"`
	Tone    Tone    `json:"tone,omitempty"`
	Text    string  `json:"text,omitempty"`
	Key     string  `json:"key,omitempty"`
	Seconds float64 `json:"seconds,omitempty"`
}

// Sequence returns the playback sequence with utterance keys for voiceID.
func (s *Script) Sequence(voiceID string) []Step {
	out := make([]Step, 0, len(s.Items))
	for _, it := range s.Items {
		if it.Kind == Pause {
			out = append(out, Step{Type: "pause", Seconds: it.PauseS})
			continue
		}
		out = append(out, Step{Type: "utterance", Section: it.Section, Tone: it.Tone, Text: it.Text,
			Key: UtteranceKey(voiceID, it.Tone, it.Text)})
	}
	return out
}
