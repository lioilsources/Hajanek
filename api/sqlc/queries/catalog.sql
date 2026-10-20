-- name: GetCatalog :one
SELECT * FROM catalog_cache WHERE id = 1;

-- name: UpsertCatalog :exec
INSERT INTO catalog_cache (id, version, body, sha256, etag, last_modified, fetched_at, updated_at)
VALUES (1, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (id) DO UPDATE SET
    version       = excluded.version,
    body          = excluded.body,
    sha256        = excluded.sha256,
    etag          = excluded.etag,
    last_modified = excluded.last_modified,
    fetched_at    = excluded.fetched_at,
    updated_at    = excluded.updated_at;

-- name: TouchCatalog :exec
UPDATE catalog_cache
SET fetched_at = ?, etag = ?, last_modified = ?
WHERE id = 1;
