// Package tts drives the python TTS worker (JSON lines over stdin/stdout).
package tts

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"sync"
)

type Request struct {
	Text     string  `json:"text"`
	Speed    float64 `json:"speed"`
	Style    string  `json:"style"`
	VoiceRef string  `json:"voice_ref"`
	OutPath  string  `json:"out_path"`
}

type Response struct {
	OK        bool    `json:"ok"`
	DurationS float64 `json:"duration_s"`
	// StyleApplied reports whether the engine rendered the style natively
	// (e.g. a whisper mode); otherwise the mixer applies the fallback.
	StyleApplied bool   `json:"style_applied"`
	Error        string `json:"error,omitempty"`
}

// Synthesizer abstracts the TTS backend (python worker in production, fakes in tests).
type Synthesizer interface {
	Synthesize(Request) (Response, error)
	Close() error
}

type Worker struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout *bufio.Reader
	mu     sync.Mutex
}

// Start launches `pythonCmd... script --engine engine`.
func Start(pythonCmd []string, script, engine string) (*Worker, error) {
	args := append(append([]string{}, pythonCmd[1:]...), script, "--engine", engine)
	cmd := exec.Command(pythonCmd[0], args...)
	cmd.Stderr = os.Stderr
	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start tts worker: %w", err)
	}
	return &Worker{cmd: cmd, stdin: in, stdout: bufio.NewReaderSize(out, 1<<16)}, nil
}

func (w *Worker) Synthesize(r Request) (Response, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	b, _ := json.Marshal(r)
	if _, err := w.stdin.Write(append(b, '\n')); err != nil {
		return Response{}, fmt.Errorf("tts worker write: %w", err)
	}
	line, err := w.stdout.ReadBytes('\n')
	if err != nil {
		return Response{}, fmt.Errorf("tts worker read: %w", err)
	}
	var resp Response
	if err := json.Unmarshal(line, &resp); err != nil {
		return Response{}, fmt.Errorf("tts worker bad response %q: %w", string(line), err)
	}
	if !resp.OK {
		return resp, fmt.Errorf("tts: %s", resp.Error)
	}
	return resp, nil
}

func (w *Worker) Close() error {
	closeErr := w.stdin.Close()
	return errors.Join(closeErr, w.cmd.Wait())
}

// CacheKey = sha256(engine, voice, text, speed, style).
func CacheKey(engine, voice, text string, speed float64, style string) string {
	h := sha256.New()
	for _, p := range []string{engine, voice, text, strconv.FormatFloat(speed, 'f', 4, 64), style} {
		h.Write([]byte(p))
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))
}
