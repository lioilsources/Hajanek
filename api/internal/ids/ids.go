// Package ids generates and validates identifiers that end up in file paths
// and URLs (voice UUIDs, utterance keys). Validation is strict on purpose:
// anything accepted here is safe to join into a filesystem path.
package ids

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"regexp"
)

var (
	uuidRe = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
	hex64  = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// NewUUID returns a random (v4) UUID in canonical lowercase form.
func NewUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// IsUUID reports whether s is a canonical lowercase UUID.
func IsUUID(s string) bool { return uuidRe.MatchString(s) }

// IsHex64 reports whether s is 64 lowercase hex chars (a sha256 / utterance key).
func IsHex64(s string) bool { return hex64.MatchString(s) }

// NewToken returns 32 random bytes as hex.
func NewToken() string {
	var b [32]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}
