// Package voices manages anonymous devices, parent voices, renders and
// clips (CONTRACTS.md §6–§8). Files live under DATA_DIR:
//
//	voices/{voice_id}/sample.{wav|m4a|mp3}
//	voices/{voice_id}/clips/{utterance_key}.m4a
//
// Every path component comes from ids.IsUUID / ids.IsHex64-validated input.
package voices

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/lioilsources/hajanek/api/internal/db"
	"github.com/lioilsources/hajanek/api/internal/ids"
	"github.com/lioilsources/hajanek/api/internal/jobs"
)

var (
	ErrNotFound = errors.New("not found")
	ErrLimit    = errors.New("voice limit reached")
	ErrNotReady = errors.New("voice is not ready")
	ErrDeleting = errors.New("voice is being deleted")
)

type Status string

const (
	StatusPending  Status = "pending"
	StatusReady    Status = "ready"
	StatusFailed   Status = "failed"
	StatusDeleting Status = "deleting"
)

// Voice is the public view of a voice.
type Voice struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Status    Status    `json:"status"`
	Error     string    `json:"error,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type Store struct {
	sqldb     *sql.DB
	q         *db.Queries
	jobs      *jobs.Store
	dir       string
	MaxVoices int
	Now       func() time.Time
	Log       *slog.Logger
}

func NewStore(sqldb *sql.DB, js *jobs.Store, dataDir string, maxVoices int) *Store {
	return &Store{
		sqldb: sqldb, q: db.New(sqldb), jobs: js,
		dir: dataDir, MaxVoices: maxVoices,
		Now: time.Now, Log: slog.Default(),
	}
}

func (s *Store) nowMs() int64 { return s.Now().UnixMilli() }

// TempDir is where uploads are staged before they get a voice id.
func (s *Store) TempDir() (string, error) {
	d := filepath.Join(s.dir, "tmp")
	return d, os.MkdirAll(d, 0o750)
}

func (s *Store) voiceDir(id string) string { return filepath.Join(s.dir, "voices", id) }

// SamplePath is the stored sample of voice id.
func (s *Store) SamplePath(id, ext string) string {
	return filepath.Join(s.voiceDir(id), "sample."+ext)
}

// ClipPath is the stored clip of voice id for utterance key.
func (s *Store) ClipPath(id, key string) string {
	return filepath.Join(s.voiceDir(id), "clips", key+".m4a")
}

// --- devices ---

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// RegisterDevice creates an anonymous device and returns its bearer token.
func (s *Store) RegisterDevice(ctx context.Context) (id, token string, err error) {
	id, token = ids.NewUUID(), ids.NewToken()
	err = s.q.InsertDevice(ctx, db.InsertDeviceParams{ID: id, TokenHash: hashToken(token), CreatedAt: s.nowMs()})
	return id, token, err
}

// DeviceByToken resolves a bearer token; ErrNotFound when unknown.
func (s *Store) DeviceByToken(ctx context.Context, token string) (string, error) {
	id, err := s.q.GetDeviceByTokenHash(ctx, hashToken(token))
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	return id, err
}

// DeleteDevice deletes the device and starts deletion of all its voices.
func (s *Store) DeleteDevice(ctx context.Context, deviceID string) error {
	var deleted []string
	err := s.inTx(ctx, func(q *db.Queries) error {
		vs, err := q.ListDeviceVoices(ctx, nullStr(deviceID))
		if err != nil {
			return err
		}
		for _, v := range vs {
			if err := s.startDelete(ctx, q, v); err != nil {
				return err
			}
			deleted = append(deleted, v.ID)
		}
		if err := q.DetachDeviceVoices(ctx, nullStr(deviceID)); err != nil {
			return err
		}
		return q.DeleteDevice(ctx, deviceID)
	})
	if err != nil {
		return err
	}
	for _, id := range deleted {
		s.removeFiles(id)
	}
	return nil
}

// --- voices ---

// NewVoice is a validated upload; SamplePath is a staged temp file that
// CreateVoice moves into place.
type NewVoice struct {
	Name        string
	ConsentText string
	Ext         string // wav | m4a | mp3
	SamplePath  string
	SampleBytes int64
	DurationS   *float64 // nil when unknown (no ffprobe)
}

// CreateVoice stores the sample and enqueues voice_create.
func (s *Store) CreateVoice(ctx context.Context, deviceID string, nv NewVoice) (Voice, error) {
	id := ids.NewUUID()
	dst := s.SamplePath(id, nv.Ext)
	if err := os.MkdirAll(filepath.Dir(dst), 0o750); err != nil {
		return Voice{}, err
	}
	if err := os.Rename(nv.SamplePath, dst); err != nil {
		s.removeFiles(id)
		return Voice{}, err
	}
	var row db.Voice
	err := s.inTx(ctx, func(q *db.Queries) error {
		n, err := q.CountActiveVoices(ctx, nullStr(deviceID))
		if err != nil {
			return err
		}
		if s.MaxVoices > 0 && n >= int64(s.MaxVoices) {
			return ErrLimit
		}
		now := s.nowMs()
		dur := sql.NullFloat64{}
		if nv.DurationS != nil {
			dur = sql.NullFloat64{Float64: *nv.DurationS, Valid: true}
		}
		row, err = q.InsertVoice(ctx, db.InsertVoiceParams{
			ID: id, DeviceID: nullStr(deviceID), Name: nv.Name,
			SampleExt: nv.Ext, SampleBytes: nv.SampleBytes, SampleDurationS: dur,
			ConsentText: nv.ConsentText, ConsentAt: now, CreatedAt: now, UpdatedAt: now,
		})
		if err != nil {
			return err
		}
		_, _, err = s.jobs.EnqueueWith(ctx, q, jobs.Spec{Kind: jobs.KindVoiceCreate, Voice: id})
		return err
	})
	if err != nil {
		s.removeFiles(id)
		return Voice{}, err
	}
	return toVoice(row), nil
}

// ListVoices returns the device's voices, oldest first.
func (s *Store) ListVoices(ctx context.Context, deviceID string) ([]Voice, error) {
	rows, err := s.q.ListDeviceVoices(ctx, nullStr(deviceID))
	if err != nil {
		return nil, err
	}
	out := make([]Voice, len(rows))
	for i, r := range rows {
		out[i] = toVoice(r)
	}
	return out, nil
}

// GetVoice returns a voice owned by deviceID; ErrNotFound otherwise, so
// other devices cannot probe for existence.
func (s *Store) GetVoice(ctx context.Context, deviceID, id string) (Voice, error) {
	row, err := s.ownedVoice(ctx, deviceID, id)
	if err != nil {
		return Voice{}, err
	}
	return toVoice(row), nil
}

func (s *Store) ownedVoice(ctx context.Context, deviceID, id string) (db.Voice, error) {
	if !ids.IsUUID(id) {
		return db.Voice{}, ErrNotFound
	}
	row, err := s.q.GetDeviceVoice(ctx, db.GetDeviceVoiceParams{ID: id, DeviceID: nullStr(deviceID)})
	if errors.Is(err, sql.ErrNoRows) {
		return db.Voice{}, ErrNotFound
	}
	return row, err
}

// DeleteVoice removes sample and clips now and enqueues voice_delete; the
// row disappears when that job finishes.
func (s *Store) DeleteVoice(ctx context.Context, deviceID, id string) error {
	err := s.inTx(ctx, func(q *db.Queries) error {
		if !ids.IsUUID(id) {
			return ErrNotFound
		}
		v, err := q.GetDeviceVoice(ctx, db.GetDeviceVoiceParams{ID: id, DeviceID: nullStr(deviceID)})
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		return s.startDelete(ctx, q, v)
	})
	if err != nil {
		return err
	}
	s.removeFiles(id)
	return nil
}

func (s *Store) startDelete(ctx context.Context, q *db.Queries, v db.Voice) error {
	if Status(v.Status) == StatusDeleting {
		return nil // already in progress
	}
	now := s.nowMs()
	if err := q.MarkVoiceDeleting(ctx, db.MarkVoiceDeletingParams{UpdatedAt: now, ID: v.ID}); err != nil {
		return err
	}
	if err := q.DeleteVoiceClips(ctx, v.ID); err != nil {
		return err
	}
	if err := q.DeleteVoiceRenders(ctx, v.ID); err != nil {
		return err
	}
	// Don't waste GPU time on queued work for a voice that is going away.
	if err := q.CancelQueuedVoiceJobs(ctx, db.CancelQueuedVoiceJobsParams{Now: sql.NullInt64{Int64: now, Valid: true}, Voice: v.ID}); err != nil {
		return err
	}
	_, _, err := s.jobs.EnqueueWith(ctx, q, jobs.Spec{Kind: jobs.KindVoiceDelete, Voice: v.ID})
	return err
}

func (s *Store) removeFiles(id string) {
	if !ids.IsUUID(id) {
		return
	}
	if err := os.RemoveAll(s.voiceDir(id)); err != nil {
		s.Log.Error("remove voice files", "voice", id, "err", err)
	}
}

// --- worker side ---

// SampleFor returns the sample path and extension for the worker.
func (s *Store) SampleFor(ctx context.Context, id string) (path, ext string, err error) {
	v, err := s.workerVoice(ctx, id)
	if err != nil {
		return "", "", err
	}
	if Status(v.Status) == StatusDeleting {
		return "", "", ErrNotFound
	}
	return s.SamplePath(v.ID, v.SampleExt), v.SampleExt, nil
}

func (s *Store) workerVoice(ctx context.Context, id string) (db.Voice, error) {
	if !ids.IsUUID(id) {
		return db.Voice{}, ErrNotFound
	}
	v, err := s.q.GetVoice(ctx, id)
	if errors.Is(err, sql.ErrNoRows) {
		return db.Voice{}, ErrNotFound
	}
	return v, err
}

// SetStatus is the worker reporting the result of voice_create.
func (s *Store) SetStatus(ctx context.Context, id string, st Status, msg string) (Voice, error) {
	var row db.Voice
	err := s.inTx(ctx, func(q *db.Queries) error {
		if !ids.IsUUID(id) {
			return ErrNotFound
		}
		v, err := q.GetVoice(ctx, id)
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		if Status(v.Status) == StatusDeleting {
			return ErrDeleting
		}
		if st != StatusFailed {
			msg = ""
		}
		row, err = q.SetVoiceStatus(ctx, db.SetVoiceStatusParams{Status: string(st), Error: msg, UpdatedAt: s.nowMs(), ID: id})
		return err
	})
	return toVoice(row), err
}

// ClipKeys lists the utterance keys that already have a clip.
func (s *Store) ClipKeys(ctx context.Context, id string) ([]string, error) {
	if _, err := s.workerVoice(ctx, id); err != nil {
		return nil, err
	}
	rows, err := s.q.ListClips(ctx, id)
	if err != nil {
		return nil, err
	}
	out := make([]string, len(rows))
	for i, r := range rows {
		out[i] = r.Key
	}
	return out, nil
}

// PutClip stores a clip uploaded by the worker (temp file + rename).
// body must already be size-limited by the caller.
func (s *Store) PutClip(ctx context.Context, id, key string, durationS float64, body io.Reader) error {
	if !ids.IsUUID(id) || !ids.IsHex64(key) {
		return ErrNotFound
	}
	v, err := s.workerVoice(ctx, id)
	if err != nil {
		return err
	}
	if Status(v.Status) == StatusDeleting {
		return ErrDeleting
	}
	dst := s.ClipPath(id, key)
	dir := filepath.Dir(dst)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	f, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	n, err := io.Copy(f, body)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		_ = os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, dst); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	err = s.inTx(ctx, func(q *db.Queries) error {
		// Re-check under the write lock: a delete may have raced the upload.
		v, err := q.GetVoice(ctx, id)
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		if Status(v.Status) == StatusDeleting {
			return ErrDeleting
		}
		return q.InsertClip(ctx, db.InsertClipParams{VoiceID: id, Key: key, Bytes: n, DurationS: durationS, CreatedAt: s.nowMs()})
	})
	if err != nil {
		_ = os.Remove(dst)
	}
	return err
}

// --- clips for devices ---

// Clip is one stored clip.
type Clip struct {
	Key       string
	Bytes     int64
	DurationS float64
	CreatedAt time.Time
}

// OwnedClip returns the clip file of a voice owned by deviceID.
func (s *Store) OwnedClip(ctx context.Context, deviceID, id, key string) (Clip, string, error) {
	if !ids.IsHex64(key) {
		return Clip{}, "", ErrNotFound
	}
	if _, err := s.ownedVoice(ctx, deviceID, id); err != nil {
		return Clip{}, "", err
	}
	c, err := s.q.GetClip(ctx, db.GetClipParams{VoiceID: id, Key: key})
	if errors.Is(err, sql.ErrNoRows) {
		return Clip{}, "", ErrNotFound
	}
	if err != nil {
		return Clip{}, "", err
	}
	return toClip(c), s.ClipPath(id, key), nil
}

func (s *Store) clipMap(ctx context.Context, id string) (map[string]Clip, error) {
	rows, err := s.q.ListClips(ctx, id)
	if err != nil {
		return nil, err
	}
	m := make(map[string]Clip, len(rows))
	for _, r := range rows {
		m[r.Key] = toClip(r)
	}
	return m, nil
}

// --- job hooks ---

// OnJobFinished reacts to finished voice jobs (jobs.Store.OnFinish).
func (s *Store) OnJobFinished(ctx context.Context, j jobs.Job) {
	var err error
	switch j.Kind {
	case jobs.KindVoiceCreate:
		if j.Status == jobs.StatusFailed {
			msg := j.Error
			if msg == "" {
				msg = "voice creation failed"
			}
			err = s.q.FailPendingVoice(ctx, db.FailPendingVoiceParams{Error: msg, UpdatedAt: s.nowMs(), ID: j.VoiceID})
		}
	case jobs.KindVoiceDelete:
		if j.Status == jobs.StatusDone {
			if err = s.q.HardDeleteVoice(ctx, j.VoiceID); err == nil {
				s.removeFiles(j.VoiceID)
				s.Log.Info("voice deleted", "voice", j.VoiceID)
			}
		} else {
			s.Log.Error("voice_delete failed; voice stays in 'deleting'", "voice", j.VoiceID, "job", j.ID, "err", j.Error)
		}
	case jobs.KindRender:
		var res struct {
			Done  *int64 `json:"done"`
			Total *int64 `json:"total"`
		}
		if len(j.Result) > 0 && json.Unmarshal(j.Result, &res) == nil && res.Done != nil && res.Total != nil {
			err = s.q.UpdateRenderProgress(ctx, db.UpdateRenderProgressParams{
				Done: *res.Done, Total: *res.Total, UpdatedAt: s.nowMs(), JobID: j.ID,
			})
		}
	}
	if err != nil {
		s.Log.Error("job finish hook", "job", j.ID, "kind", j.Kind, "err", err)
	}
}

// --- helpers ---

func (s *Store) inTx(ctx context.Context, fn func(q *db.Queries) error) error {
	tx, err := s.sqldb.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(s.q.WithTx(tx)); err != nil {
		_ = tx.Rollback()
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}

func nullStr(s string) sql.NullString { return sql.NullString{String: s, Valid: s != ""} }

func msTime(ms int64) time.Time { return time.UnixMilli(ms).UTC() }

func toVoice(r db.Voice) Voice {
	return Voice{ID: r.ID, Name: r.Name, Status: Status(r.Status), Error: r.Error, CreatedAt: msTime(r.CreatedAt)}
}

func toClip(c db.Clip) Clip {
	return Clip{Key: c.Key, Bytes: c.Bytes, DurationS: c.DurationS, CreatedAt: msTime(c.CreatedAt)}
}
