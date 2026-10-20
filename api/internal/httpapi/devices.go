package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/lioilsources/hajanek/api/internal/voices"
)

type deviceHandler func(w http.ResponseWriter, r *http.Request, deviceID string)

// device authenticates `Authorization: Bearer <device token>`.
func (s *Server) device(next deviceHandler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if ok && token != "" {
			id, err := s.Voices.DeviceByToken(r.Context(), token)
			switch {
			case err == nil:
				next(w, r, id)
				return
			case !errors.Is(err, voices.ErrNotFound):
				s.internal(w, r, err)
				return
			}
		}
		w.Header().Set("WWW-Authenticate", `Bearer realm="hajanek"`)
		writeError(w, http.StatusUnauthorized, "unauthorized")
	})
}

func (s *Server) registerDevice(w http.ResponseWriter, r *http.Request) {
	if !s.DeviceLimiter.Allow(clientIP(r)) {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "too many registrations, try later")
		return
	}
	id, token, err := s.Voices.RegisterDevice(r.Context())
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"device_id": id, "token": token})
}

func (s *Server) deleteDevice(w http.ResponseWriter, r *http.Request, deviceID string) {
	if err := s.Voices.DeleteDevice(r.Context(), deviceID); err != nil {
		s.internal(w, r, err)
		return
	}
	s.Log.Info("device deleted", "device", deviceID)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) voiceError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, voices.ErrNotFound):
		writeError(w, http.StatusNotFound, "not found")
	case errors.Is(err, voices.ErrLimit), errors.Is(err, voices.ErrNotReady), errors.Is(err, voices.ErrDeleting):
		writeError(w, http.StatusConflict, err.Error())
	default:
		s.internal(w, r, err)
	}
}
