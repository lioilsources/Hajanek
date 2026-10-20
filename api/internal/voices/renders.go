package voices

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/lioilsources/hajanek/api/internal/db"
	"github.com/lioilsources/hajanek/api/internal/jobs"
)

// Render statuses: those of the render job, or "none" when nothing was
// requested for the current script version.
const RenderNone = "none"

// Render is the public view of a requested render.
type Render struct {
	VoiceID      string    `json:"voice_id"`
	Tale         string    `json:"tale"`
	LengthMin    int       `json:"length_min"`
	ScriptSHA256 string    `json:"script_sha256"`
	Status       string    `json:"status"`
	Error        string    `json:"error,omitempty"`
	Done         int       `json:"done"`
	Total        int       `json:"total"`
	JobID        string    `json:"job_id,omitempty"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ManifestClip is one entry of Manifest.Clips.
type ManifestClip struct {
	URL       string  `json:"url"`
	DurationS float64 `json:"duration_s"`
	Bytes     int64   `json:"bytes"`
}

// Manifest is GET /v1/voices/{id}/renders/{tale}/{length} (CONTRACTS.md §6).
type Manifest struct {
	Status       string                  `json:"status"`
	Error        string                  `json:"error,omitempty"`
	ScriptSHA256 string                  `json:"script_sha256"`
	Done         int                     `json:"done"`
	Total        int                     `json:"total"`
	Clips        map[string]ManifestClip `json:"clips"`
}

// ClipURL is the device-facing URL of a clip (relative to the API host).
func ClipURL(voiceID, key string) string { return "/v1/clips/" + voiceID + "/" + key + ".m4a" }

// RequestRender enqueues a render of tale/length for an owned, ready voice.
// keys are the distinct utterance keys of the current script. While a
// render job is queued or running the same job is reused; a finished render
// of the same script with every clip present is returned without new work.
func (s *Store) RequestRender(ctx context.Context, deviceID, voiceID, tale string, length int, scriptSHA string, keys []string) (Render, error) {
	var out Render
	err := s.inTx(ctx, func(q *db.Queries) error {
		v, err := q.GetDeviceVoice(ctx, db.GetDeviceVoiceParams{ID: voiceID, DeviceID: nullStr(deviceID)})
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		switch Status(v.Status) {
		case StatusReady:
		case StatusDeleting:
			return ErrDeleting
		default:
			return ErrNotReady
		}
		done, err := countPresent(ctx, q, voiceID, keys)
		if err != nil {
			return err
		}
		cur, err := q.GetRender(ctx, db.GetRenderParams{VoiceID: voiceID, Tale: tale, LengthMin: int64(length)})
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return err
		}
		if err == nil && cur.ScriptSha256 == scriptSHA && cur.JobStatus == string(jobs.StatusDone) && done == len(keys) {
			out = toRender(cur)
			out.Done, out.Total = done, len(keys)
			return nil
		}
		job, _, err := s.jobs.EnqueueWith(ctx, q, jobs.Spec{Kind: jobs.KindRender, Voice: voiceID, Tale: tale, LengthMin: length})
		if err != nil {
			return err
		}
		now := s.nowMs()
		if err := q.UpsertRender(ctx, db.UpsertRenderParams{
			VoiceID: voiceID, Tale: tale, LengthMin: int64(length), ScriptSha256: scriptSHA,
			JobID: job.ID, Done: int64(done), Total: int64(len(keys)), CreatedAt: now, UpdatedAt: now,
		}); err != nil {
			return err
		}
		row, err := q.GetRender(ctx, db.GetRenderParams{VoiceID: voiceID, Tale: tale, LengthMin: int64(length)})
		if err != nil {
			return err
		}
		out = toRender(row)
		return nil
	})
	return out, err
}

func countPresent(ctx context.Context, q *db.Queries, voiceID string, keys []string) (int, error) {
	rows, err := q.ListClips(ctx, voiceID)
	if err != nil {
		return 0, err
	}
	have := make(map[string]bool, len(rows))
	for _, r := range rows {
		have[r.Key] = true
	}
	n := 0
	for _, k := range keys {
		if have[k] {
			n++
		}
	}
	return n, nil
}

// Manifest lists the clips available for the given script keys. Done and
// Total are counted live from the clips, so the manifest never disagrees
// with its own clip map.
func (s *Store) Manifest(ctx context.Context, deviceID, voiceID, tale string, length int, scriptSHA string, keys []string) (Manifest, error) {
	if _, err := s.ownedVoice(ctx, deviceID, voiceID); err != nil {
		return Manifest{}, err
	}
	m := Manifest{Status: RenderNone, ScriptSHA256: scriptSHA, Total: len(keys), Clips: map[string]ManifestClip{}}
	r, err := s.q.GetRender(ctx, db.GetRenderParams{VoiceID: voiceID, Tale: tale, LengthMin: int64(length)})
	switch {
	case err == nil && r.ScriptSha256 == scriptSHA && r.JobStatus != "":
		m.Status = r.JobStatus
		if r.JobStatus == string(jobs.StatusFailed) {
			m.Error = r.JobError
		}
	case err != nil && !errors.Is(err, sql.ErrNoRows):
		return Manifest{}, err
	}
	clips, err := s.clipMap(ctx, voiceID)
	if err != nil {
		return Manifest{}, err
	}
	for _, k := range keys {
		if c, ok := clips[k]; ok {
			m.Clips[k] = ManifestClip{URL: ClipURL(voiceID, k), DurationS: c.DurationS, Bytes: c.Bytes}
		}
	}
	m.Done = len(m.Clips)
	return m, nil
}

func toRender(r db.GetRenderRow) Render {
	st := r.JobStatus
	if st == "" {
		st = RenderNone
	}
	out := Render{
		VoiceID: r.VoiceID, Tale: r.Tale, LengthMin: int(r.LengthMin), ScriptSHA256: r.ScriptSha256,
		Status: st, Done: int(r.Done), Total: int(r.Total), JobID: r.JobID, UpdatedAt: msTime(r.UpdatedAt),
	}
	if st == string(jobs.StatusFailed) {
		out.Error = r.JobError
	}
	return out
}
