// Package jobs is a SQLite-backed generation job queue. Workers on the Spark
// pull jobs over HTTP (claim → heartbeat → complete); leases that expire are
// requeued until max attempts is reached.
package jobs

import (
	"errors"
	"fmt"
	"slices"

	"github.com/lioilsources/hajanek/api/internal/catalog"
	"github.com/lioilsources/hajanek/api/internal/ids"
)

type Kind string

const (
	KindScript  Kind = "script"  // tale → script.md
	KindVoice   Kind = "voice"   // script → raw TTS
	KindMaster  Kind = "master"  // raw → mastered opus + QA
	KindPublish Kind = "publish" // new catalog version → Pages
	KindTale    Kind = "tale"    // whole pipeline for one tale

	// Parent voices (ADR-003). Voice is the voice UUID.
	KindVoiceCreate Kind = "voice_create" // upload sample to the audio service
	KindVoiceDelete Kind = "voice_delete" // delete the voice in the audio service
	KindRender      Kind = "render"       // clips for every utterance of tale/length
)

// Kinds accepted by the queue. script/voice/master/tale predate ADR-003 and
// are kept so existing forge tooling keeps working.
var Kinds = []Kind{KindScript, KindVoice, KindMaster, KindPublish, KindTale,
	KindVoiceCreate, KindVoiceDelete, KindRender}

type Status string

const (
	StatusQueued  Status = "queued"
	StatusRunning Status = "running"
	StatusDone    Status = "done"
	StatusFailed  Status = "failed"
)

func ValidStatus(s string) bool {
	return slices.Contains([]Status{StatusQueued, StatusRunning, StatusDone, StatusFailed}, Status(s))
}

// Lengths allowed by CONTRACTS.md §1.
var Lengths = []int{5, 10, 15, 20}

const DefaultLength = 10

// Spec is what an admin enqueues.
type Spec struct {
	Kind  Kind   `json:"kind"`
	Tale  string `json:"tale,omitempty"`
	Voice string `json:"voice,omitempty"`
	// VoiceID is the field name for parent-voice kinds (CONTRACTS §8);
	// it is an alias of Voice.
	VoiceID   string `json:"voice_id,omitempty"`
	LengthMin int    `json:"length_min,omitempty"`
	Priority  int    `json:"priority,omitempty"`
}

// IsVoiceKind reports kinds whose voice is a parent-voice UUID.
func IsVoiceKind(k Kind) bool {
	return k == KindVoiceCreate || k == KindVoiceDelete || k == KindRender
}

// Normalize validates s and fills defaults (length_min = 10 for tale jobs).
func (s *Spec) Normalize() error {
	if !slices.Contains(Kinds, s.Kind) {
		return &ValidationError{Err: fmt.Errorf("kind: must be one of %v", Kinds)}
	}
	switch {
	case s.VoiceID != "" && s.Voice != "" && s.VoiceID != s.Voice:
		return &ValidationError{Err: errors.New("voice and voice_id differ")}
	case s.VoiceID != "":
		s.Voice = s.VoiceID
	}
	s.VoiceID = ""
	if s.Kind == KindVoiceCreate || s.Kind == KindVoiceDelete {
		var errs []error
		if !ids.IsUUID(s.Voice) {
			errs = append(errs, fmt.Errorf("voice: must be a voice UUID for kind %q", s.Kind))
		}
		if s.Tale != "" || s.LengthMin != 0 {
			errs = append(errs, fmt.Errorf("tale/length_min: not applicable to kind %q", s.Kind))
		}
		if s.Priority < -1000 || s.Priority > 1000 {
			errs = append(errs, errors.New("priority: must be within -1000..1000"))
		}
		if len(errs) > 0 {
			return &ValidationError{Err: errors.Join(errs...)}
		}
		return nil
	}
	needTale := s.Kind != KindPublish
	needVoice := s.Kind == KindVoice || s.Kind == KindMaster || s.Kind == KindRender

	var errs []error
	if s.Kind == KindRender && s.Voice != "" && !ids.IsUUID(s.Voice) {
		errs = append(errs, errors.New("voice: must be a voice UUID for kind \"render\""))
	}
	switch {
	case s.Tale == "" && needTale:
		errs = append(errs, fmt.Errorf("tale: required for kind %q", s.Kind))
	case s.Tale != "" && !catalog.IsKebab(s.Tale):
		errs = append(errs, fmt.Errorf("tale: not kebab-case: %q", s.Tale))
	}
	switch {
	case s.Voice == "" && needVoice:
		errs = append(errs, fmt.Errorf("voice: required for kind %q", s.Kind))
	case s.Voice != "" && s.Kind == KindScript:
		errs = append(errs, errors.New("voice: not applicable to kind \"script\""))
	case s.Voice != "" && !catalog.IsKebab(s.Voice):
		errs = append(errs, fmt.Errorf("voice: invalid id %q", s.Voice))
	}
	if s.Tale == "" {
		if s.LengthMin != 0 || s.Voice != "" {
			errs = append(errs, errors.New("voice/length_min: require tale"))
		}
	} else {
		if s.LengthMin == 0 {
			s.LengthMin = DefaultLength
		}
		if !slices.Contains(Lengths, s.LengthMin) {
			errs = append(errs, fmt.Errorf("length_min: must be one of %v", Lengths))
		}
	}
	if s.Priority < -1000 || s.Priority > 1000 {
		errs = append(errs, errors.New("priority: must be within -1000..1000"))
	}
	if len(errs) > 0 {
		return &ValidationError{Err: errors.Join(errs...)}
	}
	return nil
}

// ValidationError marks a client error in a job spec.
type ValidationError struct{ Err error }

func (e *ValidationError) Error() string { return e.Err.Error() }
func (e *ValidationError) Unwrap() error { return e.Err }

// IdemKey identifies equivalent work; only one such job may be active.
func (s Spec) IdemKey() string {
	return fmt.Sprintf("%s|%s|%s|%d", s.Kind, s.Tale, s.Voice, s.LengthMin)
}
