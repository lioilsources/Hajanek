// Package jobs talks to hajanek-api's job queue and worker endpoints
// (CONTRACTS §6), reads the local queue file and posts Discord notifications.
package jobs

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// Job kinds handled by forge.
const (
	KindScript      = "script"       // nightly: tale → content/scripts/{tale}.{len}.md
	KindPublish     = "publish"      // nightly: new catalog version → Pages
	KindVoiceCreate = "voice_create" // worker: upload a parent's sample to the audio service
	KindVoiceDelete = "voice_delete" // worker: delete the clone in the audio service
	KindRender      = "render"       // worker: voice missing clips of a script
)

type Job struct {
	ID        string `json:"id"`
	Kind      string `json:"kind"`
	Tale      string `json:"tale,omitempty"`
	VoiceID   string `json:"voice_id,omitempty"`
	LengthMin int    `json:"length_min,omitempty"`
}

// UnmarshalJSON accepts the job fields at the top level or in a nested
// "payload" object, and "voice" as an alias of "voice_id".
func (j *Job) UnmarshalJSON(b []byte) error {
	type fields struct {
		ID        string `json:"id"`
		Kind      string `json:"kind"`
		Tale      string `json:"tale"`
		VoiceID   string `json:"voice_id"`
		Voice     string `json:"voice"`
		LengthMin int    `json:"length_min"`
	}
	var raw struct {
		fields
		Payload *fields `json:"payload"`
	}
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	f := raw.fields
	if p := raw.Payload; p != nil {
		f.Tale = cmp(f.Tale, p.Tale)
		f.VoiceID = cmp(f.VoiceID, cmp(p.VoiceID, p.Voice))
		if f.LengthMin == 0 {
			f.LengthMin = p.LengthMin
		}
	}
	*j = Job{ID: f.ID, Kind: f.Kind, Tale: f.Tale, VoiceID: cmp(f.VoiceID, f.Voice), LengthMin: f.LengthMin}
	return nil
}

func cmp(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func (j Job) String() string {
	switch {
	case j.Tale != "" && j.VoiceID != "":
		return fmt.Sprintf("%s %s/%s/%d", j.Kind, j.VoiceID, j.Tale, j.LengthMin)
	case j.Tale != "":
		return fmt.Sprintf("%s %s/%d", j.Kind, j.Tale, j.LengthMin)
	case j.VoiceID != "":
		return fmt.Sprintf("%s %s", j.Kind, j.VoiceID)
	}
	return j.Kind
}

// ErrLeaseLost means the API no longer considers this worker the job's owner (404/409).
var ErrLeaseLost = errors.New("job lease lost")

// Client for hajanek-api with WORKER_TOKEN (CONTRACTS §6, api/README.md):
//
//	POST /v1/jobs/claim            {worker, kinds} -> 200 Job | 204 (empty queue)
//	POST /v1/jobs/{id}/heartbeat   {worker}        -> 2xx; 409 lease lost, 404 unknown
//	POST /v1/jobs/{id}/complete    {worker, ok, result, error, retry}
type Client struct {
	BaseURL, Token, Worker string
	HTTP                   *http.Client
}

// FromEnv builds a client from FORGE_API_URL, WORKER_TOKEN and FORGE_WORKER_NAME
// (default: hostname); nil when the API is not configured.
func FromEnv() *Client {
	u, t := os.Getenv("FORGE_API_URL"), os.Getenv("WORKER_TOKEN")
	if u == "" || t == "" {
		return nil
	}
	host, _ := os.Hostname()
	if w := os.Getenv("FORGE_WORKER_NAME"); w != "" {
		host = w
	}
	return &Client{BaseURL: strings.TrimRight(u, "/"), Token: t, Worker: host, HTTP: &http.Client{Timeout: 2 * time.Minute}}
}

// HTTPError is a non-2xx response.
type HTTPError struct {
	Method, Path string
	Status       int
	Body         string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("api %s %s: HTTP %d: %s", e.Method, e.Path, e.Status, strings.TrimSpace(e.Body))
}

// Do sends a request with the worker token. body may be nil, []byte or a
// value encoded as JSON. Non-2xx responses are returned as *HTTPError.
func (c *Client) Do(ctx context.Context, method, path string, body any, header http.Header) (*http.Response, []byte, error) {
	var rd io.Reader
	ctype := ""
	switch b := body.(type) {
	case nil:
	case []byte:
		rd = bytes.NewReader(b)
	default:
		jb, err := json.Marshal(b)
		if err != nil {
			return nil, nil, err
		}
		rd, ctype = bytes.NewReader(jb), "application/json"
	}
	req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, rd)
	if err != nil {
		return nil, nil, err
	}
	for k, v := range header {
		req.Header[k] = v
	}
	if ctype != "" && req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", ctype)
	}
	req.Header.Set("Authorization", "Bearer "+c.Token)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	rb, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp, nil, err
	}
	if resp.StatusCode/100 != 2 {
		return resp, rb, &HTTPError{Method: method, Path: path, Status: resp.StatusCode, Body: truncate(string(rb), 500)}
	}
	return resp, rb, nil
}

// Claim returns the next job of one of kinds (empty = any) or nil when the queue is empty.
func (c *Client) Claim(ctx context.Context, kinds []string) (*Job, error) {
	body := map[string]any{"worker": c.Worker}
	if len(kinds) > 0 {
		body["kinds"] = kinds
	}
	resp, b, err := c.Do(ctx, http.MethodPost, "/v1/jobs/claim", body, nil)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode == http.StatusNoContent || len(bytes.TrimSpace(b)) == 0 {
		return nil, nil
	}
	var j Job
	if err := json.Unmarshal(b, &j); err != nil {
		return nil, fmt.Errorf("claim: %w", err)
	}
	if j.ID == "" {
		return nil, nil
	}
	return &j, nil
}

// Heartbeat extends the job's lease once; ErrLeaseLost on 404/409.
func (c *Client) Heartbeat(ctx context.Context, id string) error {
	_, _, err := c.Do(ctx, http.MethodPost, "/v1/jobs/"+id+"/heartbeat", map[string]string{"worker": c.Worker}, nil)
	var he *HTTPError
	if errors.As(err, &he) && (he.Status == http.StatusNotFound || he.Status == http.StatusConflict) {
		return ErrLeaseLost
	}
	return err
}

// KeepAlive heartbeats every interval until ctx is done; on a lost lease it
// calls lost (e.g. to cancel the job's context) and stops.
func (c *Client) KeepAlive(ctx context.Context, id string, every time.Duration, lost func()) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if errors.Is(c.Heartbeat(ctx, id), ErrLeaseLost) {
				lost()
				return
			}
		}
	}
}

// Complete reports the result; retry=true returns the job to the queue (transient failure).
func (c *Client) Complete(ctx context.Context, id string, ok bool, errMsg string, retry bool, result any) error {
	_, _, err := c.Do(ctx, http.MethodPost, "/v1/jobs/"+id+"/complete",
		map[string]any{"worker": c.Worker, "ok": ok, "error": errMsg, "retry": retry && !ok, "result": result}, nil)
	return err
}

// ReadQueue parses "tale length [kind]" lines ('#' comments); kind defaults to script.
func ReadQueue(path string) ([]Job, error) {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	defer func() { _ = f.Close() }()
	var out []Job
	sc := bufio.NewScanner(f)
	n := 0
	for sc.Scan() {
		n++
		l := strings.TrimSpace(sc.Text())
		if i := strings.Index(l, "#"); i >= 0 {
			l = strings.TrimSpace(l[:i])
		}
		if l == "" {
			continue
		}
		fs := strings.Fields(l)
		if fs[0] == KindPublish {
			out = append(out, Job{ID: fmt.Sprintf("queue-%d", n), Kind: KindPublish})
			continue
		}
		if len(fs) < 2 {
			return nil, fmt.Errorf("%s:%d: want 'tale length [kind]' or 'publish'", path, n)
		}
		ln, err := strconv.Atoi(fs[1])
		if err != nil {
			return nil, fmt.Errorf("%s:%d: bad length %q", path, n, fs[1])
		}
		j := Job{ID: fmt.Sprintf("queue-%d", n), Kind: KindScript, Tale: fs[0], LengthMin: ln}
		if len(fs) > 2 {
			j.Kind = fs[2]
		}
		out = append(out, j)
	}
	return out, sc.Err()
}

// NotifyDiscord posts content to DISCORD_WEBHOOK if set.
func NotifyDiscord(ctx context.Context, content string) error {
	url := os.Getenv("DISCORD_WEBHOOK")
	if url == "" {
		return nil
	}
	content = truncate(content, 1900)
	b, _ := json.Marshal(map[string]string{"content": content, "username": "hajanek-forge"})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: 15 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	_ = resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("discord: HTTP %d", resp.StatusCode)
	}
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return strings.ToValidUTF8(s[:n], "") + "…"
}
