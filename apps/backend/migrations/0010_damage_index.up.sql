-- Migration 0010: Composite index for chronological listing of plant damage records
CREATE INDEX IF NOT EXISTS idx_kerusakan_date
  ON kerusakan_tanaman(tanggal_kejadian DESC, id_kerusakan DESC);
