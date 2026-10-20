package httpapi

import (
	"net"
	"net/http"
	"sync"
	"time"
)

// RateLimiter is an in-memory token bucket per key (client IP): burst n,
// refilled at n per `per`. State is lost on restart, which is fine for
// keeping scripts from mass-registering devices.
type RateLimiter struct {
	n   float64
	per time.Duration
	now func() time.Time

	mu      sync.Mutex
	buckets map[string]*bucket
}

type bucket struct {
	tokens float64
	last   time.Time
}

// maxBuckets bounds memory; full buckets are pruned when it is reached.
const maxBuckets = 10000

func NewRateLimiter(n int, per time.Duration) *RateLimiter {
	return &RateLimiter{n: float64(n), per: per, now: time.Now, buckets: map[string]*bucket{}}
}

// Allow takes one token for key. A nil limiter allows everything.
func (l *RateLimiter) Allow(key string) bool {
	if l == nil || l.n <= 0 {
		return true
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	b, ok := l.buckets[key]
	if !ok {
		if len(l.buckets) >= maxBuckets {
			l.prune(now)
		}
		b = &bucket{tokens: l.n, last: now}
		l.buckets[key] = b
	}
	b.tokens = min(l.n, b.tokens+now.Sub(b.last).Seconds()*l.n/l.per.Seconds())
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

func (l *RateLimiter) prune(now time.Time) {
	for k, b := range l.buckets {
		if now.Sub(b.last) >= l.per {
			delete(l.buckets, k)
		}
	}
	if len(l.buckets) >= maxBuckets { // still full: start over rather than grow
		clear(l.buckets)
	}
}

// clientIP is the caller's address. In production the API is reachable
// only through Caddy, which sets X-Real-IP from Cloudflare's
// CF-Connecting-IP (deploy/Caddyfile).
func clientIP(r *http.Request) string {
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
