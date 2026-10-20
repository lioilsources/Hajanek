DROP TABLE clips;
DROP TABLE renders;
DROP TABLE voices;
DROP TABLE devices;

DELETE FROM jobs WHERE kind IN ('voice_create', 'voice_delete', 'render');
CREATE TABLE jobs_old (
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
    lease_expires_at INTEGER,
    result           BLOB,
    error            TEXT    NOT NULL DEFAULT '',
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL,
    started_at       INTEGER,
    finished_at      INTEGER
);
INSERT INTO jobs_old SELECT * FROM jobs;
DROP TABLE jobs;
ALTER TABLE jobs_old RENAME TO jobs;
CREATE UNIQUE INDEX jobs_active_idem ON jobs (idem_key) WHERE status IN ('queued', 'running');
CREATE INDEX jobs_queue ON jobs (status, priority DESC, created_at);
CREATE INDEX jobs_lease ON jobs (lease_expires_at) WHERE status = 'running';
