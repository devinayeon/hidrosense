-- Migration 0012: keep receipt lookup by canonical key cheap on long-lived ledgers.
CREATE INDEX IF NOT EXISTS idx_sync_operations_key_lower
  ON sync_operations (id_user, lower(operation_key));
