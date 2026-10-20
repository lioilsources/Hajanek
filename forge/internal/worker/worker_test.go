package worker

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"

	"github.com/lioilsources/hajanek/forge/internal/config"
	"github.com/lioilsources/hajanek/forge/internal/jobs"
	"github.com/lioilsources/hajanek/forge/internal/script"
)

const voice = "3f2c0a9e-1b2c-4d5e-8f90-123456789abc"

// Two "Spinkej." lines in the same tone share one clip.
const testScript = `---
id: test
title: Test
status: gold
length_min: 1
---
## uvod
[soft] Lehni si, {{osloveni|broučku}}.
[pause 2s]
## vstup
[slow] Spinkej.
## pribeh
[slow] Spinkej.
## dojezd
[whisper] Dobrou noc.
[pause 5s]
`

type fakeAPI struct {
	mu        sync.Mutex
	queue     []string // job JSON returned by claim, then 204
	existing  []string
	completes []map[string]any
	statuses  []map[string]string
	puts      map[string]string // key → X-Duration-S
	heartbeat int
	sample    []byte
}

func (f *fakeAPI) handler(t *testing.T) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		if r.Header.Get("Authorization") != "Bearer wt" {
			w.WriteHeader(401)
			return
		}
		p := r.URL.Path
		switch {
		case p == "/v1/jobs/claim":
			var body struct {
				Kinds []string `json:"kinds"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			if strings.Join(body.Kinds, ",") != "voice_create,voice_delete,render" {
				t.Errorf("claim kinds %v", body.Kinds)
			}
			if len(f.queue) == 0 {
				w.WriteHeader(204)
				return
			}
			_, _ = io.WriteString(w, f.queue[0])
			f.queue = f.queue[1:]
		case strings.HasSuffix(p, "/heartbeat"):
			f.heartbeat++
		case strings.HasSuffix(p, "/complete"):
			var m map[string]any
			_ = json.NewDecoder(r.Body).Decode(&m)
			f.completes = append(f.completes, m)
		case p == "/v1/worker/voices/"+voice+"/sample":
			w.Header().Set("Content-Type", "audio/wav")
			_, _ = w.Write(f.sample)
		case p == "/v1/worker/voices/"+voice+"/status":
			var m map[string]string
			_ = json.NewDecoder(r.Body).Decode(&m)
			f.statuses = append(f.statuses, m)
		case p == "/v1/worker/scripts/test/1":
			w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
			_, _ = io.WriteString(w, testScript)
		case p == "/v1/worker/clips/"+voice && r.Method == http.MethodGet:
			_ = json.NewEncoder(w).Encode(map[string]any{"keys": f.existing})
		case strings.HasPrefix(p, "/v1/worker/clips/"+voice+"/") && r.Method == http.MethodPut:
			b, _ := io.ReadAll(r.Body)
			if string(b) != "m4a" || r.Header.Get("Content-Type") != "audio/mp4" {
				t.Errorf("clip upload body %q type %q", b, r.Header.Get("Content-Type"))
			}
			f.puts[p[strings.LastIndex(p, "/")+1:]] = r.Header.Get("X-Duration-S")
		default:
			t.Errorf("api: unexpected %s %s", r.Method, p)
			w.WriteHeader(404)
		}
	})
}

type fakeAudio struct {
	mu      sync.Mutex
	ttsCode int // 0 = 202
	tts     []TTSRequest
	polls   int
	voices  map[string]string // voice_id → form summary
	deleted []string
	failJob bool
}

func (f *fakeAudio) handler(t *testing.T) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		p := r.URL.Path
		switch {
		case p == "/v1/audio/tts" && r.Method == http.MethodPost:
			var req TTSRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				t.Error(err)
			}
			switch f.ttsCode {
			case 503:
				w.WriteHeader(503)
				_, _ = io.WriteString(w, `{"detail":"TTS engine chatterbox teď neběží"}`)
				return
			case 403:
				w.WriteHeader(403)
				_, _ = io.WriteString(w, `{"detail":"model xtts-v2 je nekomerční"}`)
				return
			}
			f.tts = append(f.tts, req)
			w.WriteHeader(202)
			_ = json.NewEncoder(w).Encode(JobAccepted{JobID: "job" + string(rune('0'+len(f.tts))), Status: "queued"})
		case strings.HasPrefix(p, "/v1/audio/jobs/") && strings.Contains(p, "/outputs/"):
			_, _ = io.WriteString(w, "RIFFwav")
		case strings.HasPrefix(p, "/v1/audio/jobs/"):
			id := strings.TrimPrefix(p, "/v1/audio/jobs/")
			f.polls++
			st := JobStatus{JobID: id, Kind: "tts", Status: "running"}
			if f.polls%2 == 0 {
				st.Status = "done"
				st.Outputs = []Output{{URL: "/v1/audio/jobs/" + id + "/outputs/tts_0.wav", Filename: "tts_0.wav", Duration: 1.2}}
				if f.failJob {
					st = JobStatus{JobID: id, Kind: "tts", Status: "error", Error: "CUDA out of memory"}
				}
			}
			_ = json.NewEncoder(w).Encode(st)
		case p == "/v1/audio/voices" && r.Method == http.MethodPost:
			if err := r.ParseMultipartForm(1 << 20); err != nil {
				t.Error(err)
			}
			file, hdr, err := r.FormFile("sample")
			if err != nil {
				t.Error(err)
				return
			}
			b, _ := io.ReadAll(file)
			v := r.FormValue
			f.voices[v("voice_id")] = strings.Join([]string{v("rights"), v("source"), v("language"), v("replace"), hdr.Filename, string(b)}, "|")
			if string(b) == "short" {
				w.WriteHeader(422)
				_, _ = io.WriteString(w, `{"detail":"vzorek má po ořezu ticha jen 1.0 s"}`)
				return
			}
			w.WriteHeader(201)
			_, _ = io.WriteString(w, `{"voice_id":"x"}`)
		case strings.HasPrefix(p, "/v1/audio/voices/") && r.Method == http.MethodDelete:
			f.deleted = append(f.deleted, strings.TrimPrefix(p, "/v1/audio/voices/"))
			w.WriteHeader(404)
			_, _ = io.WriteString(w, `{"detail":"neznámý hlas"}`)
		default:
			t.Errorf("audio: unexpected %s %s", r.Method, p)
			w.WriteHeader(404)
		}
	})
}

func setup(t *testing.T, api *fakeAPI, au *fakeAudio) *Worker {
	t.Helper()
	if api.puts == nil {
		api.puts = map[string]string{}
	}
	if au.voices == nil {
		au.voices = map[string]string{}
	}
	as := httptest.NewServer(api.handler(t))
	t.Cleanup(as.Close)
	us := httptest.NewServer(au.handler(t))
	t.Cleanup(us.Close)
	cfg := config.Default().Worker
	cfg.IdleS, cfg.PollS, cfg.HeartbeatS = 0.01, 0.001, 30
	return &Worker{
		API:     &jobs.Client{BaseURL: as.URL, Token: "wt", Worker: "spark-test", HTTP: as.Client()},
		Audio:   &AudioClient{BaseURL: us.URL, HTTP: us.Client()},
		Cfg:     cfg,
		Prosody: script.Prosody{Speeds: map[script.Tone]float64{script.Soft: 0.85, script.Slow: 0.78, script.Whisper: 0.75}},
		Encode: func(in, out string) (float64, error) {
			b, err := os.ReadFile(in)
			if err != nil || string(b) != "RIFFwav" {
				t.Errorf("encode input %q %v", b, err)
			}
			return 1.25, os.WriteFile(out, []byte("m4a"), 0o644)
		},
		TmpDir: t.TempDir(),
		Log:    log.New(io.Discard, "", 0),
	}
}

const renderJob = `{"id":"r1","kind":"render","voice_id":"` + voice + `","tale":"test","length_min":1}`

func keys(t *testing.T) []string {
	s, err := script.Parse([]byte(testScript))
	if err != nil {
		t.Fatal(err)
	}
	var out []string
	for _, u := range s.Utterances() {
		out = append(out, script.UtteranceKey(voice, u.Tone, u.Text))
	}
	return out
}

func TestRenderSkipsExistingClips(t *testing.T) {
	k := keys(t) // 4 utterances, k[1] == k[2]
	if k[1] != k[2] {
		t.Fatal("identical tone+text must share a key")
	}
	api := &fakeAPI{queue: []string{renderJob}, existing: []string{k[0]}}
	au := &fakeAudio{}
	w := setup(t, api, au)
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if len(au.tts) != 2 {
		t.Fatalf("tts calls %d, want 2 (1 existing + 1 duplicate skipped)", len(au.tts))
	}
	want := []TTSRequest{
		{Text: "Spinkej.", Language: "cs", Voice: "hajanek-" + voice, Speed: 0.78, Format: "wav"},
		{Text: "Dobrou noc.", Language: "cs", Voice: "hajanek-" + voice, Speed: 0.75, Format: "wav"},
	}
	for i := range want {
		if au.tts[i] != want[i] {
			t.Errorf("tts %d = %+v, want %+v", i, au.tts[i], want[i])
		}
	}
	if len(api.puts) != 2 || api.puts[k[1]] != "1.250" || api.puts[k[3]] != "1.250" {
		t.Errorf("uploads %v", api.puts)
	}
	if api.heartbeat < 1 {
		t.Error("no heartbeat between utterances")
	}
	c := api.completes[0]
	res := c["result"].(map[string]any)
	if c["ok"] != true || c["retry"] != false || res["done"] != 3.0 || res["total"] != 3.0 {
		t.Errorf("complete %v", c)
	}
}

func TestRender503Retries(t *testing.T) {
	api := &fakeAPI{queue: []string{renderJob, renderJob}}
	w := setup(t, api, &fakeAudio{ttsCode: 503})
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if len(api.completes) != 1 {
		t.Fatalf("--once must stop after a deferred job, got %d completes", len(api.completes))
	}
	c := api.completes[0]
	res := c["result"].(map[string]any)
	if c["ok"] != false || c["retry"] != true || !strings.Contains(c["error"].(string), "503") || res["done"] != 0.0 || res["total"] != 3.0 {
		t.Errorf("complete %v", c)
	}
}

func TestRender403Fails(t *testing.T) {
	api := &fakeAPI{queue: []string{renderJob}}
	w := setup(t, api, &fakeAudio{ttsCode: 403})
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	c := api.completes[0]
	if c["ok"] != false || c["retry"] != false || !strings.Contains(c["error"].(string), "nekomerční") {
		t.Errorf("complete %v", c)
	}
}

func TestRenderEngineJobErrorRetries(t *testing.T) {
	api := &fakeAPI{queue: []string{renderJob}}
	w := setup(t, api, &fakeAudio{failJob: true})
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if c := api.completes[0]; c["retry"] != true || !strings.Contains(c["error"].(string), "CUDA") {
		t.Errorf("complete %v", c)
	}
}

func TestVoiceCreate(t *testing.T) {
	api := &fakeAPI{queue: []string{`{"id":"v1","kind":"voice_create","voice_id":"` + voice + `"}`}, sample: []byte("WAVDATA")}
	au := &fakeAudio{}
	w := setup(t, api, au)
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if got := au.voices["hajanek-"+voice]; got != "own|hajanek-app|cs|true|sample.wav|WAVDATA" {
		t.Errorf("upload %q", got)
	}
	if len(api.statuses) != 1 || api.statuses[0]["status"] != "ready" {
		t.Errorf("statuses %v", api.statuses)
	}
	if c := api.completes[0]; c["ok"] != true {
		t.Errorf("complete %v", c)
	}
}

func TestVoiceCreateRejectedSample(t *testing.T) {
	api := &fakeAPI{queue: []string{`{"id":"v1","kind":"voice_create","voice_id":"` + voice + `"}`}, sample: []byte("short")}
	w := setup(t, api, &fakeAudio{})
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if len(api.statuses) != 1 || api.statuses[0]["status"] != "failed" || !strings.Contains(api.statuses[0]["error"], "ořezu") {
		t.Errorf("statuses %v", api.statuses)
	}
	if c := api.completes[0]; c["ok"] != false || c["retry"] != false {
		t.Errorf("complete %v", c)
	}
}

func TestVoiceDelete404IsOK(t *testing.T) {
	api := &fakeAPI{queue: []string{`{"id":"d1","kind":"voice_delete","voice_id":"` + voice + `"}`}}
	au := &fakeAudio{}
	w := setup(t, api, au)
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if len(au.deleted) != 1 || au.deleted[0] != "hajanek-"+voice {
		t.Errorf("deleted %v", au.deleted)
	}
	if c := api.completes[0]; c["ok"] != true {
		t.Errorf("complete %v", c)
	}
}

func TestInvalidVoiceID(t *testing.T) {
	api := &fakeAPI{queue: []string{`{"id":"x","kind":"voice_delete","voice_id":"../etc"}`}}
	w := setup(t, api, &fakeAudio{})
	if err := w.Run(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	if c := api.completes[0]; c["ok"] != false || c["retry"] != false {
		t.Errorf("complete %v", c)
	}
}
