// Package worker implements `forge worker`: it claims voice jobs from
// hajanek-api and drives the AiStack audio service (CONTRACTS §6–§8, ADR-003).
package worker

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"mime"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/config"
	"github.com/lioilsources/hajanek/forge/internal/jobs"
	"github.com/lioilsources/hajanek/forge/internal/script"
)

// Encoder turns a TTS output into a clip (.m4a) and returns its duration in seconds.
type Encoder func(in, out string) (float64, error)

type Worker struct {
	API     *jobs.Client
	Audio   *AudioClient
	Cfg     config.Worker
	Prosody script.Prosody // tone → speed sent to the engine
	Encode  Encoder
	TmpDir  string
	Log     *log.Logger
}

// Result is the outcome of one job.
type Result struct {
	OK     bool
	Retry  bool
	Err    error
	Output any
}

// RenderProgress is the complete result of a render job.
type RenderProgress struct {
	Done  int `json:"done"`
	Total int `json:"total"`
}

func dur(s float64) time.Duration { return time.Duration(s * float64(time.Second)) }

// Run claims and handles jobs until ctx ends. With once it returns when the
// queue is empty or after a job that should be retried later (engine down).
func (w *Worker) Run(ctx context.Context, once bool) error {
	for {
		job, err := w.API.Claim(ctx, w.Cfg.Kinds)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			w.Log.Printf("worker: claim: %v", err)
			if once {
				return err
			}
			if !sleep(ctx, dur(w.Cfg.IdleS)) {
				return nil
			}
			continue
		}
		if job == nil {
			if once || !sleep(ctx, dur(w.Cfg.IdleS)) {
				return nil
			}
			continue
		}
		r := w.Handle(ctx, *job)
		msg := ""
		if r.Err != nil {
			msg = r.Err.Error()
			w.Log.Printf("worker: %s: %v (retry=%v)", job, r.Err, r.Retry)
		} else {
			w.Log.Printf("worker: %s: ok", job)
		}
		if err := w.API.Complete(ctx, job.ID, r.OK, msg, r.Retry, r.Output); err != nil {
			w.Log.Printf("worker: complete %s: %v", job.ID, err)
		}
		if r.Retry {
			// The job went back to the queue (typically the GPU engine is down):
			// do not reclaim it right away.
			if once || !sleep(ctx, dur(w.Cfg.IdleS)) {
				return nil
			}
		}
	}
}

func sleep(ctx context.Context, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}

var reVoiceID = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,39}$`)

// Handle runs one job with a background heartbeat; a lost lease cancels it.
func (w *Worker) Handle(ctx context.Context, j jobs.Job) Result {
	hctx, cancel := context.WithCancel(ctx)
	defer cancel()
	go w.API.KeepAlive(hctx, j.ID, dur(w.Cfg.HeartbeatS), cancel)

	j.VoiceID = strings.ToLower(j.VoiceID)
	if !reVoiceID.MatchString(j.VoiceID) {
		return Result{Err: fmt.Errorf("invalid voice_id %q", j.VoiceID)}
	}
	switch j.Kind {
	case jobs.KindVoiceCreate:
		return w.voiceCreate(hctx, j)
	case jobs.KindVoiceDelete:
		return w.voiceDelete(hctx, j)
	case jobs.KindRender:
		return w.render(hctx, j)
	default:
		return Result{Err: fmt.Errorf("unknown job kind %q", j.Kind)}
	}
}

func (w *Worker) audioVoice(id string) string { return w.Cfg.VoicePrefix + id }

// fail classifies err: network trouble, 5xx/429 and a lost lease are retried,
// other 4xx (403 license, 422 bad sample, …) fail the job for good.
func fail(err error, out any) Result {
	return Result{Err: err, Retry: retryable(err), Output: out}
}

func retryable(err error) bool {
	var ae *AudioError
	var he *jobs.HTTPError
	var ne net.Error
	var ue *url.Error
	switch {
	case errors.As(err, &ae):
		return ae.Status >= 500 || ae.Status == http.StatusTooManyRequests
	case errors.As(err, &he):
		return he.Status >= 500 || he.Status == http.StatusTooManyRequests
	case errors.Is(err, context.Canceled), errors.Is(err, context.DeadlineExceeded), errors.Is(err, jobs.ErrLeaseLost):
		return true
	case errors.As(err, &ne), errors.As(err, &ue):
		return true
	}
	return false
}

func (w *Worker) voiceCreate(ctx context.Context, j jobs.Job) Result {
	resp, sample, err := w.API.Do(ctx, http.MethodGet, "/v1/worker/voices/"+j.VoiceID+"/sample", nil, nil)
	if err != nil {
		return fail(fmt.Errorf("sample: %w", err), nil)
	}
	name := "sample" + sampleExt(resp.Header.Get("Content-Type"))
	av := w.audioVoice(j.VoiceID)
	if err := w.Audio.CreateVoice(ctx, av, sample, name, w.Cfg.Language); err != nil {
		r := fail(err, nil)
		if !r.Retry {
			_ = w.setVoiceStatus(ctx, j.VoiceID, "failed", err.Error())
		}
		return r
	}
	if err := w.setVoiceStatus(ctx, j.VoiceID, "ready", ""); err != nil {
		return fail(fmt.Errorf("voice status: %w", err), nil)
	}
	return Result{OK: true, Output: map[string]string{"audio_voice": av}}
}

func (w *Worker) setVoiceStatus(ctx context.Context, id, status, msg string) error {
	body := map[string]string{"status": status}
	if msg != "" {
		body["error"] = msg
	}
	_, _, err := w.API.Do(ctx, http.MethodPost, "/v1/worker/voices/"+id+"/status", body, nil)
	if err != nil {
		w.Log.Printf("worker: voice %s status %s: %v", id, status, err)
	}
	return err
}

func sampleExt(ctype string) string {
	mt, _, _ := mime.ParseMediaType(ctype)
	switch mt {
	case "audio/wav", "audio/x-wav", "audio/wave":
		return ".wav"
	case "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/aac":
		return ".m4a"
	case "audio/mpeg":
		return ".mp3"
	}
	return ".bin"
}

func (w *Worker) voiceDelete(ctx context.Context, j jobs.Job) Result {
	deleted, err := w.Audio.DeleteVoice(ctx, w.audioVoice(j.VoiceID))
	if err != nil {
		return fail(err, nil)
	}
	return Result{OK: true, Output: map[string]bool{"deleted": deleted}}
}

type clip struct {
	key  string
	tone script.Tone
	text string
}

func (w *Worker) render(ctx context.Context, j jobs.Job) Result {
	if j.Tale == "" || j.LengthMin <= 0 {
		return Result{Err: fmt.Errorf("render job needs tale and length_min")}
	}
	src, err := w.fetchScript(ctx, j.Tale, j.LengthMin)
	if err != nil {
		return fail(fmt.Errorf("script: %w", err), nil)
	}
	s, err := script.Parse(src)
	if err != nil {
		return Result{Err: fmt.Errorf("script %s.%d: %w", j.Tale, j.LengthMin, err)}
	}
	var clips []clip
	seen := map[string]bool{}
	for _, u := range s.Utterances() {
		k := script.UtteranceKey(j.VoiceID, u.Tone, u.Text)
		if !seen[k] {
			seen[k] = true
			clips = append(clips, clip{k, u.Tone, u.Text})
		}
	}
	have, err := w.existingClips(ctx, j.VoiceID)
	if err != nil {
		return fail(fmt.Errorf("clips: %w", err), nil)
	}
	p := RenderProgress{Total: len(clips)}
	var todo []clip
	for _, c := range clips {
		if have[c.key] {
			p.Done++
		} else {
			todo = append(todo, c)
		}
	}
	w.Log.Printf("worker: render %s/%s.%d: %d clips, %d to voice", j.VoiceID, j.Tale, j.LengthMin, p.Total, len(todo))
	dir, err := os.MkdirTemp(w.TmpDir, "render-")
	if err != nil {
		return fail(err, p)
	}
	defer func() { _ = os.RemoveAll(dir) }()
	for i, c := range todo {
		if i > 0 {
			if err := w.API.Heartbeat(ctx, j.ID); err != nil {
				return fail(fmt.Errorf("heartbeat: %w", err), p)
			}
		}
		if err := w.voiceClip(ctx, j.VoiceID, c, dir); err != nil {
			return fail(err, p)
		}
		p.Done++
	}
	return Result{OK: true, Output: p}
}

// fetchScript returns the markdown served by the API, raw or wrapped in JSON.
func (w *Worker) fetchScript(ctx context.Context, tale string, length int) ([]byte, error) {
	resp, b, err := w.API.Do(ctx, http.MethodGet, fmt.Sprintf("/v1/worker/scripts/%s/%d", url.PathEscape(tale), length), nil, nil)
	if err != nil {
		return nil, err
	}
	if mt, _, _ := mime.ParseMediaType(resp.Header.Get("Content-Type")); mt == "application/json" {
		var v map[string]any
		if err := json.Unmarshal(b, &v); err != nil {
			return nil, err
		}
		for _, k := range []string{"script", "text", "content", "markdown"} {
			if s, ok := v[k].(string); ok {
				return []byte(s), nil
			}
		}
		return nil, fmt.Errorf("no script text in JSON response")
	}
	return b, nil
}

func (w *Worker) existingClips(ctx context.Context, voiceID string) (map[string]bool, error) {
	_, b, err := w.API.Do(ctx, http.MethodGet, "/v1/worker/clips/"+voiceID, nil, nil)
	if err != nil {
		return nil, err
	}
	var r struct {
		Keys []string `json:"keys"`
	}
	if err := json.Unmarshal(b, &r); err != nil {
		return nil, err
	}
	have := make(map[string]bool, len(r.Keys))
	for _, k := range r.Keys {
		have[k] = true
	}
	return have, nil
}

func (w *Worker) voiceClip(ctx context.Context, voiceID string, c clip, dir string) error {
	speed := min(max(w.Prosody.Speed(c.tone), 0.5), 2.0)
	id, err := w.Audio.SubmitTTS(ctx, TTSRequest{Text: c.text, Language: w.Cfg.Language, Voice: w.audioVoice(voiceID),
		CommercialOnly: false, Speed: speed, Format: "wav"})
	if err != nil {
		return err
	}
	st, err := w.await(ctx, id)
	if err != nil {
		return err
	}
	if len(st.Outputs) == 0 {
		return fmt.Errorf("audio job %s: no outputs", id)
	}
	wav := filepath.Join(dir, c.key+".wav")
	out := filepath.Join(dir, c.key+".m4a")
	if err := w.Audio.Download(ctx, st.Outputs[0].URL, wav); err != nil {
		return err
	}
	d, err := w.Encode(wav, out)
	if err != nil {
		return fmt.Errorf("encode: %w", err)
	}
	b, err := os.ReadFile(out)
	if err != nil {
		return err
	}
	h := http.Header{}
	h.Set("Content-Type", "audio/mp4")
	h.Set("X-Duration-S", strconv.FormatFloat(d, 'f', 3, 64))
	if _, _, err := w.API.Do(ctx, http.MethodPut, "/v1/worker/clips/"+voiceID+"/"+c.key, b, h); err != nil {
		return fmt.Errorf("upload clip: %w", err)
	}
	return nil
}

func (w *Worker) await(ctx context.Context, id string) (*JobStatus, error) {
	deadline := time.Now().Add(dur(w.Cfg.TTSTimeoutS))
	for {
		st, err := w.Audio.Job(ctx, id)
		if err != nil {
			return nil, err
		}
		switch st.Status {
		case "done":
			return st, nil
		case "error":
			// The engine failed mid-job (crash, OOM): treated like a 502, i.e. retried.
			return nil, &AudioError{Op: "job " + id, Status: http.StatusBadGateway, Detail: st.Error}
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("audio job %s: %w after %.0fs", id, context.DeadlineExceeded, w.Cfg.TTSTimeoutS)
		}
		if !sleep(ctx, dur(w.Cfg.PollS)) {
			return nil, ctx.Err()
		}
	}
}
