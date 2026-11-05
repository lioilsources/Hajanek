package httpapi

import (
	"errors"
	"net/http"

	"github.com/lioilsources/hajanek/api/internal/voices"
)

// createPairing issues a pairing code for the calling device (the TV).
func (s *Server) createPairing(w http.ResponseWriter, r *http.Request, deviceID string) {
	if !s.PairingLimiter.Allow(clientIP(r)) {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "too many pairing codes, try later")
		return
	}
	p, err := s.Voices.CreatePairing(r.Context(), deviceID)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"code": p.Code, "expires_at": p.ExpiresAt})
}

// getPairing lets the TV that created the code poll for the claim.
func (s *Server) getPairing(w http.ResponseWriter, r *http.Request, deviceID string) {
	p, err := s.Voices.PairingStatusFor(r.Context(), deviceID, r.PathValue("code"))
	if err != nil {
		s.voiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": p.Status, "expires_at": p.ExpiresAt})
}

// claimPairing (the phone) moves the code's owner into the caller's household.
func (s *Server) claimPairing(w http.ResponseWriter, r *http.Request, deviceID string) {
	if !s.ClaimLimiter.Allow(clientIP(r)) {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "too many attempts, try later")
		return
	}
	err := s.Voices.ClaimPairing(r.Context(), deviceID, r.PathValue("code"))
	switch {
	case err == nil:
		s.Log.Info("device paired", "claimer", deviceID)
		writeJSON(w, http.StatusOK, map[string]any{"status": voices.PairingClaimed})
	case errors.Is(err, voices.ErrSelfClaim):
		writeError(w, http.StatusConflict, err.Error())
	default:
		s.voiceError(w, r, err)
	}
}
