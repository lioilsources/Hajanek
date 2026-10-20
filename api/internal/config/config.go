// Package config loads service configuration from the environment.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port        string
	DBPath      string
	CatalogURL  string
	CatalogPoll time.Duration
	AdminToken  string
	WorkerToken string

	JobLease       time.Duration // lease granted on claim / heartbeat
	JobMaxAttempts int
	ReaperInterval time.Duration

	DataDir            string // samples, clips, script cache
	MaxVoicesPerDevice int
	// DeviceRate limits POST /v1/devices per client IP: DeviceRateN
	// registrations per DeviceRatePer (token bucket). N = 0 disables it.
	DeviceRateN   int
	DeviceRatePer time.Duration
}

// ParseRate parses "N/duration" (e.g. "10/1h") or "off".
func ParseRate(v string) (int, time.Duration, error) {
	if v == "off" || v == "0" {
		return 0, 0, nil
	}
	ns, ds, ok := strings.Cut(v, "/")
	n, err := strconv.Atoi(ns)
	if !ok || err != nil || n < 1 {
		return 0, 0, fmt.Errorf("invalid rate %q (want N/duration, e.g. 10/1h, or off)", v)
	}
	d, err := time.ParseDuration(ds)
	if err != nil || d <= 0 {
		return 0, 0, fmt.Errorf("invalid rate %q (want N/duration, e.g. 10/1h, or off)", v)
	}
	return n, d, nil
}

const DefaultCatalogURL = "https://lioilsources.github.io/hajanek-content/catalog.json"

// Load reads the configuration from env using getenv (os.Getenv when nil).
func Load(getenv func(string) string) (Config, error) {
	if getenv == nil {
		getenv = os.Getenv
	}
	str := func(key, def string) string {
		if v := getenv(key); v != "" {
			return v
		}
		return def
	}
	var errs []error
	dur := func(key string, def time.Duration) time.Duration {
		v := getenv(key)
		if v == "" {
			return def
		}
		d, err := time.ParseDuration(v)
		if err != nil || d <= 0 {
			errs = append(errs, fmt.Errorf("%s: invalid duration %q", key, v))
			return def
		}
		return d
	}

	c := Config{
		Port:           str("PORT", "8080"),
		DBPath:         str("DB_PATH", "hajanek.db"),
		CatalogURL:     str("CATALOG_URL", DefaultCatalogURL),
		CatalogPoll:    dur("CATALOG_POLL", 5*time.Minute),
		AdminToken:     getenv("ADMIN_TOKEN"),
		WorkerToken:    getenv("WORKER_TOKEN"),
		JobLease:       dur("JOB_LEASE", 10*time.Minute),
		ReaperInterval: dur("REAPER_INTERVAL", 30*time.Second),
		JobMaxAttempts: 3,
		DataDir:        str("DATA_DIR", "data"),
	}
	posInt := func(key string, def int) int {
		v := getenv(key)
		if v == "" {
			return def
		}
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			errs = append(errs, fmt.Errorf("%s: invalid value %q", key, v))
			return def
		}
		return n
	}
	c.JobMaxAttempts = posInt("JOB_MAX_ATTEMPTS", 3)
	c.MaxVoicesPerDevice = posInt("MAX_VOICES_PER_DEVICE", 3)
	n, per, err := ParseRate(str("DEVICE_RATE_LIMIT", "10/1h"))
	if err != nil {
		errs = append(errs, fmt.Errorf("DEVICE_RATE_LIMIT: %w", err))
	}
	c.DeviceRateN, c.DeviceRatePer = n, per
	if c.AdminToken == "" {
		errs = append(errs, errors.New("ADMIN_TOKEN is required"))
	}
	if c.WorkerToken == "" {
		errs = append(errs, errors.New("WORKER_TOKEN is required"))
	}
	if c.AdminToken != "" && c.AdminToken == c.WorkerToken {
		errs = append(errs, errors.New("ADMIN_TOKEN and WORKER_TOKEN must differ"))
	}
	return c, errors.Join(errs...)
}
