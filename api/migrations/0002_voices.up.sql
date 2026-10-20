-- Parent voices (ADR-003, CONTRACTS.md §6–§8).

-- New job kinds: voice_create, voice_delete, render. SQLite cannot alter a
-- CHECK constraint, so the jobs table is rebuilt. Legacy kinds stay valid
-- so that existing rows survive.
CREATE TABLE jobs_new (
    id               TEXT    PRIMARY KEY,
    kind             TEXT    NOT NULL CHECK (kind IN ('script', 'voice', 'master', 'publish', 'tale',
                                                      'voice_create', 'voice_delete', 'render')),
    tale             TEXT    NOT NULL DEFAULT '',
    voice            TEXT    NOT NULL DEFAULT '',
    length_min       INTEGER NOT NULL DEFAULT 0,
    priority         INTEGER NOT NULL DEFAULT 0,
    idem_key         TEXT    NOT NULL,
    status           TEXT    NOT NULL CHECK (status IN ('queued', 'running', 'done', 'failed')),
    attempts         INTEGER NOT NULL DEFAULT 0,
    max_attempts     INTEGER NOT NULL,
    worker           TEXT    NOT NULL DEFAULT '',
    lease_expires_at INTEGER,
    result           BLOB,
    error            TEXT    NOT NULL DEFAULT '',
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL,
    started_at       INTEGER,
    finished_at      INTEGER
);
INSERT INTO jobs_new SELECT * FROM jobs;
DROP TABLE jobs;
ALTER TABLE jobs_new RENAME TO jobs;
CREATE UNIQUE INDEX jobs_active_idem ON jobs (idem_key) WHERE status IN ('queued', 'running');
CREATE INDEX jobs_queue ON jobs (status, priority DESC, created_at);
CREATE INDEX jobs_lease ON jobs (lease_expires_at) WHERE status = 'running';
CREATE INDEX jobs_voice ON jobs (voice) WHERE voice != '';

-- Anonymous devices. Only the sha256 of the bearer token is stored.
CREATE TABLE devices (
    id         TEXT    PRIMARY KEY,
    token_hash TEXT    NOT NULL UNIQUE,
    created_at INTEGER NOT NULL
);

-- A voice outlives its device while it is being deleted on the Spark
-- (status 'deleting', device_id NULL); the row is removed when the
-- voice_delete job finishes.
CREATE TABLE voices (
    id                TEXT    PRIMARY KEY,
    device_id         TEXT    REFERENCES devices (id) ON DELETE SET NULL,
    name              TEXT    NOT NULL,
    status            TEXT    NOT NULL CHECK (status IN ('pending', 'ready', 'failed', 'deleting')),
    error             TEXT    NOT NULL DEFAULT '',
    sample_ext        TEXT    NOT NULL,
    sample_bytes      INTEGER NOT NULL,
    sample_duration_s REAL,             -- NULL when ffprobe was unavailable
    consent_text      TEXT    NOT NULL,
    consent_at        INTEGER NOT NULL,
    created_at        INTEGER NOT NULL,
    updated_at        INTEGER NOT NULL
);
CREATE INDEX voices_device ON voices (device_id, created_at);

-- Requested renders (voice × tale × length). Status comes from the job.
CREATE TABLE renders (
    voice_id      TEXT    NOT NULL REFERENCES voices (id) ON DELETE CASCADE,
    tale          TEXT    NOT NULL,
    length_min    INTEGER NOT NULL,
    script_sha256 TEXT    NOT NULL,
    job_id        TEXT    NOT NULL,
    done          INTEGER NOT NULL DEFAULT 0,
    total         INTEGER NOT NULL DEFAULT 0,
    created_at    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL,
    PRIMARY KEY (voice_id, tale, length_min)
);

-- Clips per utterance key (CONTRACTS.md §7); files live in DATA_DIR.
CREATE TABLE clips (
    voice_id   TEXT    NOT NULL REFERENCES voices (id) ON DELETE CASCADE,
    key        TEXT    NOT NULL CHECK (length(key) = 64),
    bytes      INTEGER NOT NULL,
    duration_s REAL    NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (voice_id, key)
);
