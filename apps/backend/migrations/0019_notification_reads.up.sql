-- Simpan status baca notifikasi per pengguna agar "Tandai semua dibaca"
-- bertahan lintas perangkat dan sesi.
CREATE TABLE notification_reads (
  id_user INTEGER NOT NULL,
  notification_key TEXT NOT NULL CHECK (length(notification_key) <= 120),
  read_at INTEGER NOT NULL,
  PRIMARY KEY (id_user, notification_key),
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE INDEX idx_notification_reads_user ON notification_reads (id_user);
