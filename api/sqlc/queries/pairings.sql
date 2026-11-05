-- name: DeleteDevicePairing :exec
DELETE FROM pairings WHERE device_id = ?;

-- name: DeleteStalePairings :exec
DELETE FROM pairings WHERE expires_at <= ?;

-- name: PairingCodeTaken :one
SELECT COUNT(*) FROM pairings WHERE code = ?;

-- name: InsertPairing :exec
INSERT INTO pairings (code, device_id, created_at, expires_at) VALUES (?, ?, ?, ?);

-- name: GetPairing :one
SELECT * FROM pairings WHERE code = ?;

-- name: MarkPairingClaimed :exec
UPDATE pairings SET claimed_at = ?, claimed_by = ? WHERE code = ?;
