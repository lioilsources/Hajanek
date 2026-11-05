package httpapi

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/sqlite"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "modernc.org/sqlite"

	"github.com/lioilsources/hajanek/api/internal/ids"
	"github.com/lioilsources/hajanek/api/internal/voices"
	"github.com/lioilsources/hajanek/api/migrations"
)

// doIP is e.do from a fresh client IP (clear of the per-IP rate limits).
func (e *env) doIP(method, path, token, body string) *httptest.ResponseRecorder {
	e.t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("X-Real-IP", ids.NewUUID())
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

type pairingResp struct {
	Code      string    `json:"code"`
	Status    string    `json:"status"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (e *env) newCode(tv string) pairingResp {
	e.t.Helper()
	rec := e.doIP("POST", "/v1/pairings", tv, "")
	var p pairingResp
	if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil || rec.Code != 201 || !voices.IsPairingCode(p.Code) || p.ExpiresAt.IsZero() {
		e.t.Fatalf("create pairing: %d %s", rec.Code, rec.Body)
	}
	return p
}

func (e *env) pairStatus(tv, code string) (int, string) {
	e.t.Helper()
	rec := e.doIP("GET", "/v1/pairings/"+code, tv, "")
	var p pairingResp
	_ = json.Unmarshal(rec.Body.Bytes(), &p)
	return rec.Code, p.Status
}

// pair pairs tv into phone's household.
func (e *env) pair(phone, tv string) {
	e.t.Helper()
	p := e.newCode(tv)
	if rec := e.doIP("POST", "/v1/pairings/"+p.Code+"/claim", phone, ""); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"status":"claimed"`) {
		e.t.Fatalf("claim: %d %s", rec.Code, rec.Body)
	}
}

func TestPairingFlow(t *testing.T) {
	e := newEnv(t, true)
	phone, tv, stranger := e.register(), e.register(), e.register()
	v := e.readyVoice(phone)
	key := keysFor(t, e, v.ID)[0]
	if rec := e.putClip(v.ID, key, m4aClip, "2"); rec.Code != 204 {
		t.Fatalf("put clip: %d", rec.Code)
	}
	clipPath := "/v1/clips/" + v.ID + "/" + key + ".m4a"

	// Before pairing the TV sees nothing.
	if rec := e.do("GET", "/v1/voices/"+v.ID, tv, ""); rec.Code != 404 {
		t.Fatalf("TV before pairing: %d", rec.Code)
	}

	start := time.Now()
	p := e.newCode(tv)
	if d := p.ExpiresAt.Sub(start); d < 9*time.Minute || d > 11*time.Minute {
		t.Fatalf("expires_at: %v", p.ExpiresAt)
	}
	if code, st := e.pairStatus(tv, p.Code); code != 200 || st != "pending" {
		t.Fatalf("status before claim: %d %q", code, st)
	}
	// Only the TV that created the code can poll it.
	for _, tok := range []string{phone, stranger} {
		if code, _ := e.pairStatus(tok, p.Code); code != 404 {
			t.Fatalf("foreign status poll: %d", code)
		}
	}
	// The TV cannot claim its own code; the code stays valid.
	if rec := e.doIP("POST", "/v1/pairings/"+p.Code+"/claim", tv, ""); rec.Code != 409 {
		t.Fatalf("self claim: %d %s", rec.Code, rec.Body)
	}
	if rec := e.doIP("POST", "/v1/pairings/"+p.Code+"/claim", phone, ""); rec.Code != 200 {
		t.Fatalf("claim: %d %s", rec.Code, rec.Body)
	}
	if code, st := e.pairStatus(tv, p.Code); code != 200 || st != "claimed" {
		t.Fatalf("status after claim: %d %q", code, st)
	}
	// The code is burned.
	if rec := e.doIP("POST", "/v1/pairings/"+p.Code+"/claim", stranger, ""); rec.Code != 404 {
		t.Fatalf("second claim: %d", rec.Code)
	}

	// The TV reads the parent's voice, renders and clips.
	rec := e.do("GET", "/v1/voices", tv, "")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), v.ID) || !strings.Contains(rec.Body.String(), `"owned":false`) {
		t.Fatalf("TV voice list: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("GET", "/v1/voices", phone, ""); !strings.Contains(rec.Body.String(), `"owned":true`) {
		t.Fatalf("phone voice list: %s", rec.Body)
	}
	if rec := e.do("GET", "/v1/voices/"+v.ID, tv, ""); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"owned":false`) {
		t.Fatalf("TV get voice: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("POST", "/v1/voices/"+v.ID+"/renders", tv, `{"tale":"cervena-karkulka","length_min":10}`); rec.Code != 202 {
		t.Fatalf("TV render: %d %s", rec.Code, rec.Body)
	}
	rec = e.do("GET", "/v1/voices/"+v.ID+"/renders/cervena-karkulka/10", tv, "")
	var m voices.Manifest
	if err := json.Unmarshal(rec.Body.Bytes(), &m); err != nil || rec.Code != 200 || m.Clips[key].URL != clipPath {
		t.Fatalf("TV manifest: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("GET", clipPath, tv, ""); rec.Code != 200 || !bytes.Equal(rec.Body.Bytes(), m4aClip) {
		t.Fatalf("TV clip: %d", rec.Code)
	}

	// The TV can't delete the parent's voice.
	if rec := e.do("DELETE", "/v1/voices/"+v.ID, tv, ""); rec.Code != 404 {
		t.Fatalf("TV delete voice: %d", rec.Code)
	}
	// An unrelated device still can't read anything.
	for _, c := range []struct{ method, path, body string }{
		{"GET", "/v1/voices/" + v.ID, ""},
		{"POST", "/v1/voices/" + v.ID + "/renders", `{"tale":"cervena-karkulka","length_min":10}`},
		{"GET", "/v1/voices/" + v.ID + "/renders/cervena-karkulka/10", ""},
		{"GET", clipPath, ""},
	} {
		if rec := e.do(c.method, c.path, stranger, c.body); rec.Code != 404 {
			t.Errorf("stranger %s %s: %d", c.method, c.path, rec.Code)
		}
	}
	if rec := e.do("GET", "/v1/voices", stranger, ""); strings.Contains(rec.Body.String(), v.ID) {
		t.Fatalf("stranger lists voice: %s", rec.Body)
	}

	// Deleting the TV leaves the parent's voice alone.
	if rec := e.do("DELETE", "/v1/devices/me", tv, ""); rec.Code != 204 {
		t.Fatalf("delete TV: %d", rec.Code)
	}
	if js := e.jobsOf("queued", "voice_delete"); len(js) != 0 {
		t.Fatalf("TV deletion deleted voices: %+v", js)
	}
	if rec := e.do("GET", clipPath, phone, ""); rec.Code != 200 {
		t.Fatalf("phone clip after TV deleted: %d", rec.Code)
	}
	if rec := e.do("GET", "/v1/voices/"+v.ID, phone, ""); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"ready"`) {
		t.Fatalf("phone voice after TV deleted: %d %s", rec.Code, rec.Body)
	}
}

func TestPairingCodes(t *testing.T) {
	e := newEnv(t, true)
	phone, tv := e.register(), e.register()

	for _, code := range []string{"000000", "12345", "1234567", "abcdef"} {
		if rec := e.doIP("POST", "/v1/pairings/"+code+"/claim", phone, ""); rec.Code != 404 {
			t.Errorf("claim %q: %d", code, rec.Code)
		}
	}
	// A new code replaces the old one.
	old := e.newCode(tv)
	cur := e.newCode(tv)
	if old.Code != cur.Code {
		if rec := e.doIP("POST", "/v1/pairings/"+old.Code+"/claim", phone, ""); rec.Code != 404 {
			t.Fatalf("replaced code: %d", rec.Code)
		}
		if code, _ := e.pairStatus(tv, old.Code); code != 404 {
			t.Fatalf("replaced code status: %d", code)
		}
	}

	// Expiry: 10 minutes.
	e.voices.Now = func() time.Time { return time.Now().Add(10*time.Minute + time.Second) }
	if code, _ := e.pairStatus(tv, cur.Code); code != 404 {
		t.Fatalf("expired status: %d", code)
	}
	if rec := e.doIP("POST", "/v1/pairings/"+cur.Code+"/claim", phone, ""); rec.Code != 404 {
		t.Fatalf("expired claim: %d", rec.Code)
	}
	fresh := e.newCode(tv)
	if rec := e.doIP("POST", "/v1/pairings/"+fresh.Code+"/claim", phone, ""); rec.Code != 200 {
		t.Fatalf("fresh claim: %d", rec.Code)
	}
	// A claimed code still reports "claimed" after its expiry.
	e.voices.Now = func() time.Time { return time.Now().Add(30 * time.Minute) }
	if code, st := e.pairStatus(tv, fresh.Code); code != 200 || st != "claimed" {
		t.Fatalf("claimed after expiry: %d %q", code, st)
	}
	if rec := e.doIP("POST", "/v1/pairings", "", ""); rec.Code != 401 {
		t.Fatalf("anonymous pairing: %d", rec.Code)
	}
}

func TestPairingRateLimits(t *testing.T) {
	e := newEnv(t, true)
	phone, tv := e.register(), e.register()
	// Claims: 5 per minute per IP (e.do always uses the same client IP).
	for i := range 5 {
		if rec := e.do("POST", "/v1/pairings/000000/claim", phone, ""); rec.Code != 404 {
			t.Fatalf("claim %d: %d", i, rec.Code)
		}
	}
	if rec := e.do("POST", "/v1/pairings/000000/claim", phone, ""); rec.Code != 429 {
		t.Fatalf("claim over limit: %d", rec.Code)
	}
	// Even a valid code is refused while limited.
	p := e.newCode(tv)
	if rec := e.do("POST", "/v1/pairings/"+p.Code+"/claim", phone, ""); rec.Code != 429 {
		t.Fatalf("valid claim over limit: %d", rec.Code)
	}
	if rec := e.doIP("POST", "/v1/pairings/"+p.Code+"/claim", phone, ""); rec.Code != 200 {
		t.Fatalf("other IP: %d", rec.Code)
	}
	// Codes: like POST /v1/devices (5 per hour per IP in tests).
	for i := range 5 {
		if rec := e.do("POST", "/v1/pairings", tv, ""); rec.Code != 201 {
			t.Fatalf("code %d: %d", i, rec.Code)
		}
	}
	if rec := e.do("POST", "/v1/pairings", tv, ""); rec.Code != 429 {
		t.Fatalf("code over limit: %d", rec.Code)
	}
}

func TestPairingMovesOnlyTheTV(t *testing.T) {
	e := newEnv(t, true)
	mom, dad, tv := e.register(), e.register(), e.register()
	vm, vd := e.readyVoice(mom), e.readyVoice(dad)
	e.pair(mom, tv)
	// Re-pairing to another household: the TV leaves mom's household.
	e.pair(dad, tv)
	rec := e.do("GET", "/v1/voices", tv, "")
	if !strings.Contains(rec.Body.String(), vd.ID) || strings.Contains(rec.Body.String(), vm.ID) {
		t.Fatalf("TV after re-pairing: %s", rec.Body)
	}
	// Mom and dad never see each other's voices; the claimer never moves.
	if rec := e.do("GET", "/v1/voices/"+vd.ID, mom, ""); rec.Code != 404 {
		t.Fatalf("mom reads dad's voice: %d", rec.Code)
	}
	// A second TV in dad's household sees the same voice; deleting the
	// voice stays with dad.
	tv2 := e.register()
	e.pair(dad, tv2)
	if rec := e.do("GET", "/v1/voices/"+vd.ID, tv2, ""); rec.Code != 200 {
		t.Fatalf("tv2: %d", rec.Code)
	}
	if rec := e.do("DELETE", "/v1/voices/"+vd.ID, tv2, ""); rec.Code != 404 {
		t.Fatalf("tv2 delete: %d", rec.Code)
	}
	// Dad deletes his device: his voices go, the TVs stay paired together.
	if rec := e.do("DELETE", "/v1/devices/me", dad, ""); rec.Code != 204 {
		t.Fatalf("delete dad: %d", rec.Code)
	}
	for _, tok := range []string{tv, tv2} {
		if rec := e.do("GET", "/v1/voices", tok, ""); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"voices":[]`) {
			t.Fatalf("TV after owner deleted: %d %s", rec.Code, rec.Body)
		}
	}
	// Households without devices are gone.
	var n int
	if err := e.sqldb.QueryRow(`SELECT COUNT(*) FROM households h WHERE NOT EXISTS (SELECT 1 FROM devices d WHERE d.household_id = h.id)`).Scan(&n); err != nil || n != 0 {
		t.Fatalf("empty households: %d %v", n, err)
	}
}

// TestMigrationKeepsDevices: devices and voices created before 0003 keep
// working, each device in its own household.
func TestMigrationKeepsDevices(t *testing.T) {
	dir := t.TempDir()
	dbPath, dataDir := filepath.Join(dir, "api.db"), t.TempDir()

	raw, err := sql.Open("sqlite", "file:"+dbPath+"?_pragma=foreign_keys(1)")
	if err != nil {
		t.Fatal(err)
	}
	m := migrator(t, raw)
	if err := m.Migrate(2); err != nil {
		t.Fatal(err)
	}
	tokA, tokB := strings.Repeat("a", 64), strings.Repeat("b", 64)
	hash := func(s string) string { sum := sha256.Sum256([]byte(s)); return hex.EncodeToString(sum[:]) }
	devA, devB := ids.NewUUID(), ids.NewUUID()
	voice, key := ids.NewUUID(), strings.Repeat("c", 64)
	for _, q := range []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO devices (id, token_hash, created_at) VALUES (?, ?, 1), (?, ?, 2)`, []any{devA, hash(tokA), devB, hash(tokB)}},
		{`INSERT INTO voices (id, device_id, name, status, sample_ext, sample_bytes, consent_text, consent_at, created_at, updated_at)
		  VALUES (?, ?, 'Máma', 'ready', 'wav', 10, 'souhlas', 1, 1, 1)`, []any{voice, devA}},
		{`INSERT INTO clips (voice_id, key, bytes, duration_s, created_at) VALUES (?, ?, ?, 1.5, 1)`, []any{voice, key, len(m4aClip)}},
	} {
		if _, err := raw.Exec(q.sql, q.args...); err != nil {
			t.Fatal(err)
		}
	}
	if err := raw.Close(); err != nil {
		t.Fatal(err)
	}
	clip := filepath.Join(dataDir, "voices", voice, "clips", key+".m4a")
	if err := os.MkdirAll(filepath.Dir(clip), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(clip, m4aClip, 0o640); err != nil {
		t.Fatal(err)
	}

	e := newEnvAt(t, dbPath, dataDir, true) // migrates to the latest version
	rec := e.do("GET", "/v1/voices", tokA, "")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), voice) || !strings.Contains(rec.Body.String(), `"owned":true`) {
		t.Fatalf("A's voices after migration: %d %s", rec.Code, rec.Body)
	}
	if rec := e.do("GET", "/v1/clips/"+voice+"/"+key+".m4a", tokA, ""); rec.Code != 200 {
		t.Fatalf("A's clip after migration: %d", rec.Code)
	}
	if rec := e.do("GET", "/v1/voices/"+voice, tokB, ""); rec.Code != 404 {
		t.Fatalf("B reads A's voice after migration: %d", rec.Code)
	}
	var households int
	if err := e.sqldb.QueryRow(`SELECT COUNT(DISTINCT household_id) FROM devices`).Scan(&households); err != nil || households != 2 {
		t.Fatalf("households: %d %v", households, err)
	}
	// Pairing works for migrated devices.
	e.pair(tokA, tokB)
	if rec := e.do("GET", "/v1/clips/"+voice+"/"+key+".m4a", tokB, ""); rec.Code != 200 {
		t.Fatalf("B's clip after pairing: %d", rec.Code)
	}
	if rec := e.do("DELETE", "/v1/voices/"+voice, tokA, ""); rec.Code != 204 {
		t.Fatalf("A deletes voice: %d", rec.Code)
	}

	// 0003 down keeps devices and voice owners.
	m = migrator(t, e.sqldb)
	if err := m.Migrate(2); err != nil {
		t.Fatal(err)
	}
	var owner string
	if err := e.sqldb.QueryRow(`SELECT device_id FROM voices WHERE id = ?`, voice).Scan(&owner); err != nil || owner != devA {
		t.Fatalf("voice owner after down: %q %v", owner, err)
	}
	if err := m.Migrate(3); err != nil {
		t.Fatal(err)
	}
}

// migrator migrates sqldb; it is never closed, which would close sqldb.
func migrator(t *testing.T, sqldb *sql.DB) *migrate.Migrate {
	t.Helper()
	src, err := iofs.New(migrations.FS, ".")
	if err != nil {
		t.Fatal(err)
	}
	drv, err := sqlite.WithInstance(sqldb, &sqlite.Config{})
	if err != nil {
		t.Fatal(err)
	}
	m, err := migrate.NewWithInstance("iofs", src, "sqlite", drv)
	if err != nil {
		t.Fatal(err)
	}
	return m
}
