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

// SourceLang is the language of content/scripts; other languages live in
// content/i18n/{lang}/ (docs/I18N_PLAN.md).
const SourceLang = "cs"

// scriptDirs lists where scripts of lang live, in lookup order.
func (e *Env) scriptDirs(lang string) []string {
	if lang == "" || lang == SourceLang {
		return []string{filepath.Join(e.Content, "scripts"), filepath.Join(e.Content, "scripts", "gold")}
	}
	return []string{filepath.Join(e.Content, "i18n", lang, "scripts")}
}

// Langs returns the source language and every content/i18n/{lang} directory.
func (e *Env) Langs() []string {
	out := []string{SourceLang}
	ents, _ := os.ReadDir(filepath.Join(e.Content, "i18n"))
	for _, en := range ents {
		if en.IsDir() {
			out = append(out, en.Name())
		}
	}
	return out
}

// ScriptPath resolves content/scripts/{id}.{len}.md, falling back to scripts/gold/.
func (e *Env) ScriptPath(tale string, length int) (string, error) {
	return e.scriptPath(SourceLang, tale, length)
}

func (e *Env) scriptPath(lang, tale string, length int) (string, error) {
	name := fmt.Sprintf("%s.%d.md", tale, length)
	for _, p := range e.scriptDirs(lang) {
		if _, err := os.Stat(filepath.Join(p, name)); err == nil {
			return filepath.Join(p, name), nil
		}
	}
	return "", fmt.Errorf("script %s (%s) not found in %v", name, lang, e.scriptDirs(lang))
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

// JudgeConfig is the judge setup for a script in lang ("" = cs): its own
// forbidden words (content/i18n/{lang}/forbidden_words.txt) and the
// judge.languages overrides.
func (e *Env) JudgeConfig(length int, lang string) judge.Config {
	j := e.Cfg.Judge
	wpm, maxWords := e.WPM(lang), j.MaxSentenceWords
	forbidden := e.contentPath(j.ForbiddenWordsFile)
	if lang != "" && lang != SourceLang {
		forbidden = filepath.Join(e.Content, "i18n", lang, "forbidden_words.txt")
		if l := j.Languages[lang]; l.MaxSentenceWords > 0 {
			maxWords = l.MaxSentenceWords
		}
	}
	return judge.Config{
		LengthMin: length, WPM: wpm, RefSpeed: j.RefSpeed, GapS: e.Cfg.Speech.GapS,
		Tolerance: j.LengthTolerance, MaxSentenceWords: maxWords,
		Budgets10: j.SectionBudgets10, Forbidden: judge.LoadForbidden(forbidden),
		Prosody: e.Prosody(),
	}
}

// WPM is the speaking rate the estimates use for lang.
func (e *Env) WPM(lang string) float64 {
	if l := e.Cfg.Judge.Languages[lang]; l.WPM > 0 {
		return l.WPM
	}
	return e.Cfg.Judge.WPM
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
