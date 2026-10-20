package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestClientRoundTrip(t *testing.T) {
	var completed, claimed map[string]any
	claims := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer tok" {
			w.WriteHeader(401)
			return
		}
		switch r.URL.Path {
		case "/v1/jobs/claim":
			claims++
			if err := json.NewDecoder(r.Body).Decode(&claimed); err != nil {
				t.Error(err)
			}
			if claims > 1 {
				w.WriteHeader(204)
				return
			}
			_, _ = w.Write([]byte(`{"id":"j1","kind":"render","payload":{"voice_id":"v1","tale":"zlatovlaska","length_min":10},"status":"running"}`))
		case "/v1/jobs/j1/heartbeat":
			w.WriteHeader(409)
		case "/v1/jobs/j1/complete":
			if err := json.NewDecoder(r.Body).Decode(&completed); err != nil {
				t.Error(err)
			}
		default:
			w.WriteHeader(404)
		}
	}))
	defer srv.Close()
	c := &Client{BaseURL: srv.URL, Token: "tok", Worker: "spark-1", HTTP: srv.Client()}
	j, err := c.Claim(context.Background(), []string{KindRender})
	if err != nil || j == nil || j.Tale != "zlatovlaska" || j.LengthMin != 10 || j.VoiceID != "v1" {
		t.Fatalf("claim: %+v %v", j, err)
	}
	if claimed["worker"] != "spark-1" || len(claimed["kinds"].([]any)) != 1 {
		t.Errorf("claim body %v", claimed)
	}
	if j2, err := c.Claim(context.Background(), nil); err != nil || j2 != nil {
		t.Fatalf("empty queue: %+v %v", j2, err)
	}
	if err := c.Heartbeat(context.Background(), "j1"); !errors.Is(err, ErrLeaseLost) {
		t.Errorf("heartbeat 409: %v", err)
	}
	if err := c.Complete(context.Background(), "j1", false, "audio: HTTP 503", true, map[string]int{"done": 1}); err != nil {
		t.Fatal(err)
	}
	if completed["worker"] != "spark-1" || completed["ok"] != false || completed["retry"] != true {
		t.Errorf("complete body %v", completed)
	}
}

func TestJobUnmarshalFlat(t *testing.T) {
	var j Job
	if err := json.Unmarshal([]byte(`{"id":"a","kind":"voice_create","voice":"v9"}`), &j); err != nil || j.VoiceID != "v9" {
		t.Errorf("%+v %v", j, err)
	}
}

func TestReadQueue(t *testing.T) {
	p := filepath.Join(t.TempDir(), "q.txt")
	if err := os.WriteFile(p, []byte("# comment\nzlatovlaska 10\nsnehurka 10 script # inline\npublish\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	q, err := ReadQueue(p)
	if err != nil || len(q) != 3 {
		t.Fatalf("%v %v", q, err)
	}
	if q[0].Kind != KindScript || q[0].LengthMin != 10 || q[1].Tale != "snehurka" || q[2].Kind != KindPublish {
		t.Errorf("%+v", q)
	}
	if q, _ := ReadQueue(filepath.Join(t.TempDir(), "missing")); q != nil {
		t.Error("missing queue should be empty")
	}
}
