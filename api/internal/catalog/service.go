package catalog

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/lioilsources/hajanek/api/internal/db"
)

// maxCatalogBytes guards against a runaway or wrong URL.
const maxCatalogBytes = 8 << 20

// Snapshot is the last known-good catalog.
type Snapshot struct {
	Version   int64
	Body      []byte
	SHA256    string
	FetchedAt time.Time
	UpdatedAt time.Time
}

// Service polls the published catalog.json and caches the last good copy
// in SQLite. A catalog that fails validation never replaces a good one.
type Service struct {
	q      *db.Queries
	url    string
	client *http.Client
	log    *slog.Logger
	now    func() time.Time

	mu           sync.RWMutex
	cur          *Snapshot
	etag         string
	lastModified string
}

type Option func(*Service)

func WithHTTPClient(c *http.Client) Option  { return func(s *Service) { s.client = c } }
func WithClock(now func() time.Time) Option { return func(s *Service) { s.now = now } }
func WithLogger(l *slog.Logger) Option      { return func(s *Service) { s.log = l } }

func NewService(q *db.Queries, url string, opts ...Option) *Service {
	s := &Service{
		q:      q,
		url:    url,
		client: &http.Client{Timeout: 30 * time.Second},
		log:    slog.Default(),
		now:    time.Now,
	}
	for _, o := range opts {
		o(s)
	}
	return s
}

// URL is the public catalog.json URL clients are redirected to.
func (s *Service) URL() string { return s.url }

// Current returns the cached catalog, if any.
func (s *Service) Current() (Snapshot, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.cur == nil {
		return Snapshot{}, false
	}
	return *s.cur, true
}

// Load restores the cached catalog from the database.
func (s *Service) Load(ctx context.Context) error {
	row, err := s.q.GetCatalog(ctx)
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("load cached catalog: %w", err)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cur = &Snapshot{
		Version:   row.Version,
		Body:      row.Body,
		SHA256:    row.Sha256,
		FetchedAt: time.UnixMilli(row.FetchedAt).UTC(),
		UpdatedAt: time.UnixMilli(row.UpdatedAt).UTC(),
	}
	s.etag, s.lastModified = row.Etag, row.LastModified
	return nil
}

// Run polls immediately and then every interval until ctx is done.
func (s *Service) Run(ctx context.Context, interval time.Duration) {
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		if err := s.Poll(ctx); err != nil && ctx.Err() == nil {
			s.log.Warn("catalog poll failed", "url", s.url, "err", err)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

// Poll fetches the catalog once. It returns an error for network failures,
// non-2xx responses and invalid catalogs; the cached copy is kept in all cases.
func (s *Service) Poll(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.url, nil)
	if err != nil {
		return err
	}
	s.mu.RLock()
	etag, lastMod, cur := s.etag, s.lastModified, s.cur
	s.mu.RUnlock()
	if cur != nil {
		// Only send validators belonging to the cached good copy.
		if etag != "" {
			req.Header.Set("If-None-Match", etag)
		}
		if lastMod != "" {
			req.Header.Set("If-Modified-Since", lastMod)
		}
	}
	req.Header.Set("Accept", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("fetch: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	now := s.now()
	switch {
	case resp.StatusCode == http.StatusNotModified && cur != nil:
		return s.touch(ctx, now, etag, lastMod)
	case resp.StatusCode != http.StatusOK:
		return fmt.Errorf("fetch: unexpected status %s", resp.Status)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxCatalogBytes+1))
	if err != nil {
		return fmt.Errorf("read body: %w", err)
	}
	if len(body) > maxCatalogBytes {
		return fmt.Errorf("catalog larger than %d bytes", maxCatalogBytes)
	}
	newETag, newLastMod := resp.Header.Get("ETag"), resp.Header.Get("Last-Modified")
	sum := sha256.Sum256(body)
	sumHex := hex.EncodeToString(sum[:])

	if cur != nil && cur.SHA256 == sumHex {
		return s.touch(ctx, now, newETag, newLastMod)
	}

	c, err := Parse(body)
	if err != nil {
		return fmt.Errorf("invalid catalog: %w", err)
	}
	if cur != nil && c.Version <= cur.Version {
		return fmt.Errorf("invalid catalog: version %d is not newer than cached %d but content differs", c.Version, cur.Version)
	}

	if err := s.q.UpsertCatalog(ctx, db.UpsertCatalogParams{
		Version:      c.Version,
		Body:         body,
		Sha256:       sumHex,
		Etag:         newETag,
		LastModified: newLastMod,
		FetchedAt:    now.UnixMilli(),
		UpdatedAt:    now.UnixMilli(),
	}); err != nil {
		return fmt.Errorf("store catalog: %w", err)
	}
	s.mu.Lock()
	s.cur = &Snapshot{Version: c.Version, Body: body, SHA256: sumHex, FetchedAt: now.UTC(), UpdatedAt: now.UTC()}
	s.etag, s.lastModified = newETag, newLastMod
	s.mu.Unlock()

	prev := int64(0)
	if cur != nil {
		prev = cur.Version
	}
	s.log.Info("catalog updated", "version", c.Version, "previous", prev, "sha256", sumHex)
	return nil
}

func (s *Service) touch(ctx context.Context, now time.Time, etag, lastMod string) error {
	if err := s.q.TouchCatalog(ctx, db.TouchCatalogParams{
		FetchedAt:    now.UnixMilli(),
		Etag:         etag,
		LastModified: lastMod,
	}); err != nil {
		return fmt.Errorf("touch catalog: %w", err)
	}
	s.mu.Lock()
	if s.cur != nil {
		s.cur.FetchedAt = now.UTC()
	}
	s.etag, s.lastModified = etag, lastMod
	s.mu.Unlock()
	return nil
}
