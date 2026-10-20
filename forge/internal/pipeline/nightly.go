package pipeline

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/jobs"
)

// NightlyKinds are the job kinds `forge nightly` claims; voice jobs belong to `forge worker`.
var NightlyKinds = []string{jobs.KindScript, jobs.KindPublish}

type NightlyOpts struct {
	QueueFile string
	Until     string // HH:MM local deadline in Timezone; empty = no deadline
	Timezone  string
	PagesDir  string
	Commit    bool
}

type JobResult struct {
	Job   string `json:"job"`
	OK    bool   `json:"ok"`
	Error string `json:"error,omitempty"`
}

// Nightly drains script/publish jobs from hajanek-api (if FORGE_API_URL+WORKER_TOKEN)
// or the queue file, publishes once at the end and posts a Discord summary.
func (e *Env) Nightly(ctx context.Context, o NightlyOpts) ([]JobResult, error) {
	deadline, err := nextDeadline(time.Now(), o.Until, o.Timezone)
	if err != nil {
		return nil, err
	}
	api := jobs.FromEnv()
	var queue []jobs.Job
	if api == nil {
		qf := o.QueueFile
		if !filepath.IsAbs(qf) {
			qf = filepath.Join(e.Forge, qf)
		}
		if queue, err = jobs.ReadQueue(qf); err != nil {
			return nil, err
		}
		e.Log.Printf("nightly: %d jobs from %s", len(queue), qf)
	} else {
		e.Log.Printf("nightly: claiming jobs from %s", api.BaseURL)
	}
	results := []JobResult{}
	for {
		if !deadline.IsZero() && time.Now().After(deadline) {
			e.Log.Printf("nightly: deadline %s reached", deadline.Format(time.Kitchen))
			break
		}
		var job *jobs.Job
		if api != nil {
			if job, err = api.Claim(ctx, NightlyKinds); err != nil {
				e.Log.Printf("nightly: claim: %v", err)
				break
			}
		} else if len(queue) > 0 {
			job, queue = &queue[0], queue[1:]
		}
		if job == nil {
			break
		}
		hctx, cancel := context.WithCancel(ctx)
		if api != nil {
			go api.KeepAlive(hctx, job.ID, 2*time.Minute, cancel)
		}
		jerr := e.runJob(hctx, *job, o)
		cancel()
		r := JobResult{Job: job.String(), OK: jerr == nil}
		if jerr != nil {
			r.Error = jerr.Error()
			e.Log.Printf("nightly: %s: %v", r.Job, jerr)
		}
		results = append(results, r)
		if api != nil {
			if err := api.Complete(ctx, job.ID, r.OK, r.Error, transient(r.Error), nil); err != nil {
				e.Log.Printf("nightly: complete %s: %v", job.ID, err)
			}
		}
	}
	var pub *PublishResult
	var pubErr error
	if o.PagesDir != "" {
		pub, pubErr = e.Publish(PublishOpts{PagesDir: o.PagesDir, Commit: o.Commit})
	}
	msg := summary(results, pub, pubErr)
	fmt.Fprintln(os.Stderr, msg)
	if err := jobs.NotifyDiscord(ctx, msg); err != nil {
		e.Log.Printf("nightly: discord: %v", err)
	}
	return results, pubErr
}

func (e *Env) runJob(ctx context.Context, j jobs.Job, o NightlyOpts) error {
	if j.LengthMin == 0 {
		j.LengthMin = 10
	}
	switch j.Kind {
	case jobs.KindScript:
		_, rep, err := e.GenerateScript(ctx, ScriptOpts{Tale: j.Tale, Length: j.LengthMin})
		if err == nil && !rep.OK {
			err = fmt.Errorf("judge: %s", strings.Join(rep.Errors, "; "))
		}
		return err
	case jobs.KindPublish:
		if o.PagesDir == "" {
			return fmt.Errorf("publish job needs --content-pages / HAJANEK_PAGES_DIR")
		}
		_, err := e.Publish(PublishOpts{PagesDir: o.PagesDir, Commit: o.Commit})
		return err
	default:
		return fmt.Errorf("unknown job kind %q", j.Kind)
	}
}

// transient guesses whether an error is worth retrying (infrastructure, not content).
func transient(msg string) bool {
	if msg == "" {
		return false
	}
	m := strings.ToLower(msg)
	for _, s := range []string{"llm: http 5", "llm: http 429", "connection refused", "timeout", "deadline exceeded",
		"no such host", "context canceled"} {
		if strings.Contains(m, s) {
			return true
		}
	}
	return false
}

func summary(rs []JobResult, pub *PublishResult, pubErr error) string {
	var b strings.Builder
	ok := 0
	for _, r := range rs {
		if r.OK {
			ok++
		}
	}
	fmt.Fprintf(&b, "**Hajánek forge nightly** — %d/%d OK\n", ok, len(rs))
	for _, r := range rs {
		if r.OK {
			fmt.Fprintf(&b, "OK   %s\n", r.Job)
		} else {
			fmt.Fprintf(&b, "FAIL %s: %s\n", r.Job, r.Error)
		}
	}
	switch {
	case pubErr != nil:
		fmt.Fprintf(&b, "publish failed: %v\n", pubErr)
	case pub != nil && pub.Changed:
		fmt.Fprintf(&b, "catalog v%d published (%d scripts, %d files copied)\n", pub.Version, len(pub.Scripts), len(pub.Copied))
	case pub != nil:
		fmt.Fprintf(&b, "catalog unchanged (v%d)\n", pub.Version)
	}
	return b.String()
}

// nextDeadline returns the next occurrence of HH:MM in tz after now.
func nextDeadline(now time.Time, hhmm, tz string) (time.Time, error) {
	if hhmm == "" {
		return time.Time{}, nil
	}
	loc := time.Local
	if tz != "" {
		l, err := time.LoadLocation(tz)
		if err != nil {
			return time.Time{}, err
		}
		loc = l
	}
	t, err := time.Parse("15:04", hhmm)
	if err != nil {
		return time.Time{}, fmt.Errorf("until: %w", err)
	}
	n := now.In(loc)
	d := time.Date(n.Year(), n.Month(), n.Day(), t.Hour(), t.Minute(), 0, 0, loc)
	if !d.After(n) {
		d = d.AddDate(0, 0, 1)
	}
	return d, nil
}
