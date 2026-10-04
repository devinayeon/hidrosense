-- Migration 0007: Nursery ordering index and status guard trigger
-- Uses the existing sync_resource_links / sync_resource_versions tables
-- for public_id and version identity (same pattern as stock/inventory).
-- No columns added to penyemaian; existing rows remain valid.

CREATE INDEX IF NOT EXISTS idx_penyemaian_user_date
  ON penyemaian(id_user, tanggal_semai DESC, id_penyemaian DESC);

-- Guard: status_penyemaian must be 'aktif' or 'selesai' when set
CREATE TRIGGER IF NOT EXISTS trg_penyemaian_status_insert
  BEFORE INSERT ON penyemaian
  WHEN NEW.status_penyemaian IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'status_penyemaian harus aktif atau selesai')
  WHERE NEW.status_penyemaian NOT IN ('aktif', 'selesai');
END;

CREATE TRIGGER IF NOT EXISTS trg_penyemaian_status_update
  BEFORE UPDATE OF status_penyemaian ON penyemaian
  WHEN NEW.status_penyemaian IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'status_penyemaian harus aktif atau selesai')
  WHERE NEW.status_penyemaian NOT IN ('aktif', 'selesai');
END;
