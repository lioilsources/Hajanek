-- name: GetJob :one
SELECT * FROM jobs WHERE id = ?;

-- name: GetActiveJobByKey :one
SELECT * FROM jobs
WHERE idem_key = ? AND status IN ('queued', 'running')
LIMIT 1;

-- name: InsertJob :one
INSERT INTO jobs (id, kind, tale, voice, length_min, priority, idem_key, status, max_attempts, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', ?, ?, ?)
RETURNING *;

-- name: ListJobs :many
SELECT * FROM jobs
ORDER BY created_at DESC, id DESC
LIMIT ?;

-- name: ListJobsByStatus :many
SELECT * FROM jobs
WHERE status = ?
ORDER BY created_at DESC, id DESC
LIMIT ?;

-- name: ClaimJob :one
UPDATE jobs
SET status = 'running',
    attempts = attempts + 1,
    worker = sqlc.arg(worker),
    lease_expires_at = sqlc.arg(lease_expires_at),
    started_at = COALESCE(started_at, sqlc.arg(now)),
    updated_at = sqlc.arg(now),
    error = ''
WHERE id = (
    SELECT j.id FROM jobs j
    WHERE j.status = 'queued' AND j.kind IN (sqlc.slice(kinds))
    ORDER BY j.priority DESC, j.created_at ASC, j.id ASC
    LIMIT 1
)
RETURNING *;

-- name: ExtendLease :one
UPDATE jobs
SET lease_expires_at = sqlc.arg(lease_expires_at), updated_at = sqlc.arg(now)
WHERE id = sqlc.arg(id) AND status = 'running' AND worker = sqlc.arg(worker)
RETURNING *;

-- name: FinishJob :one
UPDATE jobs
SET status = sqlc.arg(status),
    result = sqlc.arg(result),
    error = sqlc.arg(error),
    lease_expires_at = NULL,
    finished_at = sqlc.arg(now),
    updated_at = sqlc.arg(now)
WHERE id = sqlc.arg(id) AND status = 'running' AND worker = sqlc.arg(worker)
RETURNING *;

-- name: ReapExpiredLeases :many
UPDATE jobs
SET status = CASE WHEN attempts >= max_attempts THEN 'failed' ELSE 'queued' END,
    error = 'lease expired',
    worker = '',
    lease_expires_at = NULL,
    finished_at = CASE WHEN attempts >= max_attempts THEN sqlc.arg(now) ELSE NULL END,
    updated_at = sqlc.arg(now)
WHERE status = 'running' AND lease_expires_at <= sqlc.arg(now)
RETURNING *;

-- name: RequeueJob :one
UPDATE jobs
SET status = 'queued',
    error = sqlc.arg(error),
    worker = '',
    lease_expires_at = NULL,
    updated_at = sqlc.arg(now)
WHERE id = sqlc.arg(id) AND status = 'running' AND worker = sqlc.arg(worker)
RETURNING *;
