-- One detection is one scanned image; it can hold several pests, or none when the model found
-- nothing or failed. hasil_deteksi keeps its ids because rekomendasi_perawatan refers to them.
CREATE TABLE deteksi (
  id_deteksi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_pemindahan INTEGER NOT NULL,
  -- NULL only for rows that predate this migration.
  id_user INTEGER,
  tanggal_deteksi TEXT NOT NULL,
  status_deteksi TEXT NOT NULL CHECK (status_deteksi IN ('terdeteksi', 'tanpa_deteksi', 'gagal')),
  model_versi TEXT NOT NULL CHECK (length(model_versi) BETWEEN 1 AND 50),
  ambang_confidence_minor INTEGER CHECK (ambang_confidence_minor IS NULL OR ambang_confidence_minor BETWEEN 0 AND 10000),
  gambar_public_id TEXT CHECK (gambar_public_id IS NULL OR length(gambar_public_id) <= 200),
  gambar_url TEXT CHECK (gambar_url IS NULL OR length(gambar_url) <= 255),
  keterangan TEXT CHECK (keterangan IS NULL OR length(keterangan) <= 1000),
  FOREIGN KEY (id_pemindahan) REFERENCES pemindahan (id_pemindahan) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE NO ACTION
);

INSERT INTO deteksi (id_deteksi, id_pemindahan, tanggal_deteksi, status_deteksi, model_versi, gambar_url)
SELECT id_hasil_deteksi, id_pemindahan, tanggal_deteksi, 'terdeteksi', 'legacy', NULLIF(gambar, '')
FROM hasil_deteksi;

CREATE TABLE hasil_deteksi_salinan AS SELECT * FROM hasil_deteksi;

-- The runner keeps foreign_keys ON. Deferring lets rekomendasi_perawatan wait for its parent
-- rows, which return under the same name and ids before the transaction commits.
PRAGMA defer_foreign_keys = ON;
DROP TABLE hasil_deteksi;

CREATE TABLE hasil_deteksi (
  id_hasil_deteksi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_deteksi INTEGER NOT NULL,
  nama_hama TEXT NOT NULL CHECK (length(nama_hama) BETWEEN 1 AND 100),
  -- NULL only for rows that predate this migration.
  confidence_minor INTEGER CHECK (confidence_minor IS NULL OR confidence_minor BETWEEN 0 AND 10000),
  jumlah_objek INTEGER NOT NULL DEFAULT 1 CHECK (jumlah_objek > 0),
  UNIQUE (id_deteksi, nama_hama),
  FOREIGN KEY (id_deteksi) REFERENCES deteksi (id_deteksi) ON UPDATE NO ACTION ON DELETE NO ACTION
);

INSERT INTO hasil_deteksi (id_hasil_deteksi, id_deteksi, nama_hama, confidence_minor)
SELECT id_hasil_deteksi, id_hasil_deteksi, nama_hama, CAST(ROUND(confidence * 10000) AS INTEGER)
FROM hasil_deteksi_salinan;

DROP TABLE hasil_deteksi_salinan;

CREATE INDEX idx_deteksi_batch ON deteksi (id_pemindahan, tanggal_deteksi DESC, id_deteksi DESC);
CREATE INDEX idx_deteksi_date ON deteksi (tanggal_deteksi DESC, id_deteksi DESC);
