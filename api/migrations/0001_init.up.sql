-- Last known-good catalog (single row, id = 1).
CREATE TABLE catalog_cache (
    id            INTEGER PRIMARY KEY CHECK (id = 1),
    version       INTEGER NOT NULL,
    body          BLOB    NOT NULL,
    sha256        TEXT    NOT NULL,
    etag          TEXT    NOT NULL DEFAULT '',
    last_modified TEXT    NOT NULL DEFAULT '',
    fetched_at    INTEGER NOT NULL, -- unix ms, last successful fetch
    updated_at    INTEGER NOT NULL  -- unix ms, last time body changed
);

CREATE TABLE jobs (
    id               TEXT    PRIMARY KEY,
    kind             TEXT    NOT NULL CHECK (kind IN ('script', 'voice', 'master', 'publish', 'tale')),
    tale             TEXT    NOT NULL DEFAULT '',
    voice            TEXT    NOT NULL DEFAULT '',
    length_min       INTEGER NOT NULL DEFAULT 0,
    priority         INTEGER NOT NULL DEFAULT 0,
    idem_key         TEXT    NOT NULL,
    status           TEXT    NOT NULL CHECK (status IN ('queued', 'running', 'done', 'failed')),
    attempts         INTEGER NOT NULL DEFAULT 0,
    max_attempts     INTEGER NOT NULL,
    worker           TEXT    NOT NULL DEFAULT '',
    lease_expires_at INTEGER,          -- unix ms, set while running
    result           BLOB,             -- JSON from the worker
    error            TEXT    NOT NULL DEFAULT '',
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL,
    started_at       INTEGER,
    finished_at      INTEGER
);

-- At most one active job per idempotency key.
CREATE UNIQUE INDEX jobs_active_idem ON jobs (idem_key) WHERE status IN ('queued', 'running');
CREATE INDEX jobs_queue ON jobs (status, priority DESC, created_at);
CREATE INDEX jobs_lease ON jobs (lease_expires_at) WHERE status = 'running';
