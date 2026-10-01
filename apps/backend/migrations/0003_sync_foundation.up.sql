-- Durable server-side identity, replay receipts, and versions for offline operations.
CREATE TABLE sync_operations (
  id_change INTEGER PRIMARY KEY AUTOINCREMENT,
  id_user INTEGER NOT NULL,
  operation_key TEXT NOT NULL CHECK (length(operation_key) = 36),
  operation_type TEXT NOT NULL CHECK (length(operation_type) BETWEEN 1 AND 80),
  payload_hash TEXT NOT NULL CHECK (length(payload_hash) = 64),
  result_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE (id_user, operation_key),
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON DELETE NO ACTION
);
CREATE INDEX idx_sync_operations_change ON sync_operations (id_change);

CREATE TABLE sync_id_maps (
  id_user INTEGER NOT NULL,
  resource_type TEXT NOT NULL CHECK (length(resource_type) BETWEEN 1 AND 80),
  client_id TEXT NOT NULL CHECK (length(client_id) = 36),
  public_id TEXT NOT NULL UNIQUE CHECK (length(public_id) = 36),
  created_at INTEGER NOT NULL,
  PRIMARY KEY (id_user, resource_type, client_id),
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON DELETE NO ACTION
);

CREATE TABLE sync_resource_versions (
  resource_type TEXT NOT NULL CHECK (length(resource_type) BETWEEN 1 AND 80),
  public_id TEXT NOT NULL CHECK (length(public_id) = 36),
  version INTEGER NOT NULL CHECK (version > 0),
  changed_at INTEGER NOT NULL,
  PRIMARY KEY (resource_type, public_id)
);
