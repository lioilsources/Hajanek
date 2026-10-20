package pipeline

import (
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/lioilsources/hajanek/forge/internal/judge"
	"github.com/lioilsources/hajanek/forge/internal/llm"
	"github.com/lioilsources/hajanek/forge/internal/script"
)

// Tale is a source retelling: content/tales/{id}.md (front matter + text).
type Tale struct {
	Meta map[string]any
	Text string
}

func splitFrontMatter(src string) (string, string, error) {
	src = strings.ReplaceAll(src, "\r\n", "\n")
	if !strings.HasPrefix(src, "---\n") {
		return "", src, errors.New("missing front matter")
	}
	rest := src[4:]
	i := strings.Index(rest, "\n---")
	if i < 0 {
		return "", src, errors.New("unterminated front matter")
	}
	body := rest[i+4:]
	body = strings.TrimPrefix(body, "\n")
	return rest[:i], body, nil
}

func LoadTale(path string) (*Tale, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	fm, body, err := splitFrontMatter(string(b))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	t := &Tale{Meta: map[string]any{}, Text: strings.TrimSpace(body)}
	if err := yaml.Unmarshal([]byte(fm), &t.Meta); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return t, nil
}

var reVar = regexp.MustCompile(`\{\{\s*([a-z_]+)\s*\}\}`)

// renderTemplate substitutes {{var}}; unknown names (e.g. {{osloveni|…}}) are kept.
func renderTemplate(tpl string, vars map[string]string) string {
	return reVar.ReplaceAllStringFunc(tpl, func(m string) string {
		k := reVar.FindStringSubmatch(m)[1]
		if v, ok := vars[k]; ok {
			return v
		}
		return m
	})
}

func metaString(v any) string {
	switch x := v.(type) {
	case nil:
		return ""
	case []any:
		parts := make([]string, len(x))
		for i, p := range x {
			parts[i] = fmt.Sprint(p)
		}
		return strings.Join(parts, ", ")
	default:
		return fmt.Sprint(x)
	}
}

// targets computes words_target and pauses_target_s from the gold scripts' pause ratio.
func (e *Env) targets(length int, gold []*script.Script) (int, int) {
	total := float64(length) * 60
	ratio := 0.35
	var ps, ts float64
	for _, g := range gold {
		est := e.Prosody().Estimate(g, script.EstimateParams{WPM: e.Cfg.Judge.WPM, RefSpeed: e.Cfg.Judge.RefSpeed})
		ps += est.PauseS
		ts += est.TotalS
	}
	if ts > 0 {
		ratio = ps / ts
	}
	// Leave room for inter-utterance gaps added by the player (≈ 1 gap per 9 words).
	pauses := total * ratio
	speech := total - pauses
	words := speech * e.Cfg.Judge.WPM / 60 / (1 + e.Cfg.Speech.GapS*e.Cfg.Judge.WPM/60/9)
	return int(math.Round(words/10) * 10), int(math.Round(pauses/5) * 5)
}

func (e *Env) taleVars(t *Tale, id string, length, words, pauses int) map[string]string {
	v := map[string]string{
		"tale_id": id, "length_min": fmt.Sprint(length), "tale_text": t.Text,
		"words_target": fmt.Sprint(words), "pauses_target_s": fmt.Sprint(pauses),
	}
	for _, k := range []string{"title", "source", "age", "setting", "ambient", "characters", "tension_original", "softening"} {
		v[k] = metaString(t.Meta[k])
	}
	return v
}

type ScriptOpts struct {
	Tale   string
	Length int
	Out    string // default content/scripts/{tale}.{len}.md
}

// GenerateScript asks the LLM for a script, retrying with judge feedback, and
// writes it with status: draft. Returns the path and the final judge report.
func (e *Env) GenerateScript(ctx context.Context, o ScriptOpts) (string, *judge.Report, error) {
	out := o.Out
	if out == "" {
		out = filepath.Join(e.Content, "scripts", fmt.Sprintf("%s.%d.md", o.Tale, o.Length))
	}
	if _, err := os.Stat(out); err == nil && !e.Force {
		e.Log.Printf("script: %s exists (use --force to regenerate)", out)
		rep, err := e.Judge(ctx, out, o.Length, false)
		return out, rep, err
	}
	tale, err := LoadTale(filepath.Join(e.Content, "tales", o.Tale+".md"))
	if err != nil {
		return "", nil, err
	}
	tplSrc, err := os.ReadFile(e.contentPath(e.Cfg.LLM.Template))
	if err != nil {
		return "", nil, err
	}
	secs := judge.PromptSections(string(tplSrc))
	sys, user := secs["SYSTEM"], secs["USER"]
	if sys == "" || user == "" {
		return "", nil, fmt.Errorf("%s: needs '## SYSTEM' and '## USER' sections", e.Cfg.LLM.Template)
	}

	// Few-shot: two gold scripts (excluding the target tale), each preceded by its rendered USER prompt.
	goldDir := e.contentPath(e.Cfg.LLM.GoldDir)
	files, _ := filepath.Glob(filepath.Join(goldDir, "*.md"))
	sort.Strings(files)
	var golds []*script.Script
	var shots []llm.Message
	for _, f := range files {
		if len(golds) == 2 {
			break
		}
		if strings.HasPrefix(filepath.Base(f), o.Tale+".") {
			continue
		}
		b, err := os.ReadFile(f)
		if err != nil {
			return "", nil, err
		}
		g, err := script.Parse(b)
		if err != nil {
			e.Log.Printf("script: skipping invalid gold %s: %v", f, err)
			continue
		}
		golds = append(golds, g)
		gt, err := LoadTale(filepath.Join(e.Content, "tales", g.Meta.ID+".md"))
		if err != nil {
			gt = &Tale{Meta: map[string]any{"title": g.Meta.Title, "source": g.Meta.Source, "age": g.Meta.Age,
				"setting": g.Meta.Setting, "ambient": g.Meta.Ambient}, Text: "(předloha není k dispozici)"}
		}
		gw, gp := e.targets(g.Meta.LengthMin, []*script.Script{g})
		shots = append(shots,
			llm.Message{Role: "user", Content: renderTemplate(user, e.taleVars(gt, g.Meta.ID, g.Meta.LengthMin, gw, gp))},
			llm.Message{Role: "assistant", Content: strings.TrimSpace(string(b))})
	}
	if len(golds) == 0 {
		return "", nil, fmt.Errorf("no gold scripts in %s", goldDir)
	}
	words, pauses := e.targets(o.Length, golds)
	vars := e.taleVars(tale, o.Tale, o.Length, words, pauses)

	client, err := llm.FromEnv(time.Duration(e.Cfg.LLM.TimeoutS) * time.Second)
	if err != nil {
		return "", nil, err
	}
	client.MaxTokens = e.Cfg.LLM.MaxTokens
	msgs := append([]llm.Message{{Role: "system", Content: renderTemplate(sys, vars)}}, shots...)
	msgs = append(msgs, llm.Message{Role: "user", Content: renderTemplate(user, vars)})

	attempts := max(1, e.Cfg.LLM.Attempts)
	var text string
	var rep *judge.Report
	for a := 1; a <= attempts; a++ {
		e.Log.Printf("script: %s.%d attempt %d/%d (model %s)", o.Tale, o.Length, a, attempts, client.Model)
		resp, err := client.Chat(ctx, msgs, e.Cfg.LLM.Temperature)
		if err != nil {
			return "", nil, err
		}
		text = forceDraft(llm.StripFences(resp))
		rep = judge.Check(out, []byte(text), e.JudgeConfig(o.Length))
		if rep.OK {
			break
		}
		msgs = append(msgs, llm.Message{Role: "assistant", Content: resp},
			llm.Message{Role: "user", Content: "Skript neprošel automatickou kontrolou. Oprav tyto chyby a vrať celý opravený skript:\n- " +
				strings.Join(rep.Errors, "\n- ")})
	}
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
		return "", nil, err
	}
	if err := os.WriteFile(out, []byte(text), 0o644); err != nil {
		return "", nil, err
	}
	e.Log.Printf("script: wrote %s (status: draft)", out)
	rep, err = e.Judge(ctx, out, o.Length, true)
	return out, rep, err
}

var reStatus = regexp.MustCompile(`(?m)^status:.*$`)

// forceDraft makes sure generated scripts carry status: draft.
func forceDraft(s string) string {
	fm, body, err := splitFrontMatter(s)
	if err != nil {
		return s
	}
	if reStatus.MatchString(fm) {
		fm = reStatus.ReplaceAllString(fm, "status: draft")
	} else {
		fm = strings.TrimRight(fm, "\n") + "\nstatus: draft"
	}
	return "---\n" + fm + "\n---\n" + body
}

// Judge runs deterministic checks and (optionally) the LLM judge, writing a
// JSON report to work/_judge/. useLLM=false forces deterministic-only.
func (e *Env) Judge(ctx context.Context, file string, length int, useLLM bool) (*judge.Report, error) {
	src, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	rep := judge.Check(file, src, e.JudgeConfig(length))
	mode := e.Cfg.Judge.LLM
	if useLLM && (mode == "on" || (mode == "auto" && llm.Configured())) {
		checklist, err := os.ReadFile(e.contentPath(e.Cfg.LLM.JudgeChecklist))
		if err != nil {
			rep.Warnings = append(rep.Warnings, "LLM judge skipped: "+err.Error())
		} else if c, err := llm.FromEnv(time.Duration(e.Cfg.LLM.TimeoutS) * time.Second); err != nil {
			rep.Warnings = append(rep.Warnings, "LLM judge skipped: "+err.Error())
		} else {
			rep.LLM = judge.LLMJudge(ctx, c, string(checklist), string(src), e.Cfg.Judge.LLMMinScore)
			if rep.LLM.Error != "" {
				rep.Errors = append(rep.Errors, "llm judge: "+rep.LLM.Error)
			} else if !rep.LLM.Pass {
				rep.Errors = append(rep.Errors, fmt.Sprintf("llm judge failed: scores %v, blockers %v", rep.LLM.Scores, rep.LLM.Blockers))
			}
			rep.OK = len(rep.Errors) == 0
		}
	} else if useLLM && mode == "auto" {
		rep.Warnings = append(rep.Warnings, "LLM judge skipped: LLM_BASE_URL not set")
	}
	name := strings.TrimSuffix(filepath.Base(file), ".md") + ".json"
	if err := writeJSON(filepath.Join(e.Work, "_judge", name), rep); err != nil {
		return rep, err
	}
	return rep, nil
}
