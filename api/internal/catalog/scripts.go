package catalog

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
)

// maxScriptBytes bounds a single script download.
const maxScriptBytes = 1 << 20

var (
	// ErrNoCatalog means no valid catalog has been fetched yet.
	ErrNoCatalog = errors.New("catalog not available yet")
	// ErrNoScript means the current catalog has no script for tale/length.
	ErrNoScript = errors.New("script not in catalog")
)

// ScriptRef looks up the script of tale at length in the current catalog.
func (s *Service) ScriptRef(tale string, length int) (Script, error) {
	snap, ok := s.Current()
	if !ok || snap.Catalog == nil {
		return Script{}, ErrNoCatalog
	}
	sc, ok := snap.Catalog.Script(tale, length)
	if !ok {
		return Script{}, ErrNoScript
	}
	return sc, nil
}

// Script returns the verified text of tale/length from the current catalog.
// Scripts are fetched from base_url on first use and cached by sha256 (in
// memory and, with WithScriptDir, on disk), so a new catalog version that
// changes a script automatically yields the new text.
func (s *Service) Script(ctx context.Context, tale string, length int) ([]byte, Script, error) {
	snap, ok := s.Current()
	if !ok || snap.Catalog == nil {
		return nil, Script{}, ErrNoCatalog
	}
	sc, ok := snap.Catalog.Script(tale, length)
	if !ok {
		return nil, Script{}, ErrNoScript
	}

	s.scriptMu.Lock()
	body, ok := s.scripts[sc.SHA256]
	s.scriptMu.Unlock()
	if ok {
		return body, sc, nil
	}
	if body, ok := s.readCachedScript(sc.SHA256); ok {
		s.remember(sc.SHA256, body)
		return body, sc, nil
	}

	body, err := s.fetchScript(ctx, snap.Catalog.BaseURL+sc.Path, sc.SHA256)
	if err != nil {
		return nil, Script{}, err
	}
	s.remember(sc.SHA256, body)
	if s.scriptDir != "" {
		if err := writeAtomic(s.scriptDir, sc.SHA256+".md", body); err != nil {
			s.log.Warn("cache script", "sha256", sc.SHA256, "err", err)
		}
	}
	return body, sc, nil
}

func (s *Service) remember(sum string, body []byte) {
	s.scriptMu.Lock()
	s.scripts[sum] = body
	s.scriptMu.Unlock()
}

func (s *Service) readCachedScript(sum string) ([]byte, bool) {
	if s.scriptDir == "" {
		return nil, false
	}
	body, err := os.ReadFile(filepath.Join(s.scriptDir, sum+".md"))
	if err != nil || sha256Hex(body) != sum {
		return nil, false
	}
	return body, true
}

func (s *Service) fetchScript(ctx context.Context, url, sum string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch script: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fetch script %s: unexpected status %s", url, resp.Status)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxScriptBytes+1))
	if err != nil {
		return nil, fmt.Errorf("fetch script: %w", err)
	}
	if len(body) > maxScriptBytes {
		return nil, fmt.Errorf("fetch script %s: larger than %d bytes", url, maxScriptBytes)
	}
	if got := sha256Hex(body); got != sum {
		return nil, fmt.Errorf("fetch script %s: sha256 %s does not match catalog %s", url, got, sum)
	}
	return body, nil
}

func sha256Hex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

// writeAtomic writes dir/name via a temp file and rename.
func writeAtomic(dir, name string, body []byte) error {
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	f, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err := f.Write(body); err != nil {
		_ = f.Close()
		_ = os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, filepath.Join(dir, name)); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}
