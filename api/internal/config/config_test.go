package config

import (
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestLoad(t *testing.T) {
	c, err := Load(env(map[string]string{"ADMIN_TOKEN": "a", "WORKER_TOKEN": "w", "CATALOG_POLL": "90s"}))
	if err != nil {
		t.Fatal(err)
	}
	if c.Port != "8080" || c.CatalogPoll != 90*time.Second || c.JobMaxAttempts != 3 || c.CatalogURL != DefaultCatalogURL {
		t.Fatalf("unexpected config %+v", c)
	}

	bad := []map[string]string{
		{"WORKER_TOKEN": "w"},
		{"ADMIN_TOKEN": "a"},
		{"ADMIN_TOKEN": "same", "WORKER_TOKEN": "same"},
		{"ADMIN_TOKEN": "a", "WORKER_TOKEN": "w", "CATALOG_POLL": "often"},
		{"ADMIN_TOKEN": "a", "WORKER_TOKEN": "w", "JOB_MAX_ATTEMPTS": "0"},
	}
	for _, m := range bad {
		if _, err := Load(env(m)); err == nil {
			t.Errorf("expected error for %v", m)
		}
	}
}
