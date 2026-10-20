package voices

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// Prober returns the duration of an audio file in seconds. ok is false when
// the duration cannot be determined because no prober is available.
type Prober func(ctx context.Context, path string) (seconds float64, ok bool, err error)

// FFProbe returns a Prober backed by ffprobe, or nil when ffprobe is not
// on PATH (the distroless image has none; samples are then accepted
// unchecked and the worker/audio service validates them).
func FFProbe() Prober {
	bin, err := exec.LookPath("ffprobe")
	if err != nil {
		return nil
	}
	return func(ctx context.Context, path string) (float64, bool, error) {
		ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
		defer cancel()
		out, err := exec.CommandContext(ctx, bin, "-v", "error", "-show_entries", "format=duration",
			"-of", "default=noprint_wrappers=1:nokey=1", path).Output()
		if err != nil {
			return 0, true, fmt.Errorf("ffprobe: unreadable audio")
		}
		d, err := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
		if err != nil {
			return 0, true, fmt.Errorf("ffprobe: no duration")
		}
		return d, true, nil
	}
}

// SniffAudio returns the sample extension (wav, m4a, mp3) from magic bytes.
func SniffAudio(head []byte) (string, bool) {
	switch {
	case len(head) >= 12 && string(head[0:4]) == "RIFF" && string(head[8:12]) == "WAVE":
		return "wav", true
	case IsMP4(head):
		return "m4a", true
	case len(head) >= 3 && string(head[0:3]) == "ID3",
		len(head) >= 2 && head[0] == 0xFF && head[1]&0xE0 == 0xE0:
		return "mp3", true
	}
	return "", false
}

// IsMP4 reports whether head starts an ISO BMFF (m4a/mp4) file.
func IsMP4(head []byte) bool { return len(head) >= 8 && string(head[4:8]) == "ftyp" }
