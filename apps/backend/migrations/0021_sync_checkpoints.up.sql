-- Kapan satu perangkat terakhir selesai menyinkronkan antreannya. Disimpan per pengguna dan per
-- perangkat (UUID yang dibuat aplikasi), supaya jam "Terakhir sinkron" tidak berubah saat pengguna
-- keluar dari menu atau masuk lagi, dan tidak tercampur dengan perangkat atau akun lain.
CREATE TABLE sync_checkpoints (
  id_user INTEGER NOT NULL,
  device_id TEXT NOT NULL CHECK (length(device_id) = 36),
  last_synced_at INTEGER NOT NULL,
  PRIMARY KEY (id_user, device_id),
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON DELETE CASCADE
);
