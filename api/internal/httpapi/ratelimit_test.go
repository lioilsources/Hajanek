package httpapi

import (
	"testing"
	"time"
)

func TestRateLimiter(t *testing.T) {
	now := time.Unix(0, 0)
	l := NewRateLimiter(2, time.Hour)
	l.now = func() time.Time { return now }
	for i, want := range []bool{true, true, false} {
		if got := l.Allow("a"); got != want {
			t.Fatalf("request %d: %v, want %v", i, got, want)
		}
	}
	if !l.Allow("b") {
		t.Fatal("keys are independent")
	}
	now = now.Add(30 * time.Minute) // refills one token
	for i, want := range []bool{true, false} {
		if got := l.Allow("a"); got != want {
			t.Fatalf("after refill %d: %v, want %v", i, got, want)
		}
	}
	var nilLimiter *RateLimiter
	if !nilLimiter.Allow("x") {
		t.Fatal("nil limiter must allow")
	}
}
