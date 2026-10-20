package jobs

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestClientRoundTrip(t *testing.T) {
	var completed map[string]any
	claims := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer tok" {
			w.WriteHeader(401)
			return
		}
		switch r.URL.Path {
		case "/v1/jobs/claim":
			claims++
			if claims > 1 {
				w.WriteHeader(204)
				return
			}
			if _, err := w.Write([]byte(`{"id":"j1","kind":"tale","tale":"zlatovlaska","voice":"mama","length_min":10,"status":"running"}`)); err != nil {
				t.Error(err)
			}
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
	j, err := c.Claim(context.Background())
	if err != nil || j == nil || j.Tale != "zlatovlaska" || j.LengthMin != 10 {
		t.Fatalf("claim: %+v %v", j, err)
	}
	if j2, err := c.Claim(context.Background()); err != nil || j2 != nil {
		t.Fatalf("empty queue: %+v %v", j2, err)
	}
	if err := c.Complete(context.Background(), "j1", false, "llm: HTTP 503", true, map[string]int{"n": 1}); err != nil {
		t.Fatal(err)
	}
	if completed["worker"] != "spark-1" || completed["ok"] != false || completed["retry"] != true {
		t.Errorf("complete body %v", completed)
	}
}

func TestReadQueue(t *testing.T) {
	p := filepath.Join(t.TempDir(), "q.txt")
	if err := os.WriteFile(p, []byte("# comment\nzlatovlaska mama 10\ncervena-karkulka - 10 # all voices\nsnehurka mama 10 script\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	q, err := ReadQueue(p)
	if err != nil || len(q) != 3 {
		t.Fatalf("%v %v", q, err)
	}
	if q[1].Voice != "" || q[2].Kind != "script" || q[0].Kind != "tale" {
		t.Errorf("%+v", q)
	}
	if q, _ := ReadQueue(filepath.Join(t.TempDir(), "missing")); q != nil {
		t.Error("missing queue should be empty")
	}
}
