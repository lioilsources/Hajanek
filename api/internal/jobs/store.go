package jobs

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/lioilsources/hajanek/api/internal/db"
)

var (
	ErrNotFound = errors.New("job not found")
	// ErrNotLeased means the job is not running under the caller's lease
	// (finished, requeued after expiry, or claimed by another worker).
	ErrNotLeased = errors.New("job is not leased by this worker")
)

// Job is the public view of a job.
type Job struct {
	ID             string          `json:"id"`
	Kind           Kind            `json:"kind"`
	Tale           string          `json:"tale,omitempty"`
	Voice          string          `json:"voice,omitempty"`    // legacy kinds
	VoiceID        string          `json:"voice_id,omitempty"` // voice_create, voice_delete, render
	LengthMin      int             `json:"length_min,omitempty"`
	Priority       int             `json:"priority"`
	Status         Status          `json:"status"`
	Attempts       int             `json:"attempts"`
	MaxAttempts    int             `json:"max_attempts"`
	Worker         string          `json:"worker,omitempty"`
	LeaseExpiresAt *time.Time      `json:"lease_expires_at,omitempty"`
	Result         json.RawMessage `json:"result,omitempty"`
	Error          string          `json:"error,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
	StartedAt      *time.Time      `json:"started_at,omitempty"`
	FinishedAt     *time.Time      `json:"finished_at,omitempty"`
}

type Store struct {
	sqldb       *sql.DB
	q           *db.Queries
	Lease       time.Duration
	MaxAttempts int
	Now         func() time.Time // injectable clock
	Log         *slog.Logger
	// OnFinish, when set, is called after a job reaches done or failed
	// (worker completion or lease expiry with no attempts left).
	OnFinish func(ctx context.Context, j Job)
}

func NewStore(sqldb *sql.DB, lease time.Duration, maxAttempts int) *Store {
	return &Store{
		sqldb:       sqldb,
		q:           db.New(sqldb),
		Lease:       lease,
		MaxAttempts: maxAttempts,
		Now:         time.Now,
		Log:         slog.Default(),
	}
}

func (s *Store) nowMs() int64 { return s.Now().UnixMilli() }

// Enqueue adds a job unless an equivalent one is queued or running, in
// which case that job is returned with created == false.
func (s *Store) Enqueue(ctx context.Context, spec Spec) (job Job, created bool, err error) {
	if err := spec.Normalize(); err != nil {
		return Job{}, false, err
	}
	err = s.inTx(ctx, func(q *db.Queries) error {
		job, created, err = s.EnqueueWith(ctx, q, spec)
		return err
	})
	return job, created, err
}

// EnqueueWith is Enqueue inside the caller's transaction (q bound to it).
func (s *Store) EnqueueWith(ctx context.Context, q *db.Queries, spec Spec) (job Job, created bool, err error) {
	if err := spec.Normalize(); err != nil {
		return Job{}, false, err
	}
	existing, err := q.GetActiveJobByKey(ctx, spec.IdemKey())
	if err == nil {
		return toJob(existing), false, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return Job{}, false, err
	}
	now := s.nowMs()
	row, err := q.InsertJob(ctx, db.InsertJobParams{
		ID:          newID(),
		Kind:        string(spec.Kind),
		Tale:        spec.Tale,
		Voice:       spec.Voice,
		LengthMin:   int64(spec.LengthMin),
		Priority:    int64(spec.Priority),
		IdemKey:     spec.IdemKey(),
		MaxAttempts: int64(s.MaxAttempts),
		CreatedAt:   now,
		UpdatedAt:   now,
	})
	if err != nil {
		return Job{}, false, err
	}
	return toJob(row), true, nil
}

func (s *Store) Get(ctx context.Context, id string) (Job, error) {
	row, err := s.q.GetJob(ctx, id)
	if errors.Is(err, sql.ErrNoRows) {
		return Job{}, ErrNotFound
	}
	if err != nil {
		return Job{}, err
	}
	return toJob(row), nil
}

// List returns the newest jobs, optionally filtered by status.
func (s *Store) List(ctx context.Context, status Status, limit int) ([]Job, error) {
	var (
		rows []db.Job
		err  error
	)
	if status == "" {
		rows, err = s.q.ListJobs(ctx, int64(limit))
	} else {
		rows, err = s.q.ListJobsByStatus(ctx, db.ListJobsByStatusParams{Status: string(status), Limit: int64(limit)})
	}
	if err != nil {
		return nil, err
	}
	out := make([]Job, len(rows))
	for i, r := range rows {
		out[i] = toJob(r)
	}
	return out, nil
}

// Claim leases the highest-priority, oldest queued job to worker. kinds
// limits which kinds the worker accepts (all when empty). ok is false when
// the queue is empty. Expired leases are reaped first in the same
// transaction so a crashed worker's job is immediately claimable.
func (s *Store) Claim(ctx context.Context, worker string, kinds []Kind) (job Job, ok bool, err error) {
	if len(kinds) == 0 {
		kinds = Kinds
	}
	ks := make([]string, len(kinds))
	for i, k := range kinds {
		ks[i] = string(k)
	}
	var reaped []Job
	err = s.inTx(ctx, func(q *db.Queries) error {
		if reaped, err = s.reap(ctx, q); err != nil {
			return err
		}
		now := s.nowMs()
		row, err := q.ClaimJob(ctx, db.ClaimJobParams{
			Worker:         worker,
			LeaseExpiresAt: sql.NullInt64{Int64: now + s.Lease.Milliseconds(), Valid: true},
			Now:            now,
			Kinds:          ks,
		})
		if errors.Is(err, sql.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		job, ok = toJob(row), true
		return nil
	})
	if err == nil {
		s.finished(ctx, reaped)
	}
	return job, ok, err
}

// Heartbeat extends the worker's lease on a running job.
func (s *Store) Heartbeat(ctx context.Context, id, worker string) (Job, error) {
	now := s.nowMs()
	row, err := s.q.ExtendLease(ctx, db.ExtendLeaseParams{
		LeaseExpiresAt: sql.NullInt64{Int64: now + s.Lease.Milliseconds(), Valid: true},
		Now:            now,
		ID:             id,
		Worker:         worker,
	})
	return s.leaseResult(ctx, id, row, err)
}

// Completion is what a worker reports when it finishes a job.
type Completion struct {
	OK     bool
	Result json.RawMessage
	Error  string
	// Retry requeues a failed job (transient error) if attempts remain.
	Retry bool
}

func (s *Store) Complete(ctx context.Context, id, worker string, c Completion) (Job, error) {
	var (
		row db.Job
		err error
	)
	err = s.inTx(ctx, func(q *db.Queries) error {
		cur, err := q.GetJob(ctx, id)
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		now := s.nowMs()
		if !c.OK && c.Retry && cur.Attempts < cur.MaxAttempts {
			row, err = q.RequeueJob(ctx, db.RequeueJobParams{Error: c.Error, Now: now, ID: id, Worker: worker})
			return err
		}
		status, result := StatusDone, []byte(c.Result)
		if !c.OK {
			status = StatusFailed
		}
		if len(result) == 0 {
			result = nil
		}
		row, err = q.FinishJob(ctx, db.FinishJobParams{
			Status: string(status),
			Result: result,
			Error:  c.Error,
			Now:    sql.NullInt64{Int64: now, Valid: true},
			ID:     id,
			Worker: worker,
		})
		return err
	})
	job, err := s.leaseResult(ctx, id, row, err)
	if err == nil {
		s.finished(ctx, []Job{job})
	}
	return job, err
}

// finished runs the OnFinish hook for jobs that reached a final status.
func (s *Store) finished(ctx context.Context, js []Job) {
	if s.OnFinish == nil {
		return
	}
	for _, j := range js {
		if j.Status == StatusDone || j.Status == StatusFailed {
			s.OnFinish(ctx, j)
		}
	}
}

func (s *Store) leaseResult(ctx context.Context, id string, row db.Job, err error) (Job, error) {
	if errors.Is(err, sql.ErrNoRows) {
		if _, gerr := s.Get(ctx, id); errors.Is(gerr, ErrNotFound) {
			return Job{}, ErrNotFound
		}
		return Job{}, ErrNotLeased
	}
	if err != nil {
		return Job{}, err
	}
	return toJob(row), nil
}

// Reap requeues (or fails, when out of attempts) running jobs whose lease
// has expired. It returns the number of affected jobs.
func (s *Store) Reap(ctx context.Context) (int, error) {
	var reaped []Job
	err := s.inTx(ctx, func(q *db.Queries) (err error) {
		reaped, err = s.reap(ctx, q)
		return err
	})
	if err == nil {
		s.finished(ctx, reaped)
	}
	return len(reaped), err
}

func (s *Store) reap(ctx context.Context, q *db.Queries) ([]Job, error) {
	rows, err := q.ReapExpiredLeases(ctx, s.nowMs())
	if err != nil {
		return nil, fmt.Errorf("reap: %w", err)
	}
	s.logReaped(rows)
	out := make([]Job, len(rows))
	for i, r := range rows {
		out[i] = toJob(r)
	}
	return out, nil
}

func (s *Store) logReaped(rows []db.Job) {
	for _, r := range rows {
		s.Log.Warn("job lease expired", "id", r.ID, "kind", r.Kind, "attempts", r.Attempts, "status", r.Status)
	}
}

// RunReaper reaps expired leases every interval until ctx is done.
func (s *Store) RunReaper(ctx context.Context, interval time.Duration) {
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if _, err := s.Reap(ctx); err != nil && ctx.Err() == nil {
				s.Log.Error("reaper", "err", err)
			}
		}
	}
}

func (s *Store) inTx(ctx context.Context, fn func(q *db.Queries) error) error {
	tx, err := s.sqldb.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(s.q.WithTx(tx)); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}

func newID() string {
	var b [12]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

func msTime(ms int64) time.Time { return time.UnixMilli(ms).UTC() }

func nullTime(n sql.NullInt64) *time.Time {
	if !n.Valid {
		return nil
	}
	t := msTime(n.Int64)
	return &t
}

func toJob(r db.Job) Job {
	j := toJobRow(r)
	if IsVoiceKind(j.Kind) {
		j.VoiceID, j.Voice = j.Voice, ""
	}
	return j
}

func toJobRow(r db.Job) Job {
	return Job{
		ID:             r.ID,
		Kind:           Kind(r.Kind),
		Tale:           r.Tale,
		Voice:          r.Voice,
		LengthMin:      int(r.LengthMin),
		Priority:       int(r.Priority),
		Status:         Status(r.Status),
		Attempts:       int(r.Attempts),
		MaxAttempts:    int(r.MaxAttempts),
		Worker:         r.Worker,
		LeaseExpiresAt: nullTime(r.LeaseExpiresAt),
		Result:         json.RawMessage(r.Result),
		Error:          r.Error,
		CreatedAt:      msTime(r.CreatedAt),
		UpdatedAt:      msTime(r.UpdatedAt),
		StartedAt:      nullTime(r.StartedAt),
		FinishedAt:     nullTime(r.FinishedAt),
	}
}
