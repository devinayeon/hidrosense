-- Additive authentication infrastructure; existing domain records are preserved.
CREATE TABLE auth_sessions (
  id_session TEXT PRIMARY KEY NOT NULL,
  id_user INTEGER NOT NULL,
  access_token_hash TEXT NOT NULL UNIQUE,
  refresh_token_hash TEXT NOT NULL UNIQUE,
  credential_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  access_expires_at INTEGER NOT NULL,
  refresh_expires_at INTEGER NOT NULL,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON DELETE NO ACTION,
  CHECK (access_expires_at > created_at),
  CHECK (refresh_expires_at >= access_expires_at)
);
CREATE INDEX idx_auth_sessions_id_user ON auth_sessions (id_user);
CREATE INDEX idx_auth_sessions_refresh_expires_at ON auth_sessions (refresh_expires_at);

-- Atomic shared counters persist across processes using the same database.
CREATE TABLE auth_rate_limits (
  bucket_key TEXT PRIMARY KEY NOT NULL,
  hits INTEGER NOT NULL CHECK (hits > 0),
  resets_at INTEGER NOT NULL
);
CREATE INDEX idx_auth_rate_limits_resets_at ON auth_rate_limits (resets_at);
