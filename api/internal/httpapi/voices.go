package httpapi

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/lioilsources/hajanek/api/internal/catalog"
	"github.com/lioilsources/hajanek/api/internal/script"
	"github.com/lioilsources/hajanek/api/internal/voices"
)

const (
	maxSampleBytes  = 5 << 20
	maxFieldBytes   = 4 << 10
	minSampleS      = 5.0
	maxSampleS      = 30.0
	sampleTolerance = 0.1 // encoder padding
	maxNameRunes    = 60
	maxConsentRunes = 2000
)

type voiceForm struct {
	name, consent, consentText string
	tmp                        string // staged sample
	size                       int64
	head                       []byte
}

// readVoiceForm streams the multipart body; the sample goes to a temp file.
func (s *Server) readVoiceForm(r *http.Request) (f voiceForm, status int, err error) {
	mr, err := r.MultipartReader()
	if err != nil {
		return f, http.StatusBadRequest, errors.New("expected multipart/form-data")
	}
	for {
		p, err := mr.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			return f, statusForBodyErr(err), fmt.Errorf("invalid multipart body: %w", err)
		}
		switch p.FormName() {
		case "sample":
			if f.tmp != "" {
				return f, http.StatusBadRequest, errors.New("sample: only one file allowed")
			}
			if status, err := s.stageSample(p, &f); err != nil {
				return f, status, err
			}
		case "name", "consent", "consent_text":
			b, err := io.ReadAll(io.LimitReader(p, maxFieldBytes+1))
			if err != nil {
				return f, statusForBodyErr(err), err
			}
			if len(b) > maxFieldBytes {
				return f, http.StatusBadRequest, fmt.Errorf("%s: too long", p.FormName())
			}
			v := strings.TrimSpace(string(b))
			switch p.FormName() {
			case "name":
				f.name = v
			case "consent":
				f.consent = v
			default:
				f.consentText = v
			}
		}
		_ = p.Close()
	}
	return f, 0, nil
}

func (s *Server) stageSample(p *multipart.Part, f *voiceForm) (int, error) {
	dir, err := s.Voices.TempDir()
	if err != nil {
		return http.StatusInternalServerError, err
	}
	tf, err := os.CreateTemp(dir, "sample-*")
	if err != nil {
		return http.StatusInternalServerError, err
	}
	f.tmp = tf.Name()
	var head bytes.Buffer
	n, err := io.Copy(tf, io.TeeReader(io.LimitReader(p, maxSampleBytes+1), &limitedBuffer{&head, 16}))
	if cerr := tf.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return statusForBodyErr(err), fmt.Errorf("sample: %w", err)
	}
	if n > maxSampleBytes {
		return http.StatusRequestEntityTooLarge, fmt.Errorf("sample: larger than %d bytes", maxSampleBytes)
	}
	f.size, f.head = n, head.Bytes()
	return 0, nil
}

// limitedBuffer keeps only the first max bytes written to it.
type limitedBuffer struct {
	b   *bytes.Buffer
	max int
}

func (l *limitedBuffer) Write(p []byte) (int, error) {
	if room := l.max - l.b.Len(); room > 0 {
		l.b.Write(p[:min(room, len(p))])
	}
	return len(p), nil
}

func statusForBodyErr(err error) int {
	var mbe *http.MaxBytesError
	if errors.As(err, &mbe) {
		return http.StatusRequestEntityTooLarge
	}
	return http.StatusBadRequest
}

func (s *Server) createVoice(w http.ResponseWriter, r *http.Request, deviceID string) {
	r.Body = http.MaxBytesReader(w, r.Body, maxSampleBytes+64<<10)
	f, status, err := s.readVoiceForm(r)
	if f.tmp != "" {
		defer func() { _ = os.Remove(f.tmp) }() // no-op once moved into place
	}
	if err != nil {
		if status == http.StatusInternalServerError {
			s.internal(w, r, err)
			return
		}
		writeError(w, status, err.Error())
		return
	}

	var problems []string
	if f.name == "" || utf8.RuneCountInString(f.name) > maxNameRunes {
		problems = append(problems, fmt.Sprintf("name: required, at most %d characters", maxNameRunes))
	}
	if f.consent != "true" {
		problems = append(problems, "consent: must be true")
	}
	if f.consentText == "" || utf8.RuneCountInString(f.consentText) > maxConsentRunes {
		problems = append(problems, fmt.Sprintf("consent_text: required, at most %d characters", maxConsentRunes))
	}
	if f.tmp == "" || f.size == 0 {
		problems = append(problems, "sample: required")
	}
	if len(problems) > 0 {
		writeError(w, http.StatusBadRequest, strings.Join(problems, "; "))
		return
	}
	ext, ok := voices.SniffAudio(f.head)
	if !ok {
		writeError(w, http.StatusUnsupportedMediaType, "sample: must be wav, m4a or mp3")
		return
	}

	nv := voices.NewVoice{Name: f.name, ConsentText: f.consentText, Ext: ext, SamplePath: f.tmp, SampleBytes: f.size}
	if s.Probe == nil {
		s.Log.Info("ffprobe unavailable, sample duration not checked", "device", deviceID)
	} else {
		d, ok, err := s.Probe(r.Context(), f.tmp)
		switch {
		case err != nil:
			writeError(w, http.StatusBadRequest, "sample: unreadable audio")
			return
		case ok && (d < minSampleS-sampleTolerance || d > maxSampleS+sampleTolerance):
			writeError(w, http.StatusBadRequest, fmt.Sprintf("sample: duration %.1f s, must be 5–30 s", d))
			return
		case ok:
			nv.DurationS = &d
		}
	}

	v, err := s.Voices.CreateVoice(r.Context(), deviceID, nv)
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	s.Log.Info("voice created", "voice", v.ID, "device", deviceID, "bytes", f.size, "ext", ext)
	w.Header().Set("Location", "/v1/voices/"+v.ID)
	writeJSON(w, http.StatusCreated, v)
}

func (s *Server) listVoices(w http.ResponseWriter, r *http.Request, deviceID string) {
	list, err := s.Voices.ListVoices(r.Context(), deviceID)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"voices": list})
}

func (s *Server) getVoice(w http.ResponseWriter, r *http.Request, deviceID string) {
	v, err := s.Voices.GetVoice(r.Context(), deviceID, r.PathValue("id"))
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, v)
}

func (s *Server) deleteVoice(w http.ResponseWriter, r *http.Request, deviceID string) {
	id := r.PathValue("id")
	if err := s.Voices.DeleteVoice(r.Context(), deviceID, id); err != nil {
		s.voiceError(w, r, err)
		return
	}
	s.Log.Info("voice deletion started", "voice", id, "device", deviceID)
	w.WriteHeader(http.StatusNoContent)
}

type renderRequest struct {
	Tale      string `json:"tale"`
	LengthMin int    `json:"length_min"`
}

// scriptKeys loads the current script of tale/length and its utterance keys.
func (s *Server) scriptKeys(w http.ResponseWriter, r *http.Request, voiceID, tale string, length int) (string, []string, bool) {
	body, ref, err := s.Catalog.Script(r.Context(), tale, length)
	if err != nil {
		s.scriptError(w, r, err)
		return "", nil, false
	}
	sc, err := script.Parse(body)
	if err != nil {
		s.Log.Error("published script does not parse", "tale", tale, "length", length, "sha256", ref.SHA256, "err", err)
		writeError(w, http.StatusBadGateway, "script cannot be parsed")
		return "", nil, false
	}
	return ref.SHA256, sc.Keys(voiceID), true
}

func (s *Server) scriptError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, catalog.ErrNoCatalog):
		writeError(w, http.StatusServiceUnavailable, err.Error())
	case errors.Is(err, catalog.ErrNoScript):
		writeError(w, http.StatusNotFound, "tale/length not in catalog")
	default:
		s.Log.Error("script fetch failed", "path", r.URL.Path, "err", err)
		writeError(w, http.StatusBadGateway, "script not available")
	}
}

func (s *Server) createRender(w http.ResponseWriter, r *http.Request, deviceID string) {
	voiceID := r.PathValue("id")
	var req renderRequest
	if !decode(w, r, &req, false) {
		return
	}
	if !catalog.IsKebab(req.Tale) || req.LengthMin < 1 {
		writeError(w, http.StatusBadRequest, "tale and length_min are required")
		return
	}
	// Ownership first: a foreign voice is a 404 whatever the tale.
	if _, err := s.Voices.GetVoice(r.Context(), deviceID, voiceID); err != nil {
		s.voiceError(w, r, err)
		return
	}
	sha, keys, ok := s.scriptKeys(w, r, voiceID, req.Tale, req.LengthMin)
	if !ok {
		return
	}
	rd, err := s.Voices.RequestRender(r.Context(), deviceID, voiceID, req.Tale, req.LengthMin, sha, keys)
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusAccepted, rd)
}

func (s *Server) getRender(w http.ResponseWriter, r *http.Request, deviceID string) {
	voiceID, tale := r.PathValue("id"), r.PathValue("tale")
	length, err := strconv.Atoi(r.PathValue("length"))
	if err != nil || length < 1 || !catalog.IsKebab(tale) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	if _, err := s.Voices.GetVoice(r.Context(), deviceID, voiceID); err != nil {
		s.voiceError(w, r, err)
		return
	}
	sha, keys, ok := s.scriptKeys(w, r, voiceID, tale, length)
	if !ok {
		return
	}
	m, err := s.Voices.Manifest(r.Context(), deviceID, voiceID, tale, length, sha, keys)
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, m)
}

func (s *Server) getClip(w http.ResponseWriter, r *http.Request, deviceID string) {
	key, ok := strings.CutSuffix(r.PathValue("file"), ".m4a")
	if !ok {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	c, path, err := s.Voices.OwnedClip(r.Context(), deviceID, r.PathValue("voice"), key)
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	f, err := os.Open(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
		s.internal(w, r, err)
		return
	}
	defer func() { _ = f.Close() }()
	// A key names its content (voice, tone, text), so clips never change.
	w.Header().Set("Cache-Control", "private, max-age=31536000, immutable")
	w.Header().Set("Content-Type", "audio/mp4")
	w.Header().Set("ETag", `"`+key+`"`)
	http.ServeContent(w, r, "", c.CreatedAt, f)
}
