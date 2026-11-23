-- Migration 0019: deteksi hama, katalog pengetahuan obat, dan rekomendasi rotasi per meja.
--
-- Menyatukan rancangan awal (hasil_deteksi -> rekomendasi_perawatan -> perawatan, belum dipakai
-- kode) dengan kebutuhan baru, bukan membuat tabel paralel:
--   * hasil_deteksi        satu baris per FOTO (bukan per hama); hitungan per kelas ada di deteksi_hama
--   * rekomendasi_perawatan saran sistem; keputusan pengguna final dan dijaga trigger
--   * perawatan            TINDAKAN nyata. Dibuat saat rekomendasi diterima dan menjadi sumber
--                          riwayat rotasi. Tabel ini dipertahankan: stok.id_perawatan merujuknya.
--   * hama, moa_groups     tabel rujukan, menggantikan CHECK yang berulang di tiap tabel
--
-- Katalog (obat_katalog) sengaja terpisah dari `obat`: `obat` adalah master milik pengguna,
-- katalog adalah pengetahuan bawaan. Data katalog berasal dari riset web dan BELUM diverifikasi
-- pakar (terverifikasi = 0); status pendaftaran untuk selada di Indonesia tidak terkonfirmasi.

-- Tiga tabel lama belum dipakai kode. Bila ternyata berisi, hentikan migrasi daripada menghapus data.
CREATE TABLE _guard_0019 (n INTEGER NOT NULL CHECK (n = 0));
INSERT INTO _guard_0019 SELECT
  (SELECT COUNT(*) FROM perawatan) + (SELECT COUNT(*) FROM rekomendasi_perawatan) + (SELECT COUNT(*) FROM hasil_deteksi);
DROP TABLE _guard_0019;
DROP TABLE rekomendasi_perawatan;
DROP TABLE hasil_deteksi;

CREATE TABLE hama (
  kode_hama TEXT PRIMARY KEY CHECK (length(kode_hama) BETWEEN 1 AND 30),
  nama TEXT NOT NULL CHECK (length(nama) <= 100),
  -- Indeks kelas pada keluaran model (ml/artifacts/labels.txt).
  indeks_model INTEGER NOT NULL UNIQUE CHECK (indeks_model >= 0)
);
INSERT INTO hama (kode_hama, nama, indeks_model) VALUES
  ('thrips', 'Thrips', 0), ('whitefly', 'Kutu kebul', 1), ('aphids', 'Kutu daun', 2);

CREATE TABLE moa_groups (
  kode_moa TEXT PRIMARY KEY CHECK (length(kode_moa) BETWEEN 1 AND 10),
  nama TEXT NOT NULL CHECK (length(nama) <= 150)
);

CREATE TABLE obat_katalog (
  id_katalog INTEGER PRIMARY KEY AUTOINCREMENT,
  bahan_aktif TEXT NOT NULL UNIQUE CHECK (length(bahan_aktif) BETWEEN 1 AND 100),
  jenis TEXT NOT NULL CHECK (jenis IN ('mekanis', 'hayati', 'nabati', 'kimia')),
  kode_moa TEXT REFERENCES moa_groups (kode_moa),
  phi_hari INTEGER CHECK (phi_hari IS NULL OR phi_hari BETWEEN 0 AND 365),
  catatan TEXT CHECK (catatan IS NULL OR length(catatan) <= 500),
  sumber TEXT NOT NULL CHECK (length(sumber) <= 300),
  terverifikasi INTEGER NOT NULL DEFAULT 0 CHECK (terverifikasi IN (0, 1)),
  -- Cara mekanis tidak punya MoA; bahan kimia wajib punya.
  CHECK (jenis <> 'kimia' OR kode_moa IS NOT NULL),
  CHECK (jenis <> 'mekanis' OR kode_moa IS NULL)
);

CREATE TABLE katalog_hama (
  id_katalog INTEGER NOT NULL REFERENCES obat_katalog (id_katalog) ON DELETE CASCADE,
  kode_hama TEXT NOT NULL REFERENCES hama (kode_hama),
  PRIMARY KEY (id_katalog, kode_hama)
);
CREATE INDEX idx_katalog_hama_hama ON katalog_hama (kode_hama);

CREATE TABLE hasil_deteksi (
  id_hasil_deteksi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_pemindahan INTEGER NOT NULL REFERENCES pemindahan (id_pemindahan),
  id_user INTEGER NOT NULL REFERENCES users (id_user),
  gambar TEXT NOT NULL CHECK (length(gambar) <= 500 AND gambar LIKE 'https://%'),
  cloudinary_public_id TEXT CHECK (cloudinary_public_id IS NULL OR length(cloudinary_public_id) <= 255),
  versi_model TEXT NOT NULL CHECK (length(versi_model) BETWEEN 1 AND 60),
  tanggal_deteksi TEXT NOT NULL
);
CREATE INDEX idx_hasil_deteksi_pemindahan
  ON hasil_deteksi (id_pemindahan, tanggal_deteksi DESC, id_hasil_deteksi DESC);

CREATE TABLE deteksi_hama (
  id_hasil_deteksi INTEGER NOT NULL REFERENCES hasil_deteksi (id_hasil_deteksi) ON DELETE CASCADE,
  kode_hama TEXT NOT NULL REFERENCES hama (kode_hama),
  jumlah INTEGER NOT NULL CHECK (jumlah BETWEEN 1 AND 100000),
  confidence_maks REAL CHECK (confidence_maks IS NULL OR confidence_maks BETWEEN 0 AND 1),
  PRIMARY KEY (id_hasil_deteksi, kode_hama)
);
CREATE INDEX idx_deteksi_hama_hama ON deteksi_hama (kode_hama);

CREATE TABLE rekomendasi_perawatan (
  id_rekomendasi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_meja INTEGER NOT NULL REFERENCES meja_tanam (id_meja),
  -- Foto asal rekomendasi. Null bila dibuat tanpa foto.
  id_hasil_deteksi INTEGER REFERENCES hasil_deteksi (id_hasil_deteksi),
  kode_hama TEXT NOT NULL REFERENCES hama (kode_hama),
  tingkat TEXT NOT NULL CHECK (tingkat IN ('ringan', 'sedang', 'berat')),
  id_katalog INTEGER NOT NULL REFERENCES obat_katalog (id_katalog),
  -- Salinan MoA saat direkomendasikan, supaya riwayat tetap benar bila katalog berubah.
  kode_moa TEXT REFERENCES moa_groups (kode_moa),
  rule_id TEXT NOT NULL CHECK (length(rule_id) <= 30),
  alasan TEXT NOT NULL CHECK (length(alasan) <= 500),
  status_rekomendasi TEXT NOT NULL DEFAULT 'menunggu'
    CHECK (status_rekomendasi IN ('menunggu', 'diterima', 'ditolak')),
  alasan_penolakan TEXT CHECK (alasan_penolakan IS NULL OR alasan_penolakan IN
    ('tidak_tersedia', 'harga', 'sudah_ditangani', 'tidak_yakin_hama', 'lainnya')),
  catatan_penolakan TEXT CHECK (catatan_penolakan IS NULL OR length(catatan_penolakan) <= 500),
  id_user INTEGER NOT NULL REFERENCES users (id_user),
  tanggal_rekomendasi TEXT NOT NULL,
  tanggal_keputusan TEXT,
  CHECK (
    (status_rekomendasi = 'menunggu' AND alasan_penolakan IS NULL AND catatan_penolakan IS NULL AND tanggal_keputusan IS NULL)
    OR (status_rekomendasi = 'diterima' AND alasan_penolakan IS NULL AND catatan_penolakan IS NULL AND tanggal_keputusan IS NOT NULL)
    OR (status_rekomendasi = 'ditolak' AND alasan_penolakan IS NOT NULL AND tanggal_keputusan IS NOT NULL
        AND (alasan_penolakan <> 'lainnya' OR length(trim(COALESCE(catatan_penolakan, ''))) > 0))
  )
);

-- Satu rekomendasi menunggu per meja dan hama: ketuk ganda tidak membuat duplikat.
CREATE UNIQUE INDEX uq_rekomendasi_menunggu
  ON rekomendasi_perawatan (id_meja, kode_hama) WHERE status_rekomendasi = 'menunggu';
CREATE INDEX idx_rekomendasi_meja_status
  ON rekomendasi_perawatan (id_meja, status_rekomendasi, tanggal_rekomendasi DESC, id_rekomendasi DESC);
CREATE INDEX idx_rekomendasi_hasil_deteksi
  ON rekomendasi_perawatan (id_hasil_deteksi) WHERE id_hasil_deteksi IS NOT NULL;

-- Keputusan bersifat final dan riwayatnya tidak dihapus: dijaga di database, bukan hanya di service.
CREATE TRIGGER trg_rekomendasi_final_update BEFORE UPDATE ON rekomendasi_perawatan
  WHEN OLD.status_rekomendasi <> 'menunggu'
BEGIN
  SELECT RAISE(ABORT, 'rekomendasi yang sudah diputuskan tidak boleh diubah');
END;
CREATE TRIGGER trg_rekomendasi_final_delete BEFORE DELETE ON rekomendasi_perawatan
  WHEN OLD.status_rekomendasi <> 'menunggu'
BEGIN
  SELECT RAISE(ABORT, 'riwayat rekomendasi yang sudah diputuskan tidak boleh dihapus');
END;

-- perawatan dipertahankan (stok.id_perawatan merujuknya). Diperketat: satu tindakan per rekomendasi,
-- hanya untuk rekomendasi yang diterima, dan tanggal berbentuk YYYY-MM-DD.
CREATE UNIQUE INDEX uq_perawatan_rekomendasi ON perawatan (id_rekomendasi);
CREATE TRIGGER trg_perawatan_valid BEFORE INSERT ON perawatan
BEGIN
  SELECT RAISE(ABORT, 'perawatan hanya untuk rekomendasi yang diterima')
  WHERE NOT EXISTS (
    SELECT 1 FROM rekomendasi_perawatan
    WHERE id_rekomendasi = NEW.id_rekomendasi AND status_rekomendasi = 'diterima');
  SELECT RAISE(ABORT, 'tanggal_perawatan harus berbentuk YYYY-MM-DD')
  WHERE NEW.tanggal_perawatan NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]';
END;

INSERT INTO moa_groups (kode_moa, nama) VALUES
  ('3A', 'Modulator kanal natrium (piretroid)'),
  ('4A', 'Modulator kompetitif reseptor asetilkolin nikotinik (neonikotinoid)'),
  ('5', 'Modulator alosterik reseptor asetilkolin nikotinik (spinosin)'),
  ('6', 'Modulator alosterik kanal klorida berpintu glutamat (avermektin)'),
  ('9B', 'Modulator kanal TRPV organ kordotonal'),
  ('23', 'Penghambat asetil-KoA karboksilase (asam tetronat dan tetramat)'),
  ('28', 'Modulator reseptor ryanodin (diamida)'),
  ('29', 'Modulator organ kordotonal, target tidak dispesifikasi (flonikamid)'),
  ('UN', 'Mekanisme kerja tidak diketahui (azadirachtin)'),
  ('UNF', 'Agen jamur dengan mekanisme kerja tidak diketahui'),
  ('UNM', 'Pengganggu fisik nonspesifik (sabun, minyak)');

INSERT INTO obat_katalog (bahan_aktif, jenis, kode_moa, catatan, sumber) VALUES
  ('Perangkap lengket kuning', 'mekanis', NULL, 'Pemantauan dan penekanan kutu kebul dan kutu daun bersayap.', 'Praktik PHT umum (UC IPM, UF IFAS)'),
  ('Perangkap lengket biru', 'mekanis', NULL, 'Pemantauan dan penekanan thrips.', 'Praktik PHT umum (UC IPM, UF IFAS)'),
  ('Buang daun terserang', 'mekanis', NULL, 'Pangkas dan buang daun berkoloni, jangan dibuang ke area tanam.', 'Praktik PHT umum'),
  ('Encarsia formosa', 'hayati', NULL, 'Parasitoid kutu kebul, dilepas sebagai pupa terparasit.', 'https://pestadvisories.usu.edu/2020/03/26/greenhouse-pests/'),
  ('Eretmocerus eremicus', 'hayati', NULL, 'Parasitoid kutu kebul.', 'https://pestadvisories.usu.edu/2020/03/26/greenhouse-pests/'),
  ('Amblyseius swirskii', 'hayati', NULL, 'Tungau predator: telur dan nimfa kutu kebul, serta thrips.', 'https://pestadvisories.usu.edu/2020/03/26/greenhouse-pests/'),
  ('Aphidius colemani', 'hayati', NULL, 'Parasitoid kutu daun. Ketersediaan di Indonesia perlu diverifikasi.', 'Pengetahuan umum PHT; belum ada sumber web yang dikonfirmasi'),
  ('Beauveria bassiana', 'hayati', 'UNF', 'Jamur entomopatogen. Studi Indonesia pada thrips cabai; konsentrasi 10^8 spora/ml terbaik. Belum diuji pada selada hidroponik.', 'https://jurnal.unej.ac.id/index.php/BIP/article/view/38197'),
  ('Metarhizium anisopliae', 'hayati', 'UNF', 'Jamur entomopatogen. Pada thrips cabai kurang efektif dibanding Beauveria. Belum diuji pada selada hidroponik.', 'https://jurnal.unej.ac.id/index.php/BIP/article/view/38197'),
  ('Sabun insektisida', 'nabati', 'UNM', 'Efektif untuk tahap muda; semprot kena langsung. Cek label produk.', 'https://ucanr.edu/node/109663'),
  ('Azadirachtin (neem)', 'nabati', 'UN', 'Bersifat insektisida, penolak, dan antifeedant pada thrips.', 'https://ucanr.edu/node/109663'),
  ('Spinosad', 'kimia', '5', 'Sangat efektif pada thrips; pemakaian berlebihan memicu resistensi.', 'https://ucanr.edu/node/109663'),
  ('Abamektin', 'kimia', '6', 'Contoh rotasi thrips: kelompok 6.', 'https://utia.tennessee.edu/publications/wp-content/uploads/sites/269/2023/10/W415.pdf'),
  ('Lambda-sihalotrin', 'kimia', '3A', 'Piretroid tidak lagi disarankan sebagai pilihan utama: resistensi dan merusak musuh alami.', 'https://canr.msu.edu/resources/greenhouse-insecticides'),
  ('Imidakloprid', 'kimia', '4A', 'Resistensi silang dengan asetamiprid (sama-sama 4A).', 'https://utia.tennessee.edu/publications/wp-content/uploads/sites/269/2023/10/W415.pdf'),
  ('Asetamiprid', 'kimia', '4A', 'Resistensi silang dengan imidakloprid (sama-sama 4A).', 'https://utia.tennessee.edu/publications/wp-content/uploads/sites/269/2023/10/W415.pdf'),
  ('Spirotetramat', 'kimia', '23', 'Produk Movento tercatat untuk kutu kebul, trips, kutu daun; selada tidak tercantum pada label yang ditemukan.', 'https://www.bayer.com/en/id/movento'),
  ('Flonikamid', 'kimia', '29', 'Kutu daun dan kutu kebul. Kelompok 29 pada IRAC v11.3 (sebelumnya tercatat 9C).', 'https://irac-online.org/documents/moa-brochure'),
  ('Pimetrozin', 'kimia', '9B', 'Menghambat makan kutu daun dan kutu kebul. Kode 9B belum terkonfirmasi pada skema IRAC terbaru.', 'https://irac-online.org/documents/sucking-pests-moa-poster/?ext=pdf'),
  ('Siantraniliprol', 'kimia', '28', 'Pendaftaran untuk sayuran daun perlu diverifikasi.', 'Pengetahuan umum IRAC; belum ada sumber web yang dikonfirmasi');

INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT k.id_katalog, h.kode_hama
  FROM obat_katalog k CROSS JOIN hama h
  WHERE k.bahan_aktif IN ('Buang daun terserang', 'Sabun insektisida', 'Azadirachtin (neem)', 'Beauveria bassiana',
    'Spirotetramat', 'Imidakloprid', 'Siantraniliprol');
INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT id_katalog, 'whitefly' FROM obat_katalog WHERE bahan_aktif IN
    ('Perangkap lengket kuning', 'Encarsia formosa', 'Eretmocerus eremicus', 'Amblyseius swirskii',
     'Asetamiprid', 'Pimetrozin', 'Flonikamid');
INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT id_katalog, 'aphids' FROM obat_katalog WHERE bahan_aktif IN
    ('Perangkap lengket kuning', 'Aphidius colemani', 'Lambda-sihalotrin', 'Asetamiprid', 'Pimetrozin', 'Flonikamid');
INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT id_katalog, 'thrips' FROM obat_katalog WHERE bahan_aktif IN
    ('Perangkap lengket biru', 'Amblyseius swirskii', 'Spinosad', 'Abamektin', 'Lambda-sihalotrin', 'Metarhizium anisopliae');
