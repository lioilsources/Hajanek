package llm

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestChatRetriesAndStrips(t *testing.T) {
	n := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n++
		if n == 1 {
			http.Error(w, "busy", http.StatusServiceUnavailable)
			return
		}
		if _, err := w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"<think>x</think>\n ahoj "}}]}`)); err != nil {
			t.Error(err)
		}
	}))
	defer srv.Close()
	c := &Client{BaseURL: srv.URL + "/v1/", Model: "m"}
	out, err := c.Chat(context.Background(), []Message{{Role: "user", Content: "hi"}}, 0)
	if err != nil || out != "ahoj" || n != 2 {
		t.Fatalf("out=%q err=%v calls=%d", out, err, n)
	}
}

func TestHelpers(t *testing.T) {
	if s := StripFences("```markdown\n---\nid: a\n---\n```"); s != "---\nid: a\n---\n" {
		t.Errorf("StripFences = %q", s)
	}
	if j, err := ExtractJSON("text {\"a\": {\"b\": 1}} tail"); err != nil || j != `{"a": {"b": 1}}` {
		t.Errorf("ExtractJSON = %q %v", j, err)
	}
}
