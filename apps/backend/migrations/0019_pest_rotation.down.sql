-- Mengembalikan rancangan awal (0001): hasil_deteksi dan rekomendasi_perawatan lama, perawatan
-- tanpa pengetatan. Data deteksi, rekomendasi, dan perawatan hasil fitur ini ikut hilang.
-- Bila ada baris stok yang merujuk perawatan (stok.id_perawatan), DELETE di bawah gagal karena
-- foreign key. Itu disengaja: rollback tidak boleh diam-diam merusak buku besar stok.
DROP TRIGGER IF EXISTS trg_perawatan_valid;
DROP INDEX IF EXISTS uq_perawatan_rekomendasi;
DELETE FROM perawatan;
DROP TRIGGER IF EXISTS trg_rekomendasi_final_delete;
DROP TRIGGER IF EXISTS trg_rekomendasi_final_update;
DROP TABLE IF EXISTS rekomendasi_perawatan;
DROP TABLE IF EXISTS deteksi_hama;
DROP TABLE IF EXISTS hasil_deteksi;
DROP TABLE IF EXISTS katalog_hama;
DROP TABLE IF EXISTS obat_katalog;
DROP TABLE IF EXISTS moa_groups;
DROP TABLE IF EXISTS hama;

CREATE TABLE hasil_deteksi (
  id_hasil_deteksi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_pemindahan INTEGER NOT NULL,
  gambar TEXT NOT NULL CHECK (length(gambar) <= 255),
  nama_hama TEXT NOT NULL CHECK (length(nama_hama) <= 100),
  confidence DECIMAL(5,4),
  tanggal_deteksi TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_pemindahan) REFERENCES pemindahan (id_pemindahan) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE rekomendasi_perawatan (
  id_rekomendasi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_hasil_deteksi INTEGER NOT NULL,
  id_obat INTEGER NOT NULL,
  tanggal_rekomendasi TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status_rekomendasi TEXT NOT NULL DEFAULT 'menunggu' CHECK (length(status_rekomendasi) <= 20),
  alasan_penolakan TEXT,
  FOREIGN KEY (id_hasil_deteksi) REFERENCES hasil_deteksi (id_hasil_deteksi) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_obat) REFERENCES obat (id_obat) ON UPDATE NO ACTION ON DELETE NO ACTION
);
