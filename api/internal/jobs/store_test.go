package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/lioilsources/hajanek/api/internal/db"
)

type fakeClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *fakeClock) Advance(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

func newTestStore(t *testing.T) (*Store, *fakeClock) {
	t.Helper()
	sqldb, err := db.Open(context.Background(), filepath.Join(t.TempDir(), "jobs.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := sqldb.Close(); err != nil {
			t.Error(err)
		}
	})
	clock := &fakeClock{t: time.Date(2026, 10, 20, 22, 0, 0, 0, time.UTC)}
	s := NewStore(sqldb, 10*time.Minute, 3)
	s.Now = clock.Now
	s.Log = slog.New(slog.NewTextHandler(io.Discard, nil))
	return s, clock
}

func TestSpecNormalize(t *testing.T) {
	tests := []struct {
		name    string
		spec    Spec
		wantErr bool
		wantLen int
	}{
		{"script defaults length", Spec{Kind: KindScript, Tale: "zlatovlaska"}, false, 10},
		{"voice", Spec{Kind: KindVoice, Tale: "zlatovlaska", Voice: "mama", LengthMin: 15}, false, 15},
		{"tale all voices", Spec{Kind: KindTale, Tale: "zlatovlaska"}, false, 10},
		{"publish", Spec{Kind: KindPublish}, false, 0},
		{"unknown kind", Spec{Kind: "dance", Tale: "x"}, true, 0},
		{"voice_create", Spec{Kind: KindVoiceCreate, Voice: "3f2c1a2b-0000-4000-8000-000000000001"}, false, 0},
		{"voice_create needs uuid", Spec{Kind: KindVoiceCreate, Voice: "mama"}, true, 0},
		{"voice_delete with tale", Spec{Kind: KindVoiceDelete, Voice: "3f2c1a2b-0000-4000-8000-000000000001", Tale: "x"}, true, 0},
		{"render", Spec{Kind: KindRender, Voice: "3f2c1a2b-0000-4000-8000-000000000001", Tale: "zlatovlaska"}, false, 10},
		{"render needs voice", Spec{Kind: KindRender, Tale: "zlatovlaska"}, true, 0},
		{"render needs uuid voice", Spec{Kind: KindRender, Voice: "mama", Tale: "zlatovlaska"}, true, 0},
		{"missing tale", Spec{Kind: KindScript}, true, 0},
		{"bad tale id", Spec{Kind: KindScript, Tale: "Zlatovláska"}, true, 0},
		{"voice needs voice", Spec{Kind: KindVoice, Tale: "zlatovlaska"}, true, 0},
		{"script with voice", Spec{Kind: KindScript, Tale: "zlatovlaska", Voice: "mama"}, true, 0},
		{"bad length", Spec{Kind: KindScript, Tale: "zlatovlaska", LengthMin: 7}, true, 0},
		{"publish with voice", Spec{Kind: KindPublish, Voice: "mama"}, true, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.spec.Normalize()
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
			}
			var verr *ValidationError
			if err != nil && !errors.As(err, &verr) {
				t.Fatalf("want ValidationError, got %T", err)
			}
			if err == nil && tt.spec.LengthMin != tt.wantLen {
				t.Fatalf("length = %d, want %d", tt.spec.LengthMin, tt.wantLen)
			}
		})
	}
}

func TestEnqueueDedupe(t *testing.T) {
	ctx := context.Background()
	s, _ := newTestStore(t)

	a, created, err := s.Enqueue(ctx, Spec{Kind: KindScript, Tale: "zlatovlaska"})
	if err != nil || !created {
		t.Fatalf("first enqueue: created=%v err=%v", created, err)
	}
	// Same key (length defaults to 10) → same job.
	b, created, err := s.Enqueue(ctx, Spec{Kind: KindScript, Tale: "zlatovlaska", LengthMin: 10, Priority: 5})
	if err != nil || created || b.ID != a.ID {
		t.Fatalf("dedupe failed: created=%v id=%s/%s err=%v", created, a.ID, b.ID, err)
	}
	// Different length → different job.
	if _, created, _ := s.Enqueue(ctx, Spec{Kind: KindScript, Tale: "zlatovlaska", LengthMin: 5}); !created {
		t.Fatal("different length must create a job")
	}
	// Still deduped while running.
	job, ok, err := s.Claim(ctx, "w1", []Kind{KindScript})
	if err != nil || !ok {
		t.Fatalf("claim: %v %v", ok, err)
	}
	if _, created, _ := s.Enqueue(ctx, Spec{Kind: job.Kind, Tale: job.Tale, LengthMin: job.LengthMin}); created {
		t.Fatal("running job must dedupe")
	}
	// Once finished, the same work can be enqueued again.
	if _, err := s.Complete(ctx, job.ID, "w1", Completion{OK: true}); err != nil {
		t.Fatal(err)
	}
	if _, created, _ := s.Enqueue(ctx, Spec{Kind: job.Kind, Tale: job.Tale, LengthMin: job.LengthMin}); !created {
		t.Fatal("finished job must not dedupe")
	}
}

func TestClaimOrderAndKinds(t *testing.T) {
	ctx := context.Background()
	s, clock := newTestStore(t)

	low, _, _ := s.Enqueue(ctx, Spec{Kind: KindScript, Tale: "a"})
	clock.Advance(time.Second)
	high, _, _ := s.Enqueue(ctx, Spec{Kind: KindScript, Tale: "b", Priority: 10})
	clock.Advance(time.Second)
	voice, _, _ := s.Enqueue(ctx, Spec{Kind: KindVoice, Tale: "a", Voice: "mama", Priority: 100})

	got, _, _ := s.Claim(ctx, "w", []Kind{KindScript})
	if got.ID != high.ID {
		t.Fatalf("want high-priority job first, got %+v", got)
	}
	got, _, _ = s.Claim(ctx, "w", []Kind{KindScript})
	if got.ID != low.ID {
		t.Fatalf("want low job second, got %+v", got)
	}
	if _, ok, _ := s.Claim(ctx, "w", []Kind{KindScript}); ok {
		t.Fatal("script queue should be empty")
	}
	got, ok, _ := s.Claim(ctx, "w", nil)
	if !ok || got.ID != voice.ID || got.Status != StatusRunning || got.Attempts != 1 {
		t.Fatalf("want voice job running attempt 1, got %+v", got)
	}
	if got.LeaseExpiresAt == nil || !got.LeaseExpiresAt.Equal(clock.Now().Add(10*time.Minute)) {
		t.Fatalf("bad lease expiry %v", got.LeaseExpiresAt)
	}
}

func TestConcurrentClaimsAreExclusive(t *testing.T) {
	ctx := context.Background()
	s, _ := newTestStore(t)

	const nJobs, nWorkers = 40, 8
	for i := range nJobs {
		if _, _, err := s.Enqueue(ctx, Spec{Kind: KindScript, Tale: fmt.Sprintf("tale-%d", i)}); err != nil {
			t.Fatal(err)
		}
	}

	var (
		mu      sync.Mutex
		claimed = map[string]string{}
		wg      sync.WaitGroup
		errs    = make(chan error, nWorkers)
	)
	for w := range nWorkers {
		worker := fmt.Sprintf("w%d", w)
		wg.Go(func() {
			for {
				job, ok, err := s.Claim(ctx, worker, nil)
				if err != nil {
					errs <- err
					return
				}
				if !ok {
					return
				}
				mu.Lock()
				if prev, dup := claimed[job.ID]; dup {
					mu.Unlock()
					errs <- fmt.Errorf("job %s claimed by %s and %s", job.ID, prev, worker)
					return
				}
				claimed[job.ID] = worker
				mu.Unlock()
			}
		})
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Error(err)
	}
	if len(claimed) != nJobs {
		t.Fatalf("claimed %d jobs, want %d", len(claimed), nJobs)
	}
}

func TestLeaseExpiry(t *testing.T) {
	ctx := context.Background()
	s, clock := newTestStore(t)

	job, _, _ := s.Enqueue(ctx, Spec{Kind: KindMaster, Tale: "zlatovlaska", Voice: "mama"})

	// Attempt 1: heartbeat keeps the lease alive past the original expiry.
	if _, ok, _ := s.Claim(ctx, "w1", nil); !ok {
		t.Fatal("claim 1")
	}
	clock.Advance(8 * time.Minute)
	if _, err := s.Heartbeat(ctx, job.ID, "w1"); err != nil {
		t.Fatalf("heartbeat: %v", err)
	}
	if _, err := s.Heartbeat(ctx, job.ID, "intruder"); !errors.Is(err, ErrNotLeased) {
		t.Fatalf("foreign heartbeat: want ErrNotLeased, got %v", err)
	}
	clock.Advance(8 * time.Minute)
	if n, _ := s.Reap(ctx); n != 0 {
		t.Fatal("lease was extended, nothing to reap")
	}

	// Worker goes silent → requeued with attempts kept.
	clock.Advance(3 * time.Minute)
	if n, err := s.Reap(ctx); err != nil || n != 1 {
		t.Fatalf("reap: n=%d err=%v", n, err)
	}
	got, _ := s.Get(ctx, job.ID)
	if got.Status != StatusQueued || got.Attempts != 1 || got.Worker != "" || got.Error != "lease expired" {
		t.Fatalf("after expiry: %+v", got)
	}
	// The stale worker cannot complete any more.
	if _, err := s.Complete(ctx, job.ID, "w1", Completion{OK: true}); !errors.Is(err, ErrNotLeased) {
		t.Fatalf("stale complete: want ErrNotLeased, got %v", err)
	}

	// Attempts 2 and 3 expire too; claim reaps inline.
	for attempt := 2; attempt <= 3; attempt++ {
		got, ok, err := s.Claim(ctx, "w2", nil)
		if err != nil || !ok || got.Attempts != attempt {
			t.Fatalf("claim %d: %+v ok=%v err=%v", attempt, got, ok, err)
		}
		clock.Advance(11 * time.Minute)
	}
	if _, ok, _ := s.Claim(ctx, "w3", nil); ok {
		t.Fatal("job out of attempts must not be claimable")
	}
	got, _ = s.Get(ctx, job.ID)
	if got.Status != StatusFailed || got.Attempts != 3 || got.FinishedAt == nil {
		t.Fatalf("want failed after max attempts, got %+v", got)
	}
}

func TestCompleteVariants(t *testing.T) {
	ctx := context.Background()
	s, _ := newTestStore(t)

	if _, err := s.Complete(ctx, "nope", "w", Completion{OK: true}); !errors.Is(err, ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}

	job, _, _ := s.Enqueue(ctx, Spec{Kind: KindPublish})
	if _, _, err := s.Claim(ctx, "w", nil); err != nil {
		t.Fatal(err)
	}
	// Transient failure with retry → back to queue.
	got, err := s.Complete(ctx, job.ID, "w", Completion{OK: false, Error: "vLLM down", Retry: true})
	if err != nil || got.Status != StatusQueued || got.Error != "vLLM down" {
		t.Fatalf("retry: %+v err=%v", got, err)
	}
	if _, _, err := s.Claim(ctx, "w", nil); err != nil {
		t.Fatal(err)
	}
	got, err = s.Complete(ctx, job.ID, "w", Completion{OK: true, Result: json.RawMessage(`{"version":4}`)})
	if err != nil || got.Status != StatusDone || string(got.Result) != `{"version":4}` || got.Error != "" {
		t.Fatalf("done: %+v err=%v", got, err)
	}
	if _, err := s.Complete(ctx, job.ID, "w", Completion{OK: true}); !errors.Is(err, ErrNotLeased) {
		t.Fatalf("double complete: want ErrNotLeased, got %v", err)
	}

	job2, _, _ := s.Enqueue(ctx, Spec{Kind: KindPublish})
	if _, _, err := s.Claim(ctx, "w", nil); err != nil {
		t.Fatal(err)
	}
	got, _ = s.Complete(ctx, job2.ID, "w", Completion{OK: false, Error: "WER 12 %"})
	if got.Status != StatusFailed {
		t.Fatalf("want failed, got %+v", got)
	}

	list, err := s.List(ctx, StatusDone, 10)
	if err != nil || len(list) != 1 || list[0].ID != job.ID {
		t.Fatalf("list done: %+v err=%v", list, err)
	}
	all, _ := s.List(ctx, "", 10)
	if len(all) != 2 {
		t.Fatalf("list all: %d", len(all))
	}
}
