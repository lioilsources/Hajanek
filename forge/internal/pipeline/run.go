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

type RunOpts struct {
	Tale, Voice string
	Length      int
	AllowDraft  bool
	PagesDir    string // empty = skip publish
	Commit      bool
}

type RunResult struct {
	Track   string  `json:"track"`
	Stage   string  `json:"stage"` // last stage reached
	OK      bool    `json:"ok"`
	Error   string  `json:"error,omitempty"`
	LUFS    float64 `json:"lufs,omitempty"`
	Seconds float64 `json:"duration_s,omitempty"`
}

// Run executes script → judge → voice → master → qa → publish, stopping on failure.
func (e *Env) Run(ctx context.Context, o RunOpts) *RunResult {
	r := &RunResult{Track: fmt.Sprintf("%s/%s/%d", o.Tale, o.Voice, o.Length)}
	fail := func(stage string, err error) *RunResult {
		r.Stage, r.Error = stage, err.Error()
		e.Log.Printf("run %s: %s failed: %v", r.Track, stage, err)
		return r
	}
	r.Stage = "script"
	path, err := e.ScriptPath(o.Tale, o.Length)
	if err != nil {
		if path, _, err = e.GenerateScript(ctx, ScriptOpts{Tale: o.Tale, Length: o.Length}); err != nil {
			return fail("script", err)
		}
	}
	rep, err := e.Judge(ctx, path, o.Length, true)
	if err != nil {
		return fail("judge", err)
	}
	if !rep.OK {
		return fail("judge", fmt.Errorf("%s", strings.Join(rep.Errors, "; ")))
	}
	vm, err := e.Voice(VoiceOpts{Tale: o.Tale, Voice: o.Voice, Length: o.Length, AllowDraft: o.AllowDraft, ScriptPath: path})
	if err != nil {
		return fail("voice", err)
	}
	r.Seconds = vm.DurationS
	mr, err := e.Master(o.Tale, o.Voice, o.Length)
	if err != nil {
		return fail("master", err)
	}
	r.LUFS = mr.Result.Measured.IntegratedLUFS
	if _, err := e.QA(o.Tale, o.Voice, o.Length); err != nil {
		return fail("qa", err)
	}
	r.Stage = "qa"
	if o.PagesDir != "" {
		id := TrackID{Tale: o.Tale, Voice: o.Voice, Length: o.Length}
		if _, err := e.Publish(PublishOpts{PagesDir: o.PagesDir, Commit: o.Commit, Only: &id}); err != nil {
			return fail("publish", err)
		}
		r.Stage = "publish"
	}
	r.OK = true
	return r
}

type NightlyOpts struct {
	QueueFile  string
	Until      string // HH:MM local deadline in Timezone; empty = no deadline
	Timezone   string
	AllowDraft bool
	PagesDir   string
	Commit     bool
}

// Nightly drains jobs from hajanek-api (if FORGE_API_URL+WORKER_TOKEN) or the
// queue file, publishes once at the end and posts a Discord summary.
func (e *Env) Nightly(ctx context.Context, o NightlyOpts) ([]*RunResult, error) {
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
	var results []*RunResult
	for {
		if !deadline.IsZero() && time.Now().After(deadline) {
			e.Log.Printf("nightly: deadline %s reached", deadline.Format(time.Kitchen))
			break
		}
		var job *jobs.Job
		if api != nil {
			if job, err = api.Claim(ctx); err != nil {
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
			go api.Heartbeat(hctx, job.ID, 2*time.Minute)
		}
		jr := e.runJob(ctx, *job, o)
		if len(jr) == 0 {
			jr = []*RunResult{{Track: job.String(), Stage: "job", Error: "no voices configured"}}
		}
		res := jr[len(jr)-1]
		ok, msgs := true, []string{}
		for _, r := range jr {
			ok = ok && r.OK
			if r.Error != "" {
				msgs = append(msgs, r.Track+": "+r.Error)
			}
		}
		res = &RunResult{Track: job.Kind + " " + job.String(), Stage: res.Stage, OK: ok, Error: strings.Join(msgs, "; "),
			LUFS: res.LUFS, Seconds: res.Seconds}
		if len(jr) > 1 {
			results = append(results, jr...)
		}
		cancel()
		if len(jr) == 1 {
			results = append(results, res)
		}
		if api != nil {
			if err := api.Complete(ctx, job.ID, res.OK, res.Error, transient(res.Error), jr); err != nil {
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

// runJob executes one job; "tale" with empty voice runs every configured voice.
func (e *Env) runJob(ctx context.Context, j jobs.Job, o NightlyOpts) []*RunResult {
	if j.LengthMin == 0 {
		j.LengthMin = 10
	}
	one := func(stage string, err error) []*RunResult {
		r := &RunResult{Track: j.String(), Stage: stage, OK: err == nil}
		if err != nil {
			r.Error = err.Error()
		}
		return []*RunResult{r}
	}
	switch j.Kind {
	case "script":
		_, rep, err := e.GenerateScript(ctx, ScriptOpts{Tale: j.Tale, Length: j.LengthMin})
		if err == nil && !rep.OK {
			err = fmt.Errorf("judge: %s", strings.Join(rep.Errors, "; "))
		}
		return one("script", err)
	case "voice":
		_, err := e.Voice(VoiceOpts{Tale: j.Tale, Voice: j.Voice, Length: j.LengthMin, AllowDraft: o.AllowDraft})
		return one("voice", err)
	case "master":
		if _, err := e.Master(j.Tale, j.Voice, j.LengthMin); err != nil {
			return one("master", err)
		}
		_, err := e.QA(j.Tale, j.Voice, j.LengthMin)
		return one("qa", err)
	case "publish":
		if o.PagesDir == "" {
			return one("publish", fmt.Errorf("publish job needs --content-pages / HAJANEK_PAGES_DIR"))
		}
		_, err := e.Publish(PublishOpts{PagesDir: o.PagesDir, Commit: o.Commit})
		return one("publish", err)
	case "tale", "":
		voices := []string{j.Voice}
		if j.Voice == "" {
			voices = voices[:0]
			for _, v := range e.Cfg.Voices {
				voices = append(voices, v.ID)
			}
		}
		var rs []*RunResult
		for _, v := range voices {
			rs = append(rs, e.Run(ctx, RunOpts{Tale: j.Tale, Voice: v, Length: j.LengthMin, AllowDraft: o.AllowDraft}))
		}
		return rs
	default:
		return one("job", fmt.Errorf("unknown job kind %q", j.Kind))
	}
}

// transient guesses whether an error is worth retrying (infrastructure, not content).
func transient(msg string) bool {
	if msg == "" {
		return false
	}
	m := strings.ToLower(msg)
	for _, s := range []string{"llm: http 5", "llm: http 429", "connection refused", "timeout", "deadline exceeded",
		"no such host", "tts worker read", "tts worker write", "start tts worker", "cuda", "out of memory"} {
		if strings.Contains(m, s) {
			return true
		}
	}
	return false
}

func summary(rs []*RunResult, pub *PublishResult, pubErr error) string {
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
			fmt.Fprintf(&b, "OK   %s (%.0fs, %.1f LUFS)\n", r.Track, r.Seconds, r.LUFS)
		} else {
			fmt.Fprintf(&b, "FAIL %s @%s: %s\n", r.Track, r.Stage, r.Error)
		}
	}
	switch {
	case pubErr != nil:
		fmt.Fprintf(&b, "publish failed: %v\n", pubErr)
	case pub != nil && pub.Changed:
		fmt.Fprintf(&b, "catalog v%d published (%d files copied)\n", pub.Version, len(pub.Copied))
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
