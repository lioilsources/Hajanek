package httpapi

import (
	"bytes"
	"errors"
	"io"
	"math"
	"net/http"
	"os"
	"strconv"

	"github.com/lioilsources/hajanek/api/internal/catalog"
	"github.com/lioilsources/hajanek/api/internal/ids"
	"github.com/lioilsources/hajanek/api/internal/voices"
)

const (
	maxClipBytes = 2 << 20
	maxClipS     = 600.0
)

var sampleTypes = map[string]string{"wav": "audio/wav", "m4a": "audio/mp4", "mp3": "audio/mpeg"}

func (s *Server) workerSample(w http.ResponseWriter, r *http.Request) {
	path, ext, err := s.Voices.SampleFor(r.Context(), r.PathValue("id"))
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
	st, err := f.Stat()
	if err != nil {
		s.internal(w, r, err)
		return
	}
	w.Header().Set("Content-Type", sampleTypes[ext])
	w.Header().Set("Content-Disposition", `attachment; filename="sample.`+ext+`"`)
	http.ServeContent(w, r, "", st.ModTime(), f)
}

func (s *Server) workerScript(w http.ResponseWriter, r *http.Request) {
	tale := r.PathValue("tale")
	length, err := strconv.Atoi(r.PathValue("length"))
	if err != nil || length < 1 || !catalog.IsKebab(tale) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	body, ref, err := s.Catalog.Script(r.Context(), tale, length)
	if err != nil {
		s.scriptError(w, r, err)
		return
	}
	w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
	w.Header().Set("X-Script-SHA256", ref.SHA256)
	w.Header().Set("ETag", `"`+ref.SHA256+`"`)
	_, _ = w.Write(body)
}

func (s *Server) workerClipKeys(w http.ResponseWriter, r *http.Request) {
	keys, err := s.Voices.ClipKeys(r.Context(), r.PathValue("voice"))
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"keys": keys})
}

func (s *Server) workerPutClip(w http.ResponseWriter, r *http.Request) {
	voiceID, key := r.PathValue("voice"), r.PathValue("key")
	if !ids.IsUUID(voiceID) || !ids.IsHex64(key) {
		writeError(w, http.StatusBadRequest, "voice must be a UUID and key 64 lowercase hex chars")
		return
	}
	dur, err := strconv.ParseFloat(r.Header.Get("X-Duration-S"), 64)
	if err != nil || math.IsNaN(dur) || dur <= 0 || dur > maxClipS {
		writeError(w, http.StatusBadRequest, "X-Duration-S: required, seconds > 0")
		return
	}
	body := http.MaxBytesReader(w, r.Body, maxClipBytes)
	head := make([]byte, 8)
	if _, err := io.ReadFull(body, head); err != nil || !voices.IsMP4(head) {
		writeError(w, http.StatusUnsupportedMediaType, "body: must be an m4a (MP4/AAC) file")
		return
	}
	err = s.Voices.PutClip(r.Context(), voiceID, key, dur, io.MultiReader(bytes.NewReader(head), body))
	var mbe *http.MaxBytesError
	switch {
	case errors.As(err, &mbe):
		writeError(w, http.StatusRequestEntityTooLarge, "clip larger than 2 MB")
	case err != nil:
		s.voiceError(w, r, err)
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}

type voiceStatusRequest struct {
	Status voices.Status `json:"status"`
	Error  string        `json:"error"`
}

func (s *Server) workerVoiceStatus(w http.ResponseWriter, r *http.Request) {
	var req voiceStatusRequest
	if !decode(w, r, &req, false) {
		return
	}
	if req.Status != voices.StatusReady && req.Status != voices.StatusFailed {
		writeError(w, http.StatusBadRequest, "status: must be ready or failed")
		return
	}
	v, err := s.Voices.SetStatus(r.Context(), r.PathValue("id"), req.Status, req.Error)
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	s.Log.Info("voice status", "voice", v.ID, "status", v.Status, "error", v.Error)
	writeJSON(w, http.StatusOK, v)
}
