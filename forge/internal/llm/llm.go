// Package llm is a minimal OpenAI-compatible chat completions client (LiteLLM on Spark).
package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type Client struct {
	BaseURL     string
	APIKey      string
	Model       string
	Temperature float64
	MaxTokens   int
	HTTP        *http.Client
}

// FromEnv builds a client from LLM_BASE_URL, LLM_API_KEY, LLM_MODEL.
func FromEnv(timeout time.Duration) (*Client, error) {
	base := os.Getenv("LLM_BASE_URL")
	if base == "" {
		return nil, errors.New("LLM_BASE_URL not set")
	}
	return &Client{
		BaseURL: base, APIKey: os.Getenv("LLM_API_KEY"), Model: os.Getenv("LLM_MODEL"),
		Temperature: 0.7, MaxTokens: 8000, HTTP: &http.Client{Timeout: timeout},
	}, nil
}

func Configured() bool { return os.Getenv("LLM_BASE_URL") != "" }

type chatReq struct {
	Model       string    `json:"model,omitempty"`
	Messages    []Message `json:"messages"`
	Temperature float64   `json:"temperature"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
}

type chatResp struct {
	Choices []struct {
		Message Message `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

// Chat sends messages and returns the first choice content.
func (c *Client) Chat(ctx context.Context, msgs []Message, temperature float64) (string, error) {
	body, _ := json.Marshal(chatReq{Model: c.Model, Messages: msgs, Temperature: temperature, MaxTokens: c.MaxTokens})
	url := strings.TrimRight(c.BaseURL, "/")
	if !strings.HasSuffix(url, "/v1") {
		url += "/v1"
	}
	url += "/chat/completions"
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt*attempt) * 2 * time.Second)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Type", "application/json")
		if c.APIKey != "" {
			req.Header.Set("Authorization", "Bearer "+c.APIKey)
		}
		hc := c.HTTP
		if hc == nil {
			hc = http.DefaultClient
		}
		resp, err := hc.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		b, _ := io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		if resp.StatusCode >= 500 || resp.StatusCode == 429 {
			lastErr = fmt.Errorf("llm: HTTP %d: %s", resp.StatusCode, truncate(string(b), 300))
			continue
		}
		if resp.StatusCode != 200 {
			return "", fmt.Errorf("llm: HTTP %d: %s", resp.StatusCode, truncate(string(b), 300))
		}
		var cr chatResp
		if err := json.Unmarshal(b, &cr); err != nil {
			return "", fmt.Errorf("llm: bad response: %w", err)
		}
		if cr.Error != nil {
			return "", fmt.Errorf("llm: %s", cr.Error.Message)
		}
		if len(cr.Choices) == 0 {
			return "", errors.New("llm: no choices")
		}
		return StripThinking(cr.Choices[0].Message.Content), nil
	}
	return "", lastErr
}

// StripThinking removes <think>…</think> blocks some reasoning models emit.
func StripThinking(s string) string {
	for {
		i := strings.Index(s, "<think>")
		if i < 0 {
			break
		}
		j := strings.Index(s[i:], "</think>")
		if j < 0 {
			s = s[:i]
			break
		}
		s = s[:i] + s[i+j+len("</think>"):]
	}
	return strings.TrimSpace(s)
}

// ExtractJSON returns the outermost {...} object in s.
func ExtractJSON(s string) (string, error) {
	i := strings.Index(s, "{")
	j := strings.LastIndex(s, "}")
	if i < 0 || j < i {
		return "", errors.New("no JSON object in response")
	}
	return s[i : j+1], nil
}

// StripFences removes a surrounding ```markdown fence if present.
func StripFences(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```") {
		if nl := strings.Index(s, "\n"); nl >= 0 {
			s = s[nl+1:]
		}
		s = strings.TrimSuffix(strings.TrimSpace(s), "```")
	}
	return strings.TrimSpace(s) + "\n"
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n] + "…"
	}
	return s
}
