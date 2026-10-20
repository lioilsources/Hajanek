-- name: InsertDevice :exec
INSERT INTO devices (id, token_hash, created_at) VALUES (?, ?, ?);

-- name: GetDeviceByTokenHash :one
SELECT id FROM devices WHERE token_hash = ?;

-- name: DeleteDevice :exec
DELETE FROM devices WHERE id = ?;

-- name: CountActiveVoices :one
SELECT COUNT(*) FROM voices WHERE device_id = ? AND status != 'deleting';

-- name: InsertVoice :one
INSERT INTO voices (id, device_id, name, status, sample_ext, sample_bytes, sample_duration_s,
                    consent_text, consent_at, created_at, updated_at)
VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: GetVoice :one
SELECT * FROM voices WHERE id = ?;

-- name: GetDeviceVoice :one
SELECT * FROM voices WHERE id = ? AND device_id = ?;

-- name: ListDeviceVoices :many
SELECT * FROM voices WHERE device_id = ? ORDER BY created_at, id;

-- name: SetVoiceStatus :one
UPDATE voices SET status = ?, error = ?, updated_at = ?
WHERE id = ?
RETURNING *;

-- name: FailPendingVoice :exec
UPDATE voices SET status = 'failed', error = ?, updated_at = ?
WHERE id = ? AND status = 'pending';

-- name: MarkVoiceDeleting :exec
UPDATE voices SET status = 'deleting', error = '', updated_at = ? WHERE id = ?;

-- name: DetachDeviceVoices :exec
UPDATE voices SET device_id = NULL WHERE device_id = ?;

-- name: HardDeleteVoice :exec
DELETE FROM voices WHERE id = ? AND status = 'deleting';

-- name: CancelQueuedVoiceJobs :exec
UPDATE jobs
SET status = 'failed', error = 'voice deleted', finished_at = sqlc.arg(now), updated_at = sqlc.arg(now)
WHERE voice = sqlc.arg(voice) AND status = 'queued' AND kind IN ('voice_create', 'render');

-- name: DeleteVoiceRenders :exec
DELETE FROM renders WHERE voice_id = ?;

-- name: DeleteVoiceClips :exec
DELETE FROM clips WHERE voice_id = ?;

-- name: UpsertRender :exec
INSERT INTO renders (voice_id, tale, length_min, script_sha256, job_id, done, total, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (voice_id, tale, length_min) DO UPDATE SET
    script_sha256 = excluded.script_sha256,
    job_id        = excluded.job_id,
    done          = excluded.done,
    total         = excluded.total,
    updated_at    = excluded.updated_at;

-- name: GetRender :one
SELECT r.voice_id, r.tale, r.length_min, r.script_sha256, r.job_id, r.done, r.total,
       r.created_at, r.updated_at, COALESCE(j.status, '') AS job_status, COALESCE(j.error, '') AS job_error
FROM renders r LEFT JOIN jobs j ON j.id = r.job_id
WHERE r.voice_id = ? AND r.tale = ? AND r.length_min = ?;

-- name: UpdateRenderProgress :exec
UPDATE renders SET done = ?, total = ?, updated_at = ? WHERE job_id = ?;

-- name: InsertClip :exec
INSERT INTO clips (voice_id, key, bytes, duration_s, created_at)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT (voice_id, key) DO UPDATE SET
    bytes = excluded.bytes, duration_s = excluded.duration_s, created_at = excluded.created_at;

-- name: GetClip :one
SELECT * FROM clips WHERE voice_id = ? AND key = ?;

-- name: ListClips :many
SELECT * FROM clips WHERE voice_id = ? ORDER BY key;
