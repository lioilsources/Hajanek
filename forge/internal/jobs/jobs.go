// Package jobs talks to hajanek-api's job queue (CONTRACTS §6), reads the local
// queue file and posts Discord notifications.
package jobs

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

type Job struct {
	ID        string `json:"id"`
	Kind      string `json:"kind"` // script | voice | master | publish | tale (full run)
	Tale      string `json:"tale"`
	Voice     string `json:"voice"`
	LengthMin int    `json:"length_min"`
}

func (j Job) String() string { return fmt.Sprintf("%s/%s/%d", j.Tale, j.Voice, j.LengthMin) }

// Client for /v1/jobs/* (CONTRACTS §6, api/README.md):
//
//	POST /v1/jobs/claim            {worker, kinds} -> 200 Job | 204 (empty queue)
//	POST /v1/jobs/{id}/heartbeat   {worker}        -> 2xx; 409 lease lost, 404 unknown
//	POST /v1/jobs/{id}/complete    {worker, ok, result, error, retry}
type Client struct {
	BaseURL, Token, Worker string
	Kinds                  []string // empty = all
	HTTP                   *http.Client
}

func FromEnv() *Client {
	u, t := os.Getenv("FORGE_API_URL"), os.Getenv("WORKER_TOKEN")
	if u == "" || t == "" {
		return nil
	}
	host, _ := os.Hostname()
	if w := os.Getenv("FORGE_WORKER_NAME"); w != "" {
		host = w
	}
	var kinds []string
	if k := os.Getenv("FORGE_JOB_KINDS"); k != "" {
		kinds = strings.Split(k, ",")
	}
	return &Client{BaseURL: strings.TrimRight(u, "/"), Token: t, Worker: host, Kinds: kinds, HTTP: &http.Client{Timeout: 30 * time.Second}}
}

func (c *Client) post(ctx context.Context, path string, body any) (*http.Response, []byte, error) {
	b, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+path, bytes.NewReader(b))
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.Token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	rb, _ := io.ReadAll(resp.Body)
	return resp, rb, nil
}

// Claim returns the next job or nil when the queue is empty.
func (c *Client) Claim(ctx context.Context) (*Job, error) {
	resp, b, err := c.post(ctx, "/v1/jobs/claim", map[string]any{"worker": c.Worker, "kinds": c.Kinds})
	if err != nil {
		return nil, err
	}
	if resp.StatusCode == http.StatusNoContent || (resp.StatusCode == 200 && len(bytes.TrimSpace(b)) == 0) {
		return nil, nil
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("claim: HTTP %d: %s", resp.StatusCode, b)
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

// Heartbeat extends the lease until ctx is done; stops on 404/409 (lease lost).
func (c *Client) Heartbeat(ctx context.Context, id string, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			resp, _, err := c.post(ctx, "/v1/jobs/"+id+"/heartbeat", map[string]string{"worker": c.Worker})
			if err == nil && (resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusConflict) {
				return
			}
		}
	}
}

// Complete reports the result; retry=true returns the job to the queue (transient failure).
func (c *Client) Complete(ctx context.Context, id string, ok bool, errMsg string, retry bool, result any) error {
	resp, b, err := c.post(ctx, "/v1/jobs/"+id+"/complete",
		map[string]any{"worker": c.Worker, "ok": ok, "error": errMsg, "retry": retry && !ok, "result": result})
	if err != nil {
		return err
	}
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("complete: HTTP %d: %s", resp.StatusCode, b)
	}
	return nil
}

// ReadQueue parses "tale voice length [kind]" lines ('#' comments); voice "-" = all voices.
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
		if len(fs) < 3 {
			return nil, fmt.Errorf("%s:%d: want 'tale voice length [kind]'", path, n)
		}
		ln, err := strconv.Atoi(fs[2])
		if err != nil {
			return nil, fmt.Errorf("%s:%d: bad length %q", path, n, fs[2])
		}
		j := Job{ID: fmt.Sprintf("queue-%d", n), Kind: "tale", Tale: fs[0], Voice: fs[1], LengthMin: ln}
		if j.Voice == "-" {
			j.Voice = ""
		}
		if len(fs) > 3 {
			j.Kind = fs[3]
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
	if len(content) > 1900 {
		content = content[:1900] + "…"
	}
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
