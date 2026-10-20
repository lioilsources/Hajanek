package judge

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/lioilsources/hajanek/forge/internal/llm"
)

type LLMResult struct {
	Scores      map[string]float64 `json:"scores"`
	Blockers    []string           `json:"blockers"`
	Suggestions []string           `json:"suggestions"`
	Pass        bool               `json:"pass"`
	Error       string             `json:"error,omitempty"`
}

type Chatter interface {
	Chat(ctx context.Context, msgs []llm.Message, temperature float64) (string, error)
}

var reComment = regexp.MustCompile(`(?s)<!--.*?-->`)

// PromptSections splits a prompt file into "## NAME" sections (comments removed).
// Text before the first heading is returned under "".
func PromptSections(src string) map[string]string {
	src = reComment.ReplaceAllString(src, "")
	out := map[string]string{}
	cur := ""
	var b strings.Builder
	flush := func() { out[cur] = strings.TrimSpace(b.String()); b.Reset() }
	for _, line := range strings.Split(src, "\n") {
		if strings.HasPrefix(line, "## ") {
			flush()
			cur = strings.TrimSpace(strings.TrimPrefix(line, "## "))
			continue
		}
		b.WriteString(line)
		b.WriteByte('\n')
	}
	flush()
	return out
}

// LLMJudge scores the script with the checklist (SYSTEM section = system prompt,
// user message = script). Fails if any score < minScore or blockers are present.
func LLMJudge(ctx context.Context, c Chatter, checklist, scriptSrc string, minScore float64) *LLMResult {
	secs := PromptSections(checklist)
	sys := secs["SYSTEM"]
	if sys == "" {
		sys = strings.TrimSpace(reComment.ReplaceAllString(checklist, ""))
	}
	res := &LLMResult{}
	out, err := c.Chat(ctx, []llm.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: scriptSrc},
	}, 0)
	if err != nil {
		res.Error = err.Error()
		return res
	}
	js, err := llm.ExtractJSON(out)
	if err == nil {
		err = json.Unmarshal([]byte(js), res)
	}
	if err != nil {
		res.Error = fmt.Sprintf("unparseable judge output: %v", err)
		return res
	}
	res.Pass = len(res.Blockers) == 0 && len(res.Scores) > 0
	for _, v := range res.Scores {
		if v < minScore {
			res.Pass = false
		}
	}
	return res
}
