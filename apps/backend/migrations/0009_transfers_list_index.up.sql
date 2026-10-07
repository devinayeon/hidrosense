-- Migration 0009: Composite index for chronological listing of seedling transfers
CREATE INDEX IF NOT EXISTS idx_pemindahan_date
  ON pemindahan(tanggal_pemindahan DESC, id_pemindahan DESC);
