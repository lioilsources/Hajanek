// Package pipeline implements the forge steps: script, judge, master-ambient, publish, nightly.
package pipeline

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"

	"github.com/lioilsources/hajanek/forge/internal/config"
	"github.com/lioilsources/hajanek/forge/internal/judge"
	"github.com/lioilsources/hajanek/forge/internal/script"
)

type Env struct {
	Repo    string // monorepo root
	Forge   string // forge/
	Content string // content/ (overridable for tests)
	Work    string
	Cfg     *config.Config
	Force   bool
	Log     *log.Logger
}

// FindRepo walks up from dir to the directory containing forge/go.mod.
func FindRepo(dir string) (string, error) {
	if v := os.Getenv("HAJANEK_ROOT"); v != "" {
		return filepath.Abs(v)
	}
	d, _ := filepath.Abs(dir)
	for {
		if _, err := os.Stat(filepath.Join(d, "forge", "go.mod")); err == nil {
			return d, nil
		}
		p := filepath.Dir(d)
		if p == d {
			return "", errors.New("cannot find repo root (dir with forge/go.mod); set HAJANEK_ROOT or --repo")
		}
		d = p
	}
}

func NewEnv(repo, content, cfgPath string) (*Env, error) {
	e := &Env{Repo: repo, Forge: filepath.Join(repo, "forge"), Log: log.New(os.Stderr, "forge: ", 0)}
	if cfgPath == "" {
		cfgPath = filepath.Join(e.Forge, "config.yaml")
	}
	cfg, err := config.Load(cfgPath)
	if err != nil {
		return nil, err
	}
	e.Cfg = cfg
	e.Content = content
	if e.Content == "" {
		e.Content = filepath.Join(repo, "content")
	}
	e.Content, _ = filepath.Abs(e.Content)
	e.Work = e.forgePath(cfg.WorkDir)
	return e, nil
}

func (e *Env) forgePath(p string) string {
	if filepath.IsAbs(p) {
		return p
	}
	return filepath.Join(e.Forge, p)
}

func (e *Env) contentPath(p string) string {
	if filepath.IsAbs(p) {
		return p
	}
	return filepath.Join(e.Content, p)
}

// ScriptPath resolves content/scripts/{id}.{len}.md, falling back to scripts/gold/.
func (e *Env) ScriptPath(tale string, length int) (string, error) {
	name := fmt.Sprintf("%s.%d.md", tale, length)
	for _, p := range []string{filepath.Join(e.Content, "scripts", name), filepath.Join(e.Content, "scripts", "gold", name)} {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return "", fmt.Errorf("script %s not found in %s/scripts{,/gold}", name, e.Content)
}

// Prosody returns the tone speeds and dojezd ramp from config (CONTRACTS §2).
func (e *Env) Prosody() script.Prosody {
	sp := e.Cfg.Speech
	p := script.Prosody{Speeds: map[script.Tone]float64{}, RampSection: sp.Ramp.Section, RampSpeedTo: sp.Ramp.SpeedTo}
	for k, v := range sp.Tones {
		p.Speeds[script.Tone(k)] = v.Speed
	}
	return p
}

func (e *Env) JudgeConfig(length int) judge.Config {
	j := e.Cfg.Judge
	return judge.Config{
		LengthMin: length, WPM: j.WPM, RefSpeed: j.RefSpeed, GapS: e.Cfg.Speech.GapS,
		Tolerance: j.LengthTolerance, MaxSentenceWords: j.MaxSentenceWords,
		Budgets10: j.SectionBudgets10, Forbidden: judge.LoadForbidden(e.contentPath(j.ForbiddenWordsFile)),
		Prosody: e.Prosody(),
	}
}

// --- small helpers ---

func fileSHA256(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer func() { _ = f.Close() }()
	h := sha256.New()
	n, err := io.Copy(h, f)
	if err != nil {
		return "", 0, err
	}
	return hex.EncodeToString(h.Sum(nil)), n, nil
}

func writeJSON(path string, v any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, append(b, '\n'), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer func() { _ = in.Close() }()
	tmp := dst + ".tmp"
	out, err := os.Create(tmp)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}
