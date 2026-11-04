-- Ordered log of what changed, so a device can ask for everything after its last cursor.
-- Each row only names a record; the device re-reads it through the normal, permission-checked API.
CREATE TABLE sync_changes (
  id_change INTEGER PRIMARY KEY AUTOINCREMENT,
  resource_type TEXT NOT NULL CHECK (length(resource_type) BETWEEN 1 AND 80),
  domain_id TEXT NOT NULL,
  changed_at INTEGER NOT NULL
);

INSERT INTO sync_changes (resource_type, domain_id, changed_at)
SELECT l.resource_type, l.domain_id, v.changed_at
FROM sync_resource_versions v
JOIN sync_resource_links l ON l.resource_type = v.resource_type AND l.public_id = v.public_id
ORDER BY v.changed_at, l.resource_type, l.domain_id;

-- Triggers cover every path that versions a record, including the seeder and later features.
CREATE TRIGGER sync_changes_version_insert AFTER INSERT ON sync_resource_versions
BEGIN
  INSERT INTO sync_changes (resource_type, domain_id, changed_at)
  SELECT l.resource_type, l.domain_id, NEW.changed_at FROM sync_resource_links l
  WHERE l.resource_type = NEW.resource_type AND l.public_id = NEW.public_id;
END;

CREATE TRIGGER sync_changes_version_update AFTER UPDATE ON sync_resource_versions
BEGIN
  INSERT INTO sync_changes (resource_type, domain_id, changed_at)
  SELECT l.resource_type, l.domain_id, NEW.changed_at FROM sync_resource_links l
  WHERE l.resource_type = NEW.resource_type AND l.public_id = NEW.public_id;
END;
