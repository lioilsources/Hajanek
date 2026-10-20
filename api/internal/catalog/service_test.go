package catalog

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"sync"
	"testing"

	"github.com/lioilsources/hajanek/api/internal/db"
)

// fakePages serves a mutable catalog body with an ETag.
type fakePages struct {
	mu       sync.Mutex
	body     []byte
	etag     string
	status   int
	requests int
	lastINM  string
}

func (f *fakePages) set(body []byte, etag string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.body, f.etag, f.status = body, etag, http.StatusOK
}

func (f *fakePages) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.requests++
	f.lastINM = r.Header.Get("If-None-Match")
	if f.status != http.StatusOK {
		w.WriteHeader(f.status)
		return
	}
	if f.etag != "" && f.lastINM == f.etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	w.Header().Set("ETag", f.etag)
	_, _ = w.Write(f.body)
}

func catalogJSON(t *testing.T, mutate func(*Catalog)) []byte {
	t.Helper()
	c := validCatalog(t)
	mutate(c)
	b, err := json.Marshal(c)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func newTestService(t *testing.T, url string) (*Service, *db.Queries) {
	t.Helper()
	sqldb, err := db.Open(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := sqldb.Close(); err != nil {
			t.Error(err)
		}
	})
	q := db.New(sqldb)
	return NewService(q, url, WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil)))), q
}

func TestPollKeepsLastGood(t *testing.T) {
	ctx := context.Background()
	pages := &fakePages{}
	srv := httptest.NewServer(pages)
	defer srv.Close()
	svc, q := newTestService(t, srv.URL+"/catalog.json")

	if _, ok := svc.Current(); ok {
		t.Fatal("expected empty cache")
	}

	// 1. Good catalog v3 is cached.
	pages.set(catalogJSON(t, func(c *Catalog) {}), `"v3"`)
	if err := svc.Poll(ctx); err != nil {
		t.Fatalf("poll good: %v", err)
	}
	snap, ok := svc.Current()
	if !ok || snap.Version != 3 {
		t.Fatalf("want cached v3, got %+v ok=%v", snap.Version, ok)
	}

	// 2. Unchanged → conditional request answered with 304.
	if err := svc.Poll(ctx); err != nil {
		t.Fatalf("poll 304: %v", err)
	}
	if pages.lastINM != `"v3"` {
		t.Fatalf("If-None-Match not sent, got %q", pages.lastINM)
	}

	// 3. Invalid catalog never replaces the good one.
	pages.set(catalogJSON(t, func(c *Catalog) { c.Version = 4; c.Presets[0].Layers[0].Volume = ptr(2.0) }), `"bad"`)
	if err := svc.Poll(ctx); err == nil {
		t.Fatal("expected validation error")
	}
	pages.set([]byte("<html>oops</html>"), `"html"`)
	if err := svc.Poll(ctx); err == nil {
		t.Fatal("expected decode error")
	}
	// 4. Older version with different content is rejected too.
	pages.set(catalogJSON(t, func(c *Catalog) { c.Version = 2 }), `"v2"`)
	if err := svc.Poll(ctx); err == nil {
		t.Fatal("expected version regression error")
	}
	// 5. Upstream outage keeps the cache.
	pages.mu.Lock()
	pages.status = http.StatusBadGateway
	pages.mu.Unlock()
	if err := svc.Poll(ctx); err == nil {
		t.Fatal("expected status error")
	}
	if snap, _ := svc.Current(); snap.Version != 3 {
		t.Fatalf("cache replaced, now v%d", snap.Version)
	}

	// 6. Newer valid catalog replaces it and survives a restart.
	pages.set(catalogJSON(t, func(c *Catalog) { c.Version = 4 }), `"v4"`)
	if err := svc.Poll(ctx); err != nil {
		t.Fatalf("poll v4: %v", err)
	}
	restarted := NewService(q, srv.URL+"/catalog.json")
	if err := restarted.Load(ctx); err != nil {
		t.Fatal(err)
	}
	snap, ok = restarted.Current()
	if !ok || snap.Version != 4 {
		t.Fatalf("after restart want v4, got v%d ok=%v", snap.Version, ok)
	}
	if _, err := Parse(snap.Body); err != nil {
		t.Fatalf("cached body invalid: %v", err)
	}
}
