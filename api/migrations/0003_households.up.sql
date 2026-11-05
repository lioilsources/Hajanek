-- Households and TV pairing (docs/HAJANEK_TV_PLAN.md §5.1, CONTRACTS.md §6).
--
-- Every device belongs to exactly one household. Read access to a voice,
-- its renders and clips is shared by the household of the voice's owner
-- (voices.device_id); deleting a voice stays owner-only.

CREATE TABLE households (
    id         TEXT    PRIMARY KEY,
    created_at INTEGER NOT NULL
);

-- Each existing device gets its own household; its id reuses the device id
-- (both are opaque UUIDs, new households get fresh ones).
INSERT INTO households (id, created_at) SELECT id, created_at FROM devices;

-- SQLite cannot add a NOT NULL REFERENCES column, so devices is rebuilt.
-- Migrations run in a transaction where PRAGMA foreign_keys cannot be
-- switched off, and DROP TABLE devices fires voices' ON DELETE SET NULL:
-- remember the owners and restore them after the rebuild.
CREATE TEMP TABLE voice_owners AS SELECT id, device_id FROM voices WHERE device_id IS NOT NULL;

CREATE TABLE devices_new (
    id           TEXT    PRIMARY KEY,
    token_hash   TEXT    NOT NULL UNIQUE,
    household_id TEXT    NOT NULL REFERENCES households (id),
    created_at   INTEGER NOT NULL
);
INSERT INTO devices_new (id, token_hash, household_id, created_at)
SELECT id, token_hash, id, created_at FROM devices;
DROP TABLE devices;
ALTER TABLE devices_new RENAME TO devices;
CREATE INDEX devices_household ON devices (household_id);

UPDATE voices SET device_id = (SELECT o.device_id FROM voice_owners o WHERE o.id = voices.id)
WHERE id IN (SELECT id FROM voice_owners);
DROP TABLE voice_owners;

-- Pairing codes: a TV (code owner) shows a 6-digit code, a phone claims it
-- and the TV joins the phone's household. One row per device; a new code
-- replaces the old one. Claimed rows stay (claimed_at set, the code is
-- burned) so the TV can see the result; stale rows are pruned by the API.
CREATE TABLE pairings (
    code       TEXT    PRIMARY KEY CHECK (length(code) = 6),
    device_id  TEXT    NOT NULL UNIQUE REFERENCES devices (id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL, -- unix ms
    claimed_at INTEGER,          -- unix ms, NULL while pending
    claimed_by TEXT    REFERENCES devices (id) ON DELETE SET NULL
);
CREATE INDEX pairings_expires ON pairings (expires_at);
