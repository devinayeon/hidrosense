-- HidroSense QA — kueri audit invarian domain (PROMPT §5.8, §5.2).
--
-- Jalankan terhadap database uji (mis. /tmp/opencode/hsqa/qa.db) setelah
-- serangkaian operasi. Setiap kueri harus mengembalikan NOL baris; satu baris
-- berarti invarian dilanggar.
--
-- Contoh:
--   sqlite3 -header /tmp/opencode/hsqa/qa.db < qa/audit_queries.sql
--
-- Nama kolom/aturan diverifikasi dari migrasi dan kode (apps/backend/src/features/*,
-- apps/backend/migrations/*). Satuan: saldo/minimum/berat disimpan dalam minor
-- (perseratus).

-- === Bagian A: inventaris, meja, panen, penjualan (AQ-01..AQ-15) ===

-- AQ-01 Saldo cache di luar rentang yang dijaga appendMovement [0, 999999999999].
SELECT id_inventaris, saldo_minor
FROM stok_saldo
WHERE saldo_minor < 0 OR saldo_minor > 999999999999;

-- AQ-02 Cache saldo harus sama dengan jumlah buku besar (masuk - keluar).
WITH ledger AS (
  SELECT d.id_inventaris,
         SUM(CASE WHEN s.jenis_stok = 'masuk' THEN d.jumlah_minor ELSE -d.jumlah_minor END) AS hitung
  FROM detail_stok d
  JOIN stok s ON s.id_stok = d.id_stok
  GROUP BY d.id_inventaris
)
SELECT l.id_inventaris, l.hitung AS buku_besar, s.saldo_minor AS cache
FROM ledger l
JOIN stok_saldo s ON s.id_inventaris = l.id_inventaris
WHERE l.hitung <> s.saldo_minor;

-- AQ-03 Setiap transaksi stok harus sudah tersegel (sealed=1); baris sealed=0
-- berarti transaksi tulis tidak selesai.
SELECT id_stok, sealed
FROM stok
WHERE sealed <> 1;

-- AQ-04 Tanaman aktif per meja (rumus sama dengan tables/store.ts) harus
-- berada di [0, jumlah_lubang].
WITH hitung AS (
  SELECT m.id_meja, m.jumlah_lubang,
         COALESCE((
           SELECT SUM(p.jumlah_tanaman
             - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan = p.id_pemindahan), 0)
             - COALESCE((SELECT SUM(dp.jumlah_tanaman) FROM detail_panen dp WHERE dp.id_pemindahan = p.id_pemindahan), 0))
           FROM pemindahan p WHERE p.id_meja = m.id_meja
         ), 0) AS tanaman_aktif
  FROM meja_tanam m
)
SELECT id_meja, tanaman_aktif, jumlah_lubang
FROM hitung
WHERE tanaman_aktif < 0 OR tanaman_aktif > jumlah_lubang;

-- AQ-05 Status meja tersedia/penuh harus cocok dengan okupansi nyata.
WITH hitung AS (
  SELECT m.id_meja, m.status_meja, m.jumlah_lubang,
         COALESCE((
           SELECT SUM(p.jumlah_tanaman
             - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan = p.id_pemindahan), 0)
             - COALESCE((SELECT SUM(dp.jumlah_tanaman) FROM detail_panen dp WHERE dp.id_pemindahan = p.id_pemindahan), 0))
           FROM pemindahan p WHERE p.id_meja = m.id_meja
         ), 0) AS tanaman_aktif
  FROM meja_tanam m
)
SELECT id_meja, status_meja, tanaman_aktif, jumlah_lubang
FROM hitung
WHERE lower(status_meja) IN ('tersedia', 'penuh')
  AND ((lower(status_meja) = 'penuh' AND tanaman_aktif < jumlah_lubang)
    OR (lower(status_meja) = 'tersedia' AND tanaman_aktif >= jumlah_lubang));

-- AQ-06 Benih yang dipindah tidak boleh melebihi jumlah benih penyemaian.
SELECT p.id_penyemaian, s.jumlah_benih, SUM(p.jumlah_tanaman) AS dipindah
FROM pemindahan p
JOIN penyemaian s ON s.id_penyemaian = p.id_penyemaian
GROUP BY p.id_penyemaian, s.jumlah_benih
HAVING SUM(p.jumlah_tanaman) > s.jumlah_benih;

-- AQ-07 Panen tidak boleh melebihi jumlah yang dipindah ke satu batch.
SELECT dp.id_detail_panen, dp.jumlah_tanaman AS dipanen, p.jumlah_tanaman AS dipindah
FROM detail_panen dp
JOIN pemindahan p ON p.id_pemindahan = dp.id_pemindahan
WHERE dp.jumlah_tanaman > p.jumlah_tanaman;

-- AQ-08 Kerusakan + panen tidak boleh melebihi tanaman pada satu batch.
SELECT p.id_pemindahan, p.jumlah_tanaman,
       COALESCE(d.rusak, 0) AS rusak, COALESCE(h.panen, 0) AS panen
FROM pemindahan p
LEFT JOIN (SELECT id_pemindahan, SUM(jumlah_tanaman) AS rusak FROM kerusakan_tanaman GROUP BY id_pemindahan) d
  ON d.id_pemindahan = p.id_pemindahan
LEFT JOIN (SELECT id_pemindahan, SUM(jumlah_tanaman) AS panen FROM detail_panen GROUP BY id_pemindahan) h
  ON h.id_pemindahan = p.id_pemindahan
WHERE COALESCE(d.rusak, 0) + COALESCE(h.panen, 0) > p.jumlah_tanaman;

-- AQ-09 Cache berat (minor) harus konsisten dengan kolom DECIMAL-nya, dan
-- NULL harus muncul berpasangan (baris warisan kedua kolom kosong).
--
-- Catatan semantik (diverifikasi dari harvest/service.ts): `berat`/`berat_minor`
-- menyimpan BERAT LAYAK (total - reject), bukan berat total; reject tersimpan
-- sendiri di `berat_reject_minor`. Karena itu `berat_minor` setara `berat * 100`.
SELECT id_detail_panen, berat, berat_minor, berat_reject_minor
FROM detail_panen
WHERE (berat_minor IS NULL) <> (berat_reject_minor IS NULL)
   OR (berat_minor IS NOT NULL AND berat_minor <> CAST(ROUND(berat * 100) AS INTEGER));

-- AQ-10 Terjual per batch tidak boleh melebihi berat layak. Berat layak = SUM(berat_minor)
-- (lihat catatan AQ-09; JANGAN mengurangi berat_reject_minor lagi).
WITH layak AS (
  SELECT id_panen, SUM(berat_minor) AS layak_minor
  FROM detail_panen GROUP BY id_panen
), jual AS (
  SELECT id_panen, SUM(jumlah_kg_minor) AS dijual_minor
  FROM detail_penjualan GROUP BY id_panen
)
SELECT l.id_panen, l.layak_minor, COALESCE(j.dijual_minor, 0) AS dijual_minor
FROM layak l LEFT JOIN jual j ON j.id_panen = l.id_panen
WHERE COALESCE(j.dijual_minor, 0) > l.layak_minor;

-- AQ-11 Transaksi pembalik harus menunjuk transaksi asli yang ada.
SELECT r.id_stok AS pembalik, r.reversal_of
FROM stok r LEFT JOIN stok o ON o.id_stok = r.reversal_of
WHERE r.reversal_of IS NOT NULL AND o.id_stok IS NULL;

-- AQ-12 Satu transaksi tidak boleh dibalik lebih dari sekali.
SELECT reversal_of, COUNT(*) AS jumlah
FROM stok WHERE reversal_of IS NOT NULL
GROUP BY reversal_of HAVING COUNT(*) > 1;

-- AQ-13 Saldo cache yatim (tanpa baris inventaris).
SELECT s.id_inventaris
FROM stok_saldo s LEFT JOIN inventaris i ON i.id_inventaris = s.id_inventaris
WHERE i.id_inventaris IS NULL;

-- AQ-14 Harga penjualan harus konsisten dengan minor (harga_per_kg_minor > 0).
SELECT id_detail_penjualan, harga_per_kg_minor
FROM detail_penjualan WHERE harga_per_kg_minor <= 0;

-- AQ-15 Setiap detail_stok menunjuk inventaris yang ada.
SELECT d.id_detail_stok, d.id_inventaris
FROM detail_stok d LEFT JOIN inventaris i ON i.id_inventaris = d.id_inventaris
WHERE i.id_inventaris IS NULL;

-- === Bagian B: deteksi hama & katalog obat (migrasi 0019) ===

-- AQ-16 Setiap baris deteksi_hama menunjuk foto yang ada (tanpa anak yatim).
SELECT dh.id_hasil_deteksi, dh.kode_hama
FROM deteksi_hama dh
LEFT JOIN hasil_deteksi h ON h.id_hasil_deteksi = dh.id_hasil_deteksi
WHERE h.id_hasil_deteksi IS NULL;

-- AQ-17 Confidence di luar rentang 0..1 (CHECK ada di skema; ini menahan
-- regresi bila constraint terlepas dari jalur tulis mana pun).
SELECT id_hasil_deteksi, kode_hama, confidence_maks
FROM deteksi_hama
WHERE confidence_maks IS NOT NULL AND (confidence_maks < 0 OR confidence_maks > 1);

-- AQ-18 Foto harus menunjuk pemindahan yang ada, dan URL-nya https.
SELECT id_hasil_deteksi, id_pemindahan, gambar
FROM hasil_deteksi
WHERE gambar NOT LIKE 'https://%'
   OR id_pemindahan NOT IN (SELECT id_pemindahan FROM pemindahan);

-- AQ-19 Deteksi per kelas tidak boleh nol atau negatif, dan kode hama harus
-- terdaftar di tabel hama.
SELECT dh.id_hasil_deteksi, dh.kode_hama, dh.jumlah
FROM deteksi_hama dh
LEFT JOIN hama h ON h.kode_hama = dh.kode_hama
WHERE dh.jumlah < 1 OR h.kode_hama IS NULL;

-- AQ-20 Katalog obat: bahan kimia wajib punya MoA yang terdaftar; mekanis wajib
-- tanpa MoA; kode MoA harus ada di moa_groups.
SELECT k.id_katalog, k.bahan_aktif, k.jenis, k.kode_moa
FROM obat_katalog k
LEFT JOIN moa_groups m ON m.kode_moa = k.kode_moa
WHERE (k.jenis = 'kimia' AND (k.kode_moa IS NULL OR m.kode_moa IS NULL))
   OR (k.jenis = 'mekanis' AND k.kode_moa IS NOT NULL)
   OR (k.kode_moa IS NOT NULL AND m.kode_moa IS NULL);

-- AQ-21 Setiap baris katalog_hama menunjuk katalog & hama yang ada.
SELECT kh.id_katalog, kh.kode_hama
FROM katalog_hama kh
LEFT JOIN obat_katalog k ON k.id_katalog = kh.id_katalog
LEFT JOIN hama h ON h.kode_hama = kh.kode_hama
WHERE k.id_katalog IS NULL OR h.kode_hama IS NULL;

-- === Bagian C: rekomendasi rotasi & perawatan ===

-- AQ-22 Status rekomendasi harus konsisten: menunggu tanpa keputusan; diterima/
-- ditolak selalu punya tanggal_keputusan; ditolak selalu punya alasan.
SELECT id_rekomendasi, status_rekomendasi, alasan_penolakan, tanggal_keputusan
FROM rekomendasi_perawatan
WHERE (status_rekomendasi = 'menunggu'
        AND (tanggal_keputusan IS NOT NULL OR alasan_penolakan IS NOT NULL))
   OR (status_rekomendasi IN ('diterima', 'ditolak') AND tanggal_keputusan IS NULL)
   OR (status_rekomendasi = 'ditolak' AND alasan_penolakan IS NULL);

-- AQ-23 Aturan "satu saran menunggu per (meja, hama)" dijaga indeks unik; ini
-- menahan regresi bila indeks terlepas.
SELECT id_meja, kode_hama, COUNT(*) AS jumlah
FROM rekomendasi_perawatan
WHERE status_rekomendasi = 'menunggu'
GROUP BY id_meja, kode_hama HAVING COUNT(*) > 1;

-- AQ-24 Rekomendasi menunjuk meja/hama/katalog yang ada; foto, bila ada, harus
-- milik meja yang sama (aturan DETECTION_TABLE_MISMATCH).
SELECT r.id_rekomendasi, r.id_meja, r.id_hasil_deteksi
FROM rekomendasi_perawatan r
LEFT JOIN meja_tanam m ON m.id_meja = r.id_meja
LEFT JOIN hama h ON h.kode_hama = r.kode_hama
LEFT JOIN obat_katalog k ON k.id_katalog = r.id_katalog
WHERE m.id_meja IS NULL OR h.kode_hama IS NULL OR k.id_katalog IS NULL
   OR (r.id_hasil_deteksi IS NOT NULL AND r.id_hasil_deteksi NOT IN (
         SELECT hd.id_hasil_deteksi FROM hasil_deteksi hd WHERE hd.id_pemindahan IN (
           SELECT p.id_pemindahan FROM pemindahan p WHERE p.id_meja = r.id_meja)));

-- AQ-25 Setiap perawatan menunjuk rekomendasi yang berstatus 'diterima'
-- (trigger ada; ini menahan regresi).
SELECT p.id_perawatan, p.id_rekomendasi, r.status_rekomendasi
FROM perawatan p
LEFT JOIN rekomendasi_perawatan r ON r.id_rekomendasi = p.id_rekomendasi
WHERE r.id_rekomendasi IS NULL OR r.status_rekomendasi <> 'diterima';

-- AQ-26 Satu rekomendasi hanya boleh punya satu perawatan.
SELECT id_rekomendasi, COUNT(*) AS jumlah
FROM perawatan GROUP BY id_rekomendasi HAVING COUNT(*) > 1;

-- AQ-27 Setiap rekomendasi bertingkat 'berat' yang diterima harus punya perawatan
-- (diterima = tindakan nyata; tanpa perawatan berarti stok tak terpotong).
SELECT r.id_rekomendasi, r.status_rekomendasi
FROM rekomendasi_perawatan r
LEFT JOIN perawatan p ON p.id_rekomendasi = r.id_rekomendasi
WHERE r.status_rekomendasi = 'diterima' AND p.id_perawatan IS NULL;

-- AQ-28 Mutasi stok yang berasal dari perawatan harus menunjuk perawatan yang ada.
SELECT s.id_stok, s.id_perawatan
FROM stok s LEFT JOIN perawatan p ON p.id_perawatan = s.id_perawatan
WHERE s.id_perawatan IS NOT NULL AND p.id_perawatan IS NULL;
