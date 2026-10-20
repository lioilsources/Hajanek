// Package wavio reads and writes 16-bit PCM mono WAV files.
package wavio

import (
	"bufio"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
)

type PCM struct {
	SampleRate int
	Samples    []int16
}

func (p *PCM) Duration() float64 { return float64(len(p.Samples)) / float64(p.SampleRate) }

// Read reads a mono s16le WAV (as produced by `ffmpeg -c:a pcm_s16le -ac 1`).
func Read(path string) (*PCM, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(b) < 12 || string(b[0:4]) != "RIFF" || string(b[8:12]) != "WAVE" {
		return nil, fmt.Errorf("%s: not a WAV file", path)
	}
	p := &PCM{}
	var channels, bits int
	off := 12
	for off+8 <= len(b) {
		id := string(b[off : off+4])
		size := int(binary.LittleEndian.Uint32(b[off+4 : off+8]))
		body := off + 8
		end := body + size
		if end > len(b) {
			end = len(b)
		}
		switch id {
		case "fmt ":
			format := binary.LittleEndian.Uint16(b[body:])
			channels = int(binary.LittleEndian.Uint16(b[body+2:]))
			p.SampleRate = int(binary.LittleEndian.Uint32(b[body+4:]))
			bits = int(binary.LittleEndian.Uint16(b[body+14:]))
			if (format != 1 && format != 0xFFFE) || bits != 16 || channels != 1 {
				return nil, fmt.Errorf("%s: need PCM s16 mono (format=%d bits=%d ch=%d)", path, format, bits, channels)
			}
		case "data":
			if channels == 0 {
				return nil, errors.New("data before fmt chunk")
			}
			n := (end - body) / 2
			p.Samples = make([]int16, n)
			for i := 0; i < n; i++ {
				p.Samples[i] = int16(binary.LittleEndian.Uint16(b[body+2*i:]))
			}
			return p, nil
		}
		off = body + size + size%2
	}
	return nil, fmt.Errorf("%s: no data chunk", path)
}

// Writer streams samples into a WAV file; the header is patched on Close.
type Writer struct {
	f    *os.File
	w    *bufio.Writer
	rate int
	n    int64
}

func Create(path string, rate int) (*Writer, error) {
	f, err := os.Create(path)
	if err != nil {
		return nil, err
	}
	w := &Writer{f: f, w: bufio.NewWriterSize(f, 1<<16), rate: rate}
	if err := w.header(0); err != nil {
		_ = f.Close()
		return nil, err
	}
	return w, nil
}

func (w *Writer) header(dataBytes int64) error {
	h := make([]byte, 44)
	copy(h[0:], "RIFF")
	binary.LittleEndian.PutUint32(h[4:], uint32(36+dataBytes))
	copy(h[8:], "WAVEfmt ")
	binary.LittleEndian.PutUint32(h[16:], 16)
	binary.LittleEndian.PutUint16(h[20:], 1)
	binary.LittleEndian.PutUint16(h[22:], 1)
	binary.LittleEndian.PutUint32(h[24:], uint32(w.rate))
	binary.LittleEndian.PutUint32(h[28:], uint32(w.rate*2))
	binary.LittleEndian.PutUint16(h[32:], 2)
	binary.LittleEndian.PutUint16(h[34:], 16)
	copy(h[36:], "data")
	binary.LittleEndian.PutUint32(h[40:], uint32(dataBytes))
	_, err := w.f.WriteAt(h, 0)
	if err == nil {
		_, err = w.f.Seek(44, io.SeekStart)
	}
	return err
}

func (w *Writer) Write(s []int16) error {
	buf := make([]byte, 2*len(s))
	for i, v := range s {
		binary.LittleEndian.PutUint16(buf[2*i:], uint16(v))
	}
	_, err := w.w.Write(buf)
	w.n += int64(len(s))
	return err
}

func (w *Writer) Silence(seconds float64) error {
	n := int(seconds*float64(w.rate) + 0.5)
	return w.Write(make([]int16, n))
}

// Samples written so far.
func (w *Writer) Samples() int64 { return w.n }

func (w *Writer) Close() error {
	if err := w.w.Flush(); err != nil {
		_ = w.f.Close()
		return err
	}
	if err := w.header(w.n * 2); err != nil {
		_ = w.f.Close()
		return err
	}
	return w.f.Close()
}
