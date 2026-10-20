// Package httpapi exposes the HTTP API described in CONTRACTS.md §6.
package httpapi

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/lioilsources/hajanek/api/internal/catalog"
	"github.com/lioilsources/hajanek/api/internal/jobs"
	"github.com/lioilsources/hajanek/api/internal/voices"
)

const maxBodyBytes = 1 << 20

type Server struct {
	DB          *sql.DB
	Catalog     *catalog.Service
	Jobs        *jobs.Store
	AdminToken  string
	WorkerToken string
	Log         *slog.Logger

	Voices        *voices.Store
	Probe         voices.Prober // nil: sample duration is not checked
	DeviceLimiter *RateLimiter  // nil: no limit on POST /v1/devices
}

// Handler returns the routed, logged HTTP handler.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.healthz)
	mux.HandleFunc("GET /v1/catalog", s.getCatalog)
	mux.HandleFunc("GET /v1/catalog/version", s.getCatalogVersion)

	admin := s.auth(s.AdminToken)
	worker := s.auth(s.WorkerToken)
	either := s.auth(s.AdminToken, s.WorkerToken)

	mux.Handle("POST /v1/jobs", admin(s.createJob))
	mux.Handle("GET /v1/jobs", either(s.listJobs))
	mux.Handle("GET /v1/jobs/{id}", either(s.getJob))
	mux.Handle("POST /v1/jobs/claim", worker(s.claimJob))
	mux.Handle("POST /v1/jobs/{id}/heartbeat", worker(s.heartbeat))
	mux.Handle("POST /v1/jobs/{id}/complete", worker(s.completeJob))

	mux.HandleFunc("POST /v1/devices", s.registerDevice)
	mux.Handle("DELETE /v1/devices/me", s.device(s.deleteDevice))
	mux.Handle("POST /v1/voices", s.device(s.createVoice))
	mux.Handle("GET /v1/voices", s.device(s.listVoices))
	mux.Handle("GET /v1/voices/{id}", s.device(s.getVoice))
	mux.Handle("DELETE /v1/voices/{id}", s.device(s.deleteVoice))
	mux.Handle("POST /v1/voices/{id}/renders", s.device(s.createRender))
	mux.Handle("GET /v1/voices/{id}/renders/{tale}/{length}", s.device(s.getRender))
	mux.Handle("GET /v1/clips/{voice}/{file}", s.device(s.getClip))

	mux.Handle("GET /v1/worker/voices/{id}/sample", worker(s.workerSample))
	mux.Handle("POST /v1/worker/voices/{id}/status", worker(s.workerVoiceStatus))
	mux.Handle("GET /v1/worker/scripts/{tale}/{length}", worker(s.workerScript))
	mux.Handle("GET /v1/worker/clips/{voice}", worker(s.workerClipKeys))
	mux.Handle("PUT /v1/worker/clips/{voice}/{key}", worker(s.workerPutClip))

	return s.logRequests(mux)
}

func (s *Server) healthz(w http.ResponseWriter, r *http.Request) {
	if s.DB != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := s.DB.PingContext(ctx); err != nil {
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{"ok": false, "error": "database unavailable"})
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *Server) getCatalog(w http.ResponseWriter, r *http.Request) {
	if r.URL.Query().Get("inline") != "1" {
		w.Header().Set("Cache-Control", "public, max-age=60")
		http.Redirect(w, r, s.Catalog.URL(), http.StatusFound)
		return
	}
	snap, ok := s.Catalog.Current()
	if !ok {
		writeError(w, http.StatusServiceUnavailable, "catalog not available yet")
		return
	}
	etag := `"` + snap.SHA256 + `"`
	w.Header().Set("ETag", etag)
	w.Header().Set("Cache-Control", "public, max-age=60")
	if match := r.Header.Get("If-None-Match"); match != "" && strings.Contains(match, etag) {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Last-Modified", snap.UpdatedAt.Format(http.TimeFormat))
	_, _ = w.Write(snap.Body)
}

func (s *Server) getCatalogVersion(w http.ResponseWriter, r *http.Request) {
	snap, ok := s.Catalog.Current()
	if !ok {
		writeError(w, http.StatusServiceUnavailable, "catalog not available yet")
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=60")
	writeJSON(w, http.StatusOK, map[string]any{"version": snap.Version, "url": s.Catalog.URL()})
}

func (s *Server) createJob(w http.ResponseWriter, r *http.Request) {
	var spec jobs.Spec
	if !decode(w, r, &spec, false) {
		return
	}
	job, created, err := s.Jobs.Enqueue(r.Context(), spec)
	if err != nil {
		var verr *jobs.ValidationError
		if errors.As(err, &verr) {
			writeError(w, http.StatusBadRequest, verr.Error())
			return
		}
		s.internal(w, r, err)
		return
	}
	status := http.StatusCreated
	if !created {
		status = http.StatusOK
		w.Header().Set("X-Deduplicated", "true")
	} else {
		s.Log.Info("job enqueued", "id", job.ID, "kind", job.Kind, "tale", job.Tale, "voice", job.Voice+job.VoiceID)
	}
	w.Header().Set("Location", "/v1/jobs/"+job.ID)
	writeJSON(w, status, job)
}

func (s *Server) listJobs(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if status != "" && !jobs.ValidStatus(status) {
		writeError(w, http.StatusBadRequest, "status: must be one of queued, running, done, failed")
		return
	}
	list, err := s.Jobs.List(r.Context(), jobs.Status(status), 100)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"jobs": list})
}

func (s *Server) getJob(w http.ResponseWriter, r *http.Request) {
	job, err := s.Jobs.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		s.jobError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, job)
}

type claimRequest struct {
	Worker string      `json:"worker"`
	Kinds  []jobs.Kind `json:"kinds"`
}

func (s *Server) claimJob(w http.ResponseWriter, r *http.Request) {
	var req claimRequest
	if !decode(w, r, &req, true) {
		return
	}
	for _, k := range req.Kinds {
		if !slices.Contains(jobs.Kinds, k) {
			writeError(w, http.StatusBadRequest, "kinds: unknown kind "+strconv.Quote(string(k)))
			return
		}
	}
	job, ok, err := s.Jobs.Claim(r.Context(), workerName(req.Worker), req.Kinds)
	if err != nil {
		s.internal(w, r, err)
		return
	}
	if !ok {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	s.Log.Info("job claimed", "id", job.ID, "kind", job.Kind, "worker", job.Worker, "attempt", job.Attempts)
	writeJSON(w, http.StatusOK, job)
}

type heartbeatRequest struct {
	Worker string `json:"worker"`
}

func (s *Server) heartbeat(w http.ResponseWriter, r *http.Request) {
	var req heartbeatRequest
	if !decode(w, r, &req, true) {
		return
	}
	job, err := s.Jobs.Heartbeat(r.Context(), r.PathValue("id"), workerName(req.Worker))
	if err != nil {
		s.jobError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, job)
}

type completeRequest struct {
	Worker string          `json:"worker"`
	OK     *bool           `json:"ok"`
	Result json.RawMessage `json:"result"`
	Error  string          `json:"error"`
	Retry  bool            `json:"retry"`
}

func (s *Server) completeJob(w http.ResponseWriter, r *http.Request) {
	var req completeRequest
	if !decode(w, r, &req, false) {
		return
	}
	if req.OK == nil {
		writeError(w, http.StatusBadRequest, "ok: required")
		return
	}
	if !*req.OK && strings.TrimSpace(req.Error) == "" {
		writeError(w, http.StatusBadRequest, "error: required when ok is false")
		return
	}
	if string(req.Result) == "null" {
		req.Result = nil
	}
	job, err := s.Jobs.Complete(r.Context(), r.PathValue("id"), workerName(req.Worker), jobs.Completion{
		OK: *req.OK, Result: req.Result, Error: req.Error, Retry: req.Retry,
	})
	if err != nil {
		s.jobError(w, r, err)
		return
	}
	s.Log.Info("job completed", "id", job.ID, "status", job.Status, "worker", job.Worker, "error", job.Error)
	writeJSON(w, http.StatusOK, job)
}

func (s *Server) jobError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, jobs.ErrNotFound):
		writeError(w, http.StatusNotFound, err.Error())
	case errors.Is(err, jobs.ErrNotLeased):
		writeError(w, http.StatusConflict, err.Error())
	default:
		s.internal(w, r, err)
	}
}

func (s *Server) internal(w http.ResponseWriter, r *http.Request, err error) {
	s.Log.Error("request failed", "method", r.Method, "path", r.URL.Path, "err", err)
	writeError(w, http.StatusInternalServerError, "internal error")
}

func workerName(s string) string {
	if s = strings.TrimSpace(s); s == "" {
		return "default"
	}
	return s
}

// auth accepts a request bearing any of the given tokens.
func (s *Server) auth(tokens ...string) func(http.HandlerFunc) http.Handler {
	return func(next http.HandlerFunc) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			got, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
			if ok && got != "" {
				for _, t := range tokens {
					if t != "" && subtle.ConstantTimeCompare([]byte(got), []byte(t)) == 1 {
						next(w, r)
						return
					}
				}
			}
			w.Header().Set("WWW-Authenticate", `Bearer realm="hajanek"`)
			writeError(w, http.StatusUnauthorized, "unauthorized")
		})
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (s *Server) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		if r.URL.Path == "/healthz" && rec.status == http.StatusOK {
			return
		}
		s.Log.Info("http", "method", r.Method, "path", r.URL.Path, "status", rec.status,
			"dur_ms", time.Since(start).Milliseconds())
	})
}

// decode reads a JSON body into v. With allowEmpty, an empty body is fine.
func decode(w http.ResponseWriter, r *http.Request, v any, allowEmpty bool) bool {
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		if allowEmpty && errors.Is(err, io.EOF) {
			return true
		}
		writeError(w, http.StatusBadRequest, "invalid JSON body: "+err.Error())
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
