DROP TABLE pairings;

-- Back to device-owned voices: drop household_id (rebuild, see the up
-- migration for why the voice owners are saved first).
CREATE TEMP TABLE voice_owners AS SELECT id, device_id FROM voices WHERE device_id IS NOT NULL;
CREATE TABLE devices_old (
    id         TEXT    PRIMARY KEY,
    token_hash TEXT    NOT NULL UNIQUE,
    created_at INTEGER NOT NULL
);
INSERT INTO devices_old (id, token_hash, created_at) SELECT id, token_hash, created_at FROM devices;
DROP TABLE devices;
ALTER TABLE devices_old RENAME TO devices;
UPDATE voices SET device_id = (SELECT o.device_id FROM voice_owners o WHERE o.id = voices.id)
WHERE id IN (SELECT id FROM voice_owners);
DROP TABLE voice_owners;

DROP TABLE households;
