-- HidroSense QA — kueri audit invarian domain (PROMPT §5.8).
--
-- Jalankan terhadap database uji (mis. /tmp/opencode/hsqa/qa.db) setelah
-- serangkaian operasi. Setiap kueri harus mengembalikan NOL baris; satu baris
-- berarti invarian dilanggar.
--
-- Contoh:
--   sqlite3 /tmp/opencode/hsqa/qa.db < mcdocs/audit_queries.sql
-- atau lewat libSQL. Nama kolom/aturan diverifikasi dari migrasi dan kode
-- (apps/backend/src/features/*, src/db/migrations/*).
--
-- Satuan: saldo/minimum/berat disimpan dalam minor (perseratus).

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
-- (Status penyemaian juga menjadi `selesai` saat habis; ini memeriksa angkanya.)
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
       COALESCE(d.rusak, 0) AS rusak,
       COALESCE(h.panen, 0) AS panen
FROM pemindahan p
LEFT JOIN (SELECT id_pemindahan, SUM(jumlah_tanaman) AS rusak FROM kerusakan_tanaman GROUP BY id_pemindahan) d
  ON d.id_pemindahan = p.id_pemindahan
LEFT JOIN (SELECT id_pemindahan, SUM(jumlah_tanaman) AS panen FROM detail_panen GROUP BY id_pemindahan) h
  ON h.id_pemindahan = p.id_pemindahan
WHERE COALESCE(d.rusak, 0) + COALESCE(h.panen, 0) > p.jumlah_tanaman;

-- AQ-09 Berat reject panen tidak boleh melebihi berat total panen.
SELECT id_detail_panen, berat_minor, berat_reject_minor
FROM detail_panen
WHERE berat_reject_minor > berat_minor;

-- AQ-10 Terjual per batch tidak boleh melebihi berat layak (berat - reject).
WITH layak AS (
  SELECT id_panen, SUM(berat_minor - berat_reject_minor) AS layak_minor
  FROM detail_panen GROUP BY id_panen
), jual AS (
  SELECT id_panen, SUM(jumlah_kg_minor) AS dijual_minor
  FROM detail_penjualan GROUP BY id_panen
)
SELECT l.id_panen, l.layak_minor, COALESCE(j.dijual_minor, 0) AS dijual_minor
FROM layak l
LEFT JOIN jual j ON j.id_panen = l.id_panen
WHERE COALESCE(j.dijual_minor, 0) > l.layak_minor;

-- AQ-11 Transaksi pembalik harus menunjuk transaksi asli yang ada dan belum
-- dibalik dua kali.
SELECT r.id_stok AS pembalik, r.reversal_of
FROM stok r
LEFT JOIN stok o ON o.id_stok = r.reversal_of
WHERE r.reversal_of IS NOT NULL AND o.id_stok IS NULL;

SELECT reversal_of, COUNT(*) AS jumlah
FROM stok
WHERE reversal_of IS NOT NULL
GROUP BY reversal_of
HAVING COUNT(*) > 1;

-- AQ-12 Selisih pembalik tidak boleh melebihi jumlah asli per barang.
WITH asli AS (
  SELECT s.reversal_of AS asli, d.id_inventaris, SUM(d.jumlah_minor) AS jumlah
  FROM stok s JOIN detail_stok d ON d.id_stok = s.id_stok
  WHERE s.reversal_of IS NOT NULL GROUP BY s.reversal_of, d.id_inventaris
), dasar AS (
  SELECT d.id_stok AS asli, d.id_inventaris, d.jumlah_minor AS jumlah
  FROM detail_stok d JOIN stok s ON s.id_stok = d.id_stok WHERE s.reversal_of IS NULL
)
SELECT a.asli, a.id_inventaris, a.jumlah AS pembalik, b.jumlah AS asli
FROM asli a JOIN dasar b ON b.asli = a.asli AND b.id_inventaris = a.id_inventaris
WHERE a.jumlah > b.jumlah;

-- AQ-13 Saldo cache yatim (tanpa baris inventaris).
SELECT s.id_inventaris
FROM stok_saldo s
LEFT JOIN inventaris i ON i.id_inventaris = s.id_inventaris
WHERE i.id_inventaris IS NULL;

-- AQ-14 Harga penjualan harus konsisten dengan minor (harga_per_kg_minor > 0).
SELECT id_detail_penjualan, harga_per_kg_minor
FROM detail_penjualan
WHERE harga_per_kg_minor <= 0;

-- AQ-15 Setiap detail_stok menunjuk inventaris yang ada.
SELECT d.id_detail_stok, d.id_inventaris
FROM detail_stok d
LEFT JOIN inventaris i ON i.id_inventaris = d.id_inventaris
WHERE i.id_inventaris IS NULL;
