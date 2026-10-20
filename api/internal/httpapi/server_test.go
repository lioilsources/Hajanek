package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/hajanek/api/internal/catalog"
	"github.com/lioilsources/hajanek/api/internal/db"
	"github.com/lioilsources/hajanek/api/internal/jobs"
)

const (
	adminToken  = "admin-secret"
	workerToken = "worker-secret"
)

type env struct {
	t     *testing.T
	h     http.Handler
	cat   *catalog.Service
	pages *httptest.Server
}

func newEnv(t *testing.T, withCatalog bool) *env {
	t.Helper()
	ctx := context.Background()
	sqldb, err := db.Open(ctx, filepath.Join(t.TempDir(), "api.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := sqldb.Close(); err != nil {
			t.Error(err)
		}
	})

	body, err := os.ReadFile("../catalog/testdata/valid.json")
	if err != nil {
		t.Fatal(err)
	}
	pages := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write(body)
	}))
	t.Cleanup(pages.Close)

	quiet := slog.New(slog.NewTextHandler(io.Discard, nil))
	cat := catalog.NewService(db.New(sqldb), pages.URL+"/catalog.json", catalog.WithLogger(quiet))
	if withCatalog {
		if err := cat.Poll(ctx); err != nil {
			t.Fatal(err)
		}
	}
	store := jobs.NewStore(sqldb, time.Minute, 3)
	store.Log = quiet
	s := &Server{DB: sqldb, Catalog: cat, Jobs: store, AdminToken: adminToken, WorkerToken: workerToken, Log: quiet}
	return &env{t: t, h: s.Handler(), cat: cat, pages: pages}
}

func (e *env) do(method, path, token, body string) *httptest.ResponseRecorder {
	e.t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func decodeJob(t *testing.T, rec *httptest.ResponseRecorder) jobs.Job {
	t.Helper()
	var j jobs.Job
	if err := json.Unmarshal(rec.Body.Bytes(), &j); err != nil {
		t.Fatalf("decode job: %v (%s)", err, rec.Body)
	}
	return j
}

func TestHealthz(t *testing.T) {
	e := newEnv(t, false)
	rec := e.do("GET", "/healthz", "", "")
	if rec.Code != 200 || strings.TrimSpace(rec.Body.String()) != `{"ok":true}` {
		t.Fatalf("healthz: %d %s", rec.Code, rec.Body)
	}
}

func TestCatalogEndpoints(t *testing.T) {
	t.Run("not yet fetched", func(t *testing.T) {
		e := newEnv(t, false)
		if rec := e.do("GET", "/v1/catalog/version", "", ""); rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("version: %d", rec.Code)
		}
		if rec := e.do("GET", "/v1/catalog?inline=1", "", ""); rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("inline: %d", rec.Code)
		}
		// The redirect works regardless of cache state.
		if rec := e.do("GET", "/v1/catalog", "", ""); rec.Code != http.StatusFound {
			t.Fatalf("redirect: %d", rec.Code)
		}
	})

	e := newEnv(t, true)
	rec := e.do("GET", "/v1/catalog", "", "")
	if rec.Code != http.StatusFound || rec.Header().Get("Location") != e.cat.URL() {
		t.Fatalf("redirect: %d %q", rec.Code, rec.Header().Get("Location"))
	}

	rec = e.do("GET", "/v1/catalog/version", "", "")
	var v struct {
		Version int    `json:"version"`
		URL     string `json:"url"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &v); err != nil || rec.Code != 200 || v.Version != 3 || v.URL != e.cat.URL() {
		t.Fatalf("version: %d %s", rec.Code, rec.Body)
	}

	rec = e.do("GET", "/v1/catalog?inline=1", "", "")
	if rec.Code != 200 || !strings.HasPrefix(rec.Header().Get("Content-Type"), "application/json") {
		t.Fatalf("inline: %d %v", rec.Code, rec.Header())
	}
	if _, err := catalog.Parse(rec.Body.Bytes()); err != nil {
		t.Fatalf("inline body invalid: %v", err)
	}
	etag := rec.Header().Get("ETag")
	req := httptest.NewRequest("GET", "/v1/catalog?inline=1", nil)
	req.Header.Set("If-None-Match", etag)
	rec = httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != http.StatusNotModified {
		t.Fatalf("conditional inline: %d", rec.Code)
	}
}

func TestAuth(t *testing.T) {
	e := newEnv(t, false)
	cases := []struct {
		method, path, token string
		want                int
	}{
		{"POST", "/v1/jobs", "", 401},
		{"POST", "/v1/jobs", workerToken, 401},
		{"POST", "/v1/jobs", "nope", 401},
		{"GET", "/v1/jobs", "", 401},
		{"GET", "/v1/jobs", workerToken, 200},
		{"GET", "/v1/jobs", adminToken, 200},
		{"POST", "/v1/jobs/claim", adminToken, 401},
		{"POST", "/v1/jobs/claim", workerToken, 204},
		{"POST", "/v1/jobs/x/complete", adminToken, 401},
		{"POST", "/v1/jobs/x/heartbeat", "", 401},
	}
	for _, c := range cases {
		if rec := e.do(c.method, c.path, c.token, ""); rec.Code != c.want {
			t.Errorf("%s %s token=%q: got %d want %d (%s)", c.method, c.path, c.token, rec.Code, c.want, rec.Body)
		}
	}
}

func TestJobLifecycle(t *testing.T) {
	e := newEnv(t, false)

	rec := e.do("POST", "/v1/jobs", adminToken, `{"kind":"voice","tale":"zlatovlaska","voice":"mama","length_min":10,"priority":2}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: %d %s", rec.Code, rec.Body)
	}
	job := decodeJob(t, rec)
	if job.Status != jobs.StatusQueued || rec.Header().Get("Location") != "/v1/jobs/"+job.ID {
		t.Fatalf("create: %+v", job)
	}

	rec = e.do("POST", "/v1/jobs", adminToken, `{"kind":"voice","tale":"zlatovlaska","voice":"mama"}`)
	if rec.Code != http.StatusOK || rec.Header().Get("X-Deduplicated") != "true" || decodeJob(t, rec).ID != job.ID {
		t.Fatalf("dedupe: %d %s", rec.Code, rec.Body)
	}

	for _, bad := range []string{
		`{"kind":"voice","tale":"zlatovlaska"}`,
		`{"kind":"dance","tale":"zlatovlaska"}`,
		`{"kind":"script","tale":"Zlatovláska"}`,
		`{"kind":"script","tale":"zlatovlaska","extra":1}`,
		`not json`,
	} {
		if rec := e.do("POST", "/v1/jobs", adminToken, bad); rec.Code != http.StatusBadRequest {
			t.Errorf("bad spec %s: %d", bad, rec.Code)
		}
	}

	rec = e.do("GET", "/v1/jobs/"+job.ID, adminToken, "")
	if rec.Code != 200 || decodeJob(t, rec).ID != job.ID {
		t.Fatalf("get: %d", rec.Code)
	}
	if rec := e.do("GET", "/v1/jobs/missing", adminToken, ""); rec.Code != 404 {
		t.Fatalf("get missing: %d", rec.Code)
	}

	if rec := e.do("POST", "/v1/jobs/claim", workerToken, `{"kinds":["bogus"]}`); rec.Code != 400 {
		t.Fatalf("claim bad kind: %d", rec.Code)
	}
	if rec := e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark","kinds":["script"]}`); rec.Code != 204 {
		t.Fatalf("claim other kind: %d", rec.Code)
	}
	rec = e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark"}`)
	claimed := decodeJob(t, rec)
	if rec.Code != 200 || claimed.ID != job.ID || claimed.Status != jobs.StatusRunning || claimed.Worker != "spark" {
		t.Fatalf("claim: %d %s", rec.Code, rec.Body)
	}

	if rec := e.do("POST", "/v1/jobs/"+job.ID+"/heartbeat", workerToken, `{"worker":"spark"}`); rec.Code != 200 {
		t.Fatalf("heartbeat: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("POST", "/v1/jobs/"+job.ID+"/heartbeat", workerToken, `{"worker":"other"}`); rec.Code != 409 {
		t.Fatalf("foreign heartbeat: %d", rec.Code)
	}
	if rec := e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken, `{"worker":"spark"}`); rec.Code != 400 {
		t.Fatalf("complete without ok: %d", rec.Code)
	}
	if rec := e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken, `{"worker":"spark","ok":false}`); rec.Code != 400 {
		t.Fatalf("failure without error: %d", rec.Code)
	}

	rec = e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken,
		`{"worker":"spark","ok":true,"result":{"path":"audio/zlatovlaska/mama/10.opus","lufs":-23.1}}`)
	done := decodeJob(t, rec)
	if rec.Code != 200 || done.Status != jobs.StatusDone || !strings.Contains(string(done.Result), "lufs") {
		t.Fatalf("complete: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken, `{"worker":"spark","ok":true}`); rec.Code != 409 {
		t.Fatalf("double complete: %d", rec.Code)
	}
	if rec := e.do("POST", "/v1/jobs/missing/complete", workerToken, `{"ok":true}`); rec.Code != 404 {
		t.Fatalf("complete missing: %d", rec.Code)
	}

	rec = e.do("GET", "/v1/jobs?status=done", adminToken, "")
	var list struct{ Jobs []jobs.Job }
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil || len(list.Jobs) != 1 {
		t.Fatalf("list: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("GET", "/v1/jobs?status=weird", adminToken, ""); rec.Code != 400 {
		t.Fatalf("list bad status: %d", rec.Code)
	}
}
