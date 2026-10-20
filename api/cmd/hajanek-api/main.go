// Command hajanek-api serves the Hajánek catalog endpoints and the
// generation job queue consumed by workers on the Spark.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/lioilsources/hajanek/api/internal/catalog"
	"github.com/lioilsources/hajanek/api/internal/config"
	"github.com/lioilsources/hajanek/api/internal/db"
	"github.com/lioilsources/hajanek/api/internal/httpapi"
	"github.com/lioilsources/hajanek/api/internal/jobs"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(log)
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}
	if err := run(log); err != nil {
		log.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) (retErr error) {
	cfg, err := config.Load(nil)
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	sqldb, err := db.Open(ctx, cfg.DBPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := sqldb.Close(); err != nil && retErr == nil {
			retErr = fmt.Errorf("close db: %w", err)
		}
	}()

	cat := catalog.NewService(db.New(sqldb), cfg.CatalogURL, catalog.WithLogger(log))
	if err := cat.Load(ctx); err != nil {
		return err
	}
	store := jobs.NewStore(sqldb, cfg.JobLease, cfg.JobMaxAttempts)
	store.Log = log

	api := &httpapi.Server{
		DB:          sqldb,
		Catalog:     cat,
		Jobs:        store,
		AdminToken:  cfg.AdminToken,
		WorkerToken: cfg.WorkerToken,
		Log:         log,
	}
	srv := &http.Server{
		Addr:              net.JoinHostPort("", cfg.Port),
		Handler:           api.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	var wg sync.WaitGroup
	wg.Go(func() { cat.Run(ctx, cfg.CatalogPoll) })
	wg.Go(func() { store.RunReaper(ctx, cfg.ReaperInterval) })

	errc := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", srv.Addr, "catalog_url", cfg.CatalogURL, "catalog_poll", cfg.CatalogPoll.String())
		errc <- srv.ListenAndServe()
	}()

	select {
	case err := <-errc:
		stop()
		wg.Wait()
		return err
	case <-ctx.Done():
	}

	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	err = srv.Shutdown(shutdownCtx)
	wg.Wait()
	if err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

// healthcheck probes the local /healthz; used by Docker (distroless has no curl).
func healthcheck() int {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	c := &http.Client{Timeout: 3 * time.Second}
	resp, err := c.Get("http://" + net.JoinHostPort("127.0.0.1", port) + "/healthz")
	if err != nil {
		return 1
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
