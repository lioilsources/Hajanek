package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"mime/multipart"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/lioilsources/hajanek/api/internal/ids"
	"github.com/lioilsources/hajanek/api/internal/jobs"
	"github.com/lioilsources/hajanek/api/internal/script"
	"github.com/lioilsources/hajanek/api/internal/voices"
)

// fakeProbe: samples containing "short" last 3 s, everything else 10 s.
func fakeProbe(_ context.Context, path string) (float64, bool, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0, true, err
	}
	if bytes.Contains(b, []byte("short")) {
		return 3, true, nil
	}
	return 10, true, nil
}

var (
	wavSample = append([]byte("RIFF\x24\x00\x00\x00WAVEfmt "), bytes.Repeat([]byte{0}, 64)...)
	m4aClip   = append([]byte("\x00\x00\x00\x18ftypM4A \x00\x00\x00\x00"), bytes.Repeat([]byte{1}, 100)...)
)

type formFields map[string]string

func (e *env) postVoice(token string, fields formFields, sample []byte) *httptest.ResponseRecorder {
	e.t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	for k, v := range fields {
		_ = mw.WriteField(k, v)
	}
	if sample != nil {
		fw, _ := mw.CreateFormFile("sample", "sample.wav")
		_, _ = fw.Write(sample)
	}
	_ = mw.Close()
	req := httptest.NewRequest("POST", "/v1/voices", &buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func validForm() formFields {
	return formFields{"name": "Máma", "consent": "true", "consent_text": "Jsem Jana a souhlasím, aby Hajánek z této nahrávky vytvořil můj hlas."}
}

func (e *env) register() string {
	e.t.Helper()
	req := httptest.NewRequest("POST", "/v1/devices", nil)
	req.Header.Set("X-Real-IP", ids.NewUUID()) // stay clear of the rate limit
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	var d struct {
		DeviceID string `json:"device_id"`
		Token    string `json:"token"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &d); err != nil || rec.Code != 201 || len(d.Token) != 64 || d.DeviceID == "" {
		e.t.Fatalf("register: %d %s", rec.Code, rec.Body)
	}
	return d.Token
}

func (e *env) createVoice(token string) voices.Voice {
	e.t.Helper()
	rec := e.postVoice(token, validForm(), wavSample)
	if rec.Code != 201 {
		e.t.Fatalf("create voice: %d %s", rec.Code, rec.Body)
	}
	var v voices.Voice
	_ = json.Unmarshal(rec.Body.Bytes(), &v)
	return v
}

func (e *env) readyVoice(token string) voices.Voice {
	e.t.Helper()
	v := e.createVoice(token)
	if rec := e.do("POST", "/v1/worker/voices/"+v.ID+"/status", workerToken, `{"status":"ready"}`); rec.Code != 200 {
		e.t.Fatalf("set ready: %d %s", rec.Code, rec.Body)
	}
	return v
}

func (e *env) putClip(voiceID, key string, body []byte, dur string) *httptest.ResponseRecorder {
	e.t.Helper()
	req := httptest.NewRequest("PUT", "/v1/worker/clips/"+voiceID+"/"+key, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+workerToken)
	if dur != "" {
		req.Header.Set("X-Duration-S", dur)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func (e *env) jobsOf(status, kind string) []jobs.Job {
	e.t.Helper()
	rec := e.do("GET", "/v1/jobs?status="+status, adminToken, "")
	var list struct{ Jobs []jobs.Job }
	_ = json.Unmarshal(rec.Body.Bytes(), &list)
	var out []jobs.Job
	for _, j := range list.Jobs {
		if string(j.Kind) == kind {
			out = append(out, j)
		}
	}
	return out
}

func keysFor(t *testing.T, e *env, voiceID string) []string {
	t.Helper()
	sc, err := script.Parse(e.script)
	if err != nil {
		t.Fatal(err)
	}
	return sc.Keys(voiceID)
}

func TestDeviceAuth(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()
	for _, c := range []struct {
		token string
		want  int
	}{{"", 401}, {"nope", 401}, {adminToken, 401}, {workerToken, 401}, {tok, 200}} {
		if rec := e.do("GET", "/v1/voices", c.token, ""); rec.Code != c.want {
			t.Errorf("token %q: %d want %d", c.token, rec.Code, c.want)
		}
	}
	if rec := e.do("DELETE", "/v1/devices/me", tok, ""); rec.Code != 204 {
		t.Fatalf("delete device: %d", rec.Code)
	}
	if rec := e.do("GET", "/v1/voices", tok, ""); rec.Code != 401 {
		t.Fatalf("token after delete: %d", rec.Code)
	}
	// Worker endpoints don't accept device tokens.
	if rec := e.do("GET", "/v1/worker/scripts/cervena-karkulka/10", e.register(), ""); rec.Code != 401 {
		t.Fatalf("device on worker endpoint: %d", rec.Code)
	}
}

func TestDeviceRateLimit(t *testing.T) {
	e := newEnv(t, false) // limiter: 5 per hour per IP
	for i := range 5 {
		if rec := e.do("POST", "/v1/devices", "", ""); rec.Code != 201 {
			t.Fatalf("register %d: %d", i, rec.Code)
		}
	}
	if rec := e.do("POST", "/v1/devices", "", ""); rec.Code != 429 {
		t.Fatalf("over limit: %d", rec.Code)
	}
	req := httptest.NewRequest("POST", "/v1/devices", nil)
	req.Header.Set("X-Real-IP", "203.0.113.7")
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != 201 {
		t.Fatalf("other IP: %d", rec.Code)
	}
}

func TestCreateVoiceValidation(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()
	with := func(k, v string) formFields {
		f := validForm()
		if v == "" {
			delete(f, k)
		} else {
			f[k] = v
		}
		return f
	}
	cases := []struct {
		name   string
		form   formFields
		sample []byte
		want   int
	}{
		{"no consent", with("consent", ""), wavSample, 400},
		{"consent false", with("consent", "false"), wavSample, 400},
		{"no consent text", with("consent_text", ""), wavSample, 400},
		{"blank consent text", with("consent_text", "   "), wavSample, 400},
		{"no name", with("name", ""), wavSample, 400},
		{"no sample", validForm(), nil, 400},
		{"not audio", validForm(), []byte("hello, this is not audio at all"), 415},
		{"too short", validForm(), append(slices.Clone(wavSample), "short"...), 400},
		{"too large", validForm(), append(slices.Clone(wavSample), make([]byte, 5<<20)...), 413},
	}
	for _, c := range cases {
		if rec := e.postVoice(tok, c.form, c.sample); rec.Code != c.want {
			t.Errorf("%s: %d want %d (%s)", c.name, rec.Code, c.want, rec.Body)
		}
	}
	if rec := e.do("GET", "/v1/voices", tok, ""); !strings.Contains(rec.Body.String(), `"voices":[]`) {
		t.Fatalf("rejected uploads created voices: %s", rec.Body)
	}
	if ents, _ := os.ReadDir(filepath.Join(e.dataDir, "tmp")); len(ents) != 0 {
		t.Fatalf("temp files left behind: %v", ents)
	}

	v := e.createVoice(tok)
	if v.Status != voices.StatusPending || v.Name != "Máma" {
		t.Fatalf("voice: %+v", v)
	}
	if _, err := os.Stat(filepath.Join(e.dataDir, "voices", v.ID, "sample.wav")); err != nil {
		t.Fatalf("sample not stored: %v", err)
	}
	if js := e.jobsOf("queued", "voice_create"); len(js) != 1 || js[0].VoiceID != v.ID {
		t.Fatalf("voice_create job: %+v", js)
	}
	// Worker downloads the sample.
	rec := e.do("GET", "/v1/worker/voices/"+v.ID+"/sample", workerToken, "")
	if rec.Code != 200 || !bytes.Equal(rec.Body.Bytes(), wavSample) || rec.Header().Get("Content-Type") != "audio/wav" {
		t.Fatalf("worker sample: %d %v", rec.Code, rec.Header())
	}
	// Limit: 3 voices per device.
	e.createVoice(tok)
	e.createVoice(tok)
	if rec := e.postVoice(tok, validForm(), wavSample); rec.Code != 409 {
		t.Fatalf("voice limit: %d %s", rec.Code, rec.Body)
	}
}

func TestOwnershipIsolation(t *testing.T) {
	e := newEnv(t, true)
	a, b := e.register(), e.register()
	v := e.readyVoice(a)
	key := keysFor(t, e, v.ID)[0]
	if rec := e.putClip(v.ID, key, m4aClip, "2.5"); rec.Code != 204 {
		t.Fatalf("put clip: %d %s", rec.Code, rec.Body)
	}

	clipPath := "/v1/clips/" + v.ID + "/" + key + ".m4a"
	rec := e.do("GET", clipPath, a, "")
	if rec.Code != 200 || !bytes.Equal(rec.Body.Bytes(), m4aClip) ||
		!strings.Contains(rec.Header().Get("Cache-Control"), "immutable") || rec.Header().Get("Content-Type") != "audio/mp4" {
		t.Fatalf("owner clip: %d %v", rec.Code, rec.Header())
	}

	for _, c := range []struct{ method, path, body string }{
		{"GET", "/v1/voices/" + v.ID, ""},
		{"DELETE", "/v1/voices/" + v.ID, ""},
		{"POST", "/v1/voices/" + v.ID + "/renders", `{"tale":"cervena-karkulka","length_min":10}`},
		{"GET", "/v1/voices/" + v.ID + "/renders/cervena-karkulka/10", ""},
		{"GET", clipPath, ""},
	} {
		if rec := e.do(c.method, c.path, b, c.body); rec.Code != 404 {
			t.Errorf("device B %s %s: %d (%s)", c.method, c.path, rec.Code, rec.Body)
		}
	}
	// Indistinguishable from a voice that doesn't exist.
	missing := "00000000-0000-4000-8000-000000000000"
	recMissing := e.do("GET", "/v1/voices/"+missing, b, "")
	recForeign := e.do("GET", "/v1/voices/"+v.ID, b, "")
	if recMissing.Code != recForeign.Code || recMissing.Body.String() != recForeign.Body.String() {
		t.Errorf("existence leak: %s vs %s", recMissing.Body, recForeign.Body)
	}
	if rec := e.do("GET", "/v1/voices", b, ""); strings.Contains(rec.Body.String(), v.ID) {
		t.Errorf("B lists A's voice: %s", rec.Body)
	}
	// A's voice survived B's delete attempt.
	if rec := e.do("GET", "/v1/voices/"+v.ID, a, ""); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"ready"`) {
		t.Fatalf("A's voice: %d %s", rec.Code, rec.Body)
	}
}

func TestVoiceDeleteCascade(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()
	v := e.readyVoice(tok)
	key := keysFor(t, e, v.ID)[0]
	if rec := e.putClip(v.ID, key, m4aClip, "1.5"); rec.Code != 204 {
		t.Fatalf("put clip: %d", rec.Code)
	}
	if rec := e.do("POST", "/v1/voices/"+v.ID+"/renders", tok, `{"tale":"cervena-karkulka","length_min":10}`); rec.Code != 202 {
		t.Fatalf("render: %d %s", rec.Code, rec.Body)
	}

	if rec := e.do("DELETE", "/v1/voices/"+v.ID, tok, ""); rec.Code != 204 {
		t.Fatalf("delete: %d %s", rec.Code, rec.Body)
	}
	if _, err := os.Stat(filepath.Join(e.dataDir, "voices", v.ID)); !os.IsNotExist(err) {
		t.Fatalf("voice files still present: %v", err)
	}
	rec := e.do("GET", "/v1/voices/"+v.ID, tok, "")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), `"deleting"`) {
		t.Fatalf("voice after delete: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("GET", "/v1/clips/"+v.ID+"/"+key+".m4a", tok, ""); rec.Code != 404 {
		t.Fatalf("clip after delete: %d", rec.Code)
	}
	if js := e.jobsOf("queued", "render"); len(js) != 0 {
		t.Fatalf("queued render not cancelled: %+v", js)
	}
	// The worker can't fetch the sample or upload clips any more.
	if rec := e.do("GET", "/v1/worker/voices/"+v.ID+"/sample", workerToken, ""); rec.Code != 404 {
		t.Fatalf("sample after delete: %d", rec.Code)
	}
	if rec := e.putClip(v.ID, key, m4aClip, "1.5"); rec.Code != 409 {
		t.Fatalf("clip upload after delete: %d", rec.Code)
	}

	del := e.jobsOf("queued", "voice_delete")
	if len(del) != 1 || del[0].VoiceID != v.ID {
		t.Fatalf("voice_delete job: %+v", del)
	}
	rec = e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark","kinds":["voice_delete"]}`)
	if rec.Code != 200 || decodeJob(t, rec).ID != del[0].ID {
		t.Fatalf("claim voice_delete: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("POST", "/v1/jobs/"+del[0].ID+"/complete", workerToken, `{"worker":"spark","ok":true}`); rec.Code != 200 {
		t.Fatalf("complete: %d", rec.Code)
	}
	if rec := e.do("GET", "/v1/voices/"+v.ID, tok, ""); rec.Code != 404 {
		t.Fatalf("voice row not hard-deleted: %d %s", rec.Code, rec.Body)
	}
}

func TestDeviceDeleteCascade(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()
	v1, v2 := e.readyVoice(tok), e.createVoice(tok)
	if rec := e.do("DELETE", "/v1/devices/me", tok, ""); rec.Code != 204 {
		t.Fatalf("delete device: %d", rec.Code)
	}
	del := e.jobsOf("queued", "voice_delete")
	var got []string
	for _, j := range del {
		got = append(got, j.VoiceID)
	}
	slices.Sort(got)
	want := []string{v1.ID, v2.ID}
	slices.Sort(want)
	if !slices.Equal(got, want) {
		t.Fatalf("voice_delete jobs %v want %v", got, want)
	}
	if js := e.jobsOf("queued", "voice_create"); len(js) != 0 {
		t.Fatalf("voice_create still queued: %+v", js)
	}
	for _, id := range want {
		if _, err := os.Stat(filepath.Join(e.dataDir, "voices", id)); !os.IsNotExist(err) {
			t.Fatalf("files of %s still present", id)
		}
	}
}

func TestRendersAndManifest(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()

	pending := e.createVoice(tok)
	if rec := e.do("POST", "/v1/voices/"+pending.ID+"/renders", tok, `{"tale":"cervena-karkulka","length_min":10}`); rec.Code != 409 {
		t.Fatalf("render on pending voice: %d", rec.Code)
	}

	v := e.readyVoice(tok)
	for _, body := range []string{`{"tale":"zlatovlaska","length_min":10}`, `{"tale":"cervena-karkulka","length_min":5}`} {
		if rec := e.do("POST", "/v1/voices/"+v.ID+"/renders", tok, body); rec.Code != 404 {
			t.Errorf("render %s: %d", body, rec.Code)
		}
	}
	if rec := e.do("POST", "/v1/voices/"+v.ID+"/renders", tok, `{"tale":"Bad Tale"}`); rec.Code != 400 {
		t.Errorf("bad render request: %d", rec.Code)
	}

	keys := keysFor(t, e, v.ID)
	if len(keys) != 9 {
		t.Fatalf("keys: %d", len(keys))
	}
	// Manifest before any render: no status, no clips.
	var m voices.Manifest
	rec := e.do("GET", "/v1/voices/"+v.ID+"/renders/cervena-karkulka/10", tok, "")
	if err := json.Unmarshal(rec.Body.Bytes(), &m); err != nil || rec.Code != 200 || m.Status != "none" || m.Total != 9 || len(m.Clips) != 0 {
		t.Fatalf("empty manifest: %d %s", rec.Code, rec.Body)
	}

	var r1, r2 voices.Render
	rec = e.do("POST", "/v1/voices/"+v.ID+"/renders", tok, `{"tale":"cervena-karkulka","length_min":10}`)
	_ = json.Unmarshal(rec.Body.Bytes(), &r1)
	rec = e.do("POST", "/v1/voices/"+v.ID+"/renders", tok, `{"tale":"cervena-karkulka","length_min":10}`)
	_ = json.Unmarshal(rec.Body.Bytes(), &r2)
	if rec.Code != 202 || r1.JobID == "" || r1.JobID != r2.JobID || r1.Status != "queued" || r1.Total != 9 {
		t.Fatalf("idempotent render: %+v %+v", r1, r2)
	}
	if js := e.jobsOf("queued", "render"); len(js) != 1 || js[0].Tale != "cervena-karkulka" || js[0].LengthMin != 10 || js[0].VoiceID != v.ID {
		t.Fatalf("render jobs: %+v", js)
	}

	// Worker: script, existing keys, uploads.
	rec = e.do("GET", "/v1/worker/scripts/cervena-karkulka/10", workerToken, "")
	if rec.Code != 200 || !bytes.Equal(rec.Body.Bytes(), e.script) || !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/markdown") ||
		rec.Header().Get("X-Script-SHA256") != r1.ScriptSHA256 {
		t.Fatalf("worker script: %d %v", rec.Code, rec.Header())
	}
	if rec := e.do("GET", "/v1/worker/scripts/zlatovlaska/10", workerToken, ""); rec.Code != 404 {
		t.Fatalf("worker unknown script: %d", rec.Code)
	}
	for _, k := range keys[:2] {
		if rec := e.putClip(v.ID, k, m4aClip, "3.25"); rec.Code != 204 {
			t.Fatalf("put clip: %d %s", rec.Code, rec.Body)
		}
	}
	// A clip with a key outside this script (another tale) is not listed.
	other := script.Key(v.ID, script.Soft, "Jiná pohádka.")
	if rec := e.putClip(v.ID, other, m4aClip, "1"); rec.Code != 204 {
		t.Fatalf("put other clip: %d", rec.Code)
	}
	rec = e.do("GET", "/v1/worker/clips/"+v.ID, workerToken, "")
	var ck struct{ Keys []string }
	_ = json.Unmarshal(rec.Body.Bytes(), &ck)
	if rec.Code != 200 || len(ck.Keys) != 3 || !slices.Contains(ck.Keys, keys[0]) || !slices.Contains(ck.Keys, other) {
		t.Fatalf("worker clip keys: %d %s", rec.Code, rec.Body)
	}

	m = voices.Manifest{}
	rec = e.do("GET", "/v1/voices/"+v.ID+"/renders/cervena-karkulka/10", tok, "")
	if err := json.Unmarshal(rec.Body.Bytes(), &m); err != nil || rec.Code != 200 {
		t.Fatalf("manifest: %d %s", rec.Code, rec.Body)
	}
	if m.Status != "queued" || m.ScriptSHA256 != r1.ScriptSHA256 || m.Done != 2 || m.Total != 9 || len(m.Clips) != 2 {
		t.Fatalf("manifest: %+v", m)
	}
	for _, k := range keys[:2] {
		c, ok := m.Clips[k]
		if !ok || c.URL != "/v1/clips/"+v.ID+"/"+k+".m4a" || c.DurationS != 3.25 || c.Bytes != int64(len(m4aClip)) {
			t.Fatalf("clip %s: %+v", k, c)
		}
	}

	// Worker finishes the render job; progress is recorded.
	rec = e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark","kinds":["render"]}`)
	job := decodeJob(t, rec)
	if rec.Code != 200 || job.ID != r1.JobID {
		t.Fatalf("claim render: %d %s", rec.Code, rec.Body)
	}
	rec = e.do("GET", "/v1/voices/"+v.ID+"/renders/cervena-karkulka/10", tok, "")
	if !strings.Contains(rec.Body.String(), `"status":"running"`) {
		t.Fatalf("running manifest: %s", rec.Body)
	}
	for _, k := range keys[2:] {
		if rec := e.putClip(v.ID, k, m4aClip, "2"); rec.Code != 204 {
			t.Fatalf("put clip: %d", rec.Code)
		}
	}
	if rec := e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken, `{"worker":"spark","ok":true,"result":{"done":9,"total":9}}`); rec.Code != 200 {
		t.Fatalf("complete render: %d %s", rec.Code, rec.Body)
	}
	m = voices.Manifest{}
	rec = e.do("GET", "/v1/voices/"+v.ID+"/renders/cervena-karkulka/10", tok, "")
	_ = json.Unmarshal(rec.Body.Bytes(), &m)
	if m.Status != "done" || m.Done != 9 || len(m.Clips) != 9 {
		t.Fatalf("done manifest: %+v", m)
	}
	// A finished, complete render is not re-enqueued.
	var r3 voices.Render
	rec = e.do("POST", "/v1/voices/"+v.ID+"/renders", tok, `{"tale":"cervena-karkulka","length_min":10}`)
	_ = json.Unmarshal(rec.Body.Bytes(), &r3)
	if r3.JobID != r1.JobID || r3.Status != "done" || r3.Done != 9 {
		t.Fatalf("render after done: %+v", r3)
	}
	if js := e.jobsOf("queued", "render"); len(js) != 0 {
		t.Fatalf("render re-enqueued: %+v", js)
	}
}

func TestWorkerClipUploadRejects(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()
	v := e.readyVoice(tok)
	key := keysFor(t, e, v.ID)[0]

	for _, c := range []struct {
		name, path string
		body       []byte
		dur        string
		want       int
	}{
		{"traversal in key", "/v1/worker/clips/" + v.ID + "/..%2F..%2F..%2Fescape", m4aClip, "1", 400},
		{"dotdot key", "/v1/worker/clips/" + v.ID + "/..", m4aClip, "1", 0},
		{"traversal in voice", "/v1/worker/clips/..%2F..%2Fx/" + key, m4aClip, "1", 400},
		{"uppercase key", "/v1/worker/clips/" + v.ID + "/" + strings.ToUpper(key), m4aClip, "1", 400},
		{"short key", "/v1/worker/clips/" + v.ID + "/abc", m4aClip, "1", 400},
		{"unknown voice", "/v1/worker/clips/00000000-0000-4000-8000-000000000000/" + key, m4aClip, "1", 404},
		{"missing duration", "/v1/worker/clips/" + v.ID + "/" + key, m4aClip, "", 400},
		{"bad duration", "/v1/worker/clips/" + v.ID + "/" + key, m4aClip, "-1", 400},
		{"not m4a", "/v1/worker/clips/" + v.ID + "/" + key, []byte("definitely not an mp4 file"), "1", 415},
		{"too large", "/v1/worker/clips/" + v.ID + "/" + key, append(slices.Clone(m4aClip), make([]byte, 2<<20)...), "1", 413},
	} {
		req := httptest.NewRequest("PUT", c.path, bytes.NewReader(c.body))
		req.Header.Set("Authorization", "Bearer "+workerToken)
		if c.dur != "" {
			req.Header.Set("X-Duration-S", c.dur)
		}
		rec := httptest.NewRecorder()
		e.h.ServeHTTP(rec, req)
		if (c.want != 0 && rec.Code != c.want) || (c.want == 0 && rec.Code < 300) {
			t.Errorf("%s: %d want %d (%s)", c.name, rec.Code, c.want, rec.Body)
		}
	}
	// Device tokens can't upload.
	req := httptest.NewRequest("PUT", "/v1/worker/clips/"+v.ID+"/"+key, bytes.NewReader(m4aClip))
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("X-Duration-S", "1")
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != 401 {
		t.Fatalf("device upload: %d", rec.Code)
	}

	// Nothing was written anywhere except the voice's sample.
	var files []string
	_ = filepath.WalkDir(e.dataDir, func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			files = append(files, p)
		}
		return nil
	})
	if len(files) != 1 || !strings.HasSuffix(files[0], filepath.Join("voices", v.ID, "sample.wav")) {
		t.Fatalf("unexpected files: %v", files)
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(e.dataDir), "escape")); !os.IsNotExist(err) {
		t.Fatal("file escaped DATA_DIR")
	}
}

func TestWorkerVoiceStatus(t *testing.T) {
	e := newEnv(t, true)
	tok := e.register()
	v := e.createVoice(tok)
	if rec := e.do("POST", "/v1/worker/voices/"+v.ID+"/status", workerToken, `{"status":"deleting"}`); rec.Code != 400 {
		t.Fatalf("bad status: %d", rec.Code)
	}
	if rec := e.do("POST", "/v1/worker/voices/00000000-0000-4000-8000-000000000000/status", workerToken, `{"status":"ready"}`); rec.Code != 404 {
		t.Fatalf("unknown voice: %d", rec.Code)
	}
	rec := e.do("POST", "/v1/worker/voices/"+v.ID+"/status", workerToken, `{"status":"failed","error":"audio service rejected sample"}`)
	if rec.Code != 200 {
		t.Fatalf("set failed: %d", rec.Code)
	}
	rec = e.do("GET", "/v1/voices/"+v.ID, tok, "")
	if !strings.Contains(rec.Body.String(), `"status":"failed"`) || !strings.Contains(rec.Body.String(), "rejected sample") {
		t.Fatalf("voice: %s", rec.Body)
	}

	// A voice_create job that finally fails marks a pending voice failed.
	v2 := e.createVoice(tok)
	rec = e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark","kinds":["voice_create"]}`)
	job := decodeJob(t, rec)
	for job.VoiceID != v2.ID { // skip the first voice's job
		_ = e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken, `{"worker":"spark","ok":true}`)
		job = decodeJob(t, e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark","kinds":["voice_create"]}`))
	}
	_ = e.do("POST", "/v1/jobs/"+job.ID+"/complete", workerToken, `{"worker":"spark","ok":false,"error":"no GPU"}`)
	rec = e.do("GET", "/v1/voices/"+v2.ID, tok, "")
	if !strings.Contains(rec.Body.String(), `"status":"failed"`) {
		t.Fatalf("voice after failed job: %s", rec.Body)
	}
}

func TestVoiceJobPayloadUsesVoiceID(t *testing.T) {
	e := newEnv(t, false)
	id := "3f2c1a2b-0000-4000-8000-000000000001"
	rec := e.do("POST", "/v1/jobs", adminToken, `{"kind":"render","voice_id":"`+id+`","tale":"zlatovlaska","length_min":10}`)
	if rec.Code != 201 || !strings.Contains(rec.Body.String(), `"voice_id":"`+id+`"`) || strings.Contains(rec.Body.String(), `"voice":`) {
		t.Fatalf("render job: %d %s", rec.Code, rec.Body)
	}
	rec = e.do("POST", "/v1/jobs/claim", workerToken, `{"worker":"spark","kinds":["render"]}`)
	if !strings.Contains(rec.Body.String(), `"voice_id":"`+id+`"`) {
		t.Fatalf("claimed job: %s", rec.Body)
	}
	if rec := e.do("POST", "/v1/jobs", adminToken, `{"kind":"voice_delete","voice":"`+id+`","voice_id":"00000000-0000-4000-8000-000000000000"}`); rec.Code != 400 {
		t.Fatalf("conflicting voice/voice_id: %d", rec.Code)
	}
}
