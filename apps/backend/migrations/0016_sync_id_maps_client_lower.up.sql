-- Migration 0016: pencarian mapping klien berjalan di setiap tulis yang memakai X-Client-Id.
-- Tanpa indeks ini SQLite memindai semua mapping milik pengguna untuk jenis resource itu.
CREATE INDEX IF NOT EXISTS idx_sync_id_maps_client_lower
  ON sync_id_maps (id_user, resource_type, lower(client_id));
