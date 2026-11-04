-- Data loss on rollback: detections without a pest have no place in the old shape, and an
-- image attached only to the header is copied to each of its results.
CREATE TABLE hasil_deteksi_salinan AS
SELECT h.id_hasil_deteksi, d.id_pemindahan, COALESCE(d.gambar_url, '') AS gambar, h.nama_hama,
  h.confidence_minor / 10000.0 AS confidence, d.tanggal_deteksi
FROM hasil_deteksi h JOIN deteksi d ON d.id_deteksi = h.id_deteksi;

PRAGMA defer_foreign_keys = ON;
DROP TABLE hasil_deteksi;
DROP TABLE deteksi;

CREATE TABLE hasil_deteksi (
  id_hasil_deteksi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_pemindahan INTEGER NOT NULL,
  gambar TEXT NOT NULL CHECK (length(gambar) <= 255),
  nama_hama TEXT NOT NULL CHECK (length(nama_hama) <= 100),
  confidence DECIMAL(5,4),
  tanggal_deteksi TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_pemindahan) REFERENCES pemindahan (id_pemindahan) ON UPDATE NO ACTION ON DELETE NO ACTION
);

INSERT INTO hasil_deteksi (id_hasil_deteksi, id_pemindahan, gambar, nama_hama, confidence, tanggal_deteksi)
SELECT id_hasil_deteksi, id_pemindahan, gambar, nama_hama, confidence, tanggal_deteksi
FROM hasil_deteksi_salinan;

DROP TABLE hasil_deteksi_salinan;

DELETE FROM sync_resource_versions WHERE resource_type = 'deteksi';
DELETE FROM sync_resource_links WHERE resource_type = 'deteksi';
