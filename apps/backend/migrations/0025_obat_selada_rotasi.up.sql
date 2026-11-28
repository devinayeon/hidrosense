-- Migration 0025: data obat kutu daun dan kutu kebul untuk selada hidroponik NFT, status
-- registrasi Indonesia, rencana rotasi kombinasi, dan alasan penolakan opsional.
-- Dataset dan sumbernya: docs/obat-selada-nft.md, docs/data/obat-selada.csv, docs/data/registri/.

ALTER TABLE obat_katalog ADD COLUMN boleh_direkomendasikan INTEGER NOT NULL DEFAULT 1
  CHECK (boleh_direkomendasikan IN (0, 1));
ALTER TABLE obat_katalog ADD COLUMN status_registrasi TEXT NOT NULL DEFAULT 'belum_diperiksa'
  CHECK (status_registrasi IN ('tercatat_komoditas_lain', 'tidak_ditemukan', 'bukan_pestisida', 'belum_diperiksa'));
ALTER TABLE obat_katalog ADD COLUMN catatan_registrasi TEXT
  CHECK (catatan_registrasi IS NULL OR length(catatan_registrasi) <= 500);

-- Rencana rotasi saat saran dibuat (JSON), supaya riwayat tidak berubah bila katalog berubah.
ALTER TABLE rekomendasi_perawatan ADD COLUMN rencana TEXT
  CHECK (rencana IS NULL OR json_valid(rencana));
-- Alasan menolak boleh kosong. CHECK lama mewajibkan nilai, jadi penolakan tanpa alasan disimpan
-- sebagai 'lainnya' bertanda alasan_diisi = 0 dan dibaca kembali sebagai kosong.
ALTER TABLE rekomendasi_perawatan ADD COLUMN alasan_diisi INTEGER NOT NULL DEFAULT 1
  CHECK (alasan_diisi IN (0, 1));

INSERT INTO moa_groups (kode_moa, nama) VALUES
  ('4D', 'Modulator kompetitif reseptor asetilkolin nikotinik (butenolid)'),
  ('12A', 'Penghambat ATP sintase mitokondria (diafentiuron)'),
  ('16', 'Penghambat biosintesis kitin tipe 1 (buprofezin)'),
  ('36', 'Kelompok 36 (dimpropiridaz)');

INSERT INTO obat_katalog (bahan_aktif, jenis, kode_moa, catatan, sumber) VALUES
  ('Dimpropiridaz', 'kimia', '36',
    'Belum disarankan: tidak ditemukan data masa tunggu panen untuk selada.',
    'https://petani-sejahtera.basf.co.id/insektisida/efficon');

INSERT INTO obat_katalog (bahan_aktif, jenis, kode_moa, phi_hari, phi_sumber, catatan, sumber) VALUES
  ('Flupiradifuron', 'kimia', '4D', 1, 'Label AS untuk selada (UC IPM Lettuce PMG 04/17), semprot daun',
    'Satu keluarga dengan kelompok 4A. Semprot daun saja, jangan masuk larutan nutrisi.',
    'https://ipm.ucanr.edu/pdf/pmg/pmglettuce.pdf'),
  ('Dinotefuran', 'kimia', '4A', 7, 'Label AS untuk selada (UC IPM Lettuce PMG 04/17), semprot daun',
    'Hanya semprot daun. Aplikasi tanah berinterval 21 hari dan tidak untuk larutan nutrisi NFT.',
    'https://ipm.ucanr.edu/pdf/pmg/pmglettuce.pdf'),
  ('Tiametoksam', 'kimia', '4A', 7, 'Label AS untuk selada (UC IPM Lettuce PMG 04/17), semprot daun',
    'Resistensi silang dengan bahan 4A lain. Semprot daun saja, jangan masuk larutan nutrisi.',
    'https://ipm.ucanr.edu/pdf/pmg/pmglettuce.pdf'),
  ('Spiromesifen', 'kimia', '23', 7, 'Label AS untuk selada (UC IPM Lettuce PMG 04/17)',
    'Kutu kebul. Satu kelompok dengan spirotetramat. Semprot daun saja.',
    'https://ipm.ucanr.edu/pdf/pmg/pmglettuce.pdf'),
  ('Diafentiuron', 'kimia', '12A', NULL, NULL,
    'Belum disarankan: tidak ditemukan data masa tunggu panen untuk selada.',
    'https://ap-simpel.pertanian.go.id/pestisida?kategori_formula=pestisida_terdaftar'),
  ('Buprofezin', 'kimia', '16', NULL, NULL,
    'Belum disarankan: tidak ditemukan data masa tunggu panen untuk selada.',
    'https://ap-simpel.pertanian.go.id/pestisida?kategori_formula=pestisida_terdaftar'),
  ('Lecanicillium lecanii', 'hayati', 'UNF', NULL, NULL,
    'Jamur entomopatogen. Studi Indonesia pada cabai dan kedelai; belum diuji pada selada hidroponik.',
    'https://ejournal.unesa.ac.id/index.php/lenterabio/article/view/28434/26014'),
  ('Menochilus sexmaculatus', 'hayati', NULL, NULL, NULL,
    'Kumbang koksi pemangsa kutu daun. Studi Indonesia di luar selada hidroponik.',
    'https://media.neliti.com/media/publications/85300-ID-teknik-perbanyakan-masal-predator-menoch.pdf');

UPDATE obat_katalog SET boleh_direkomendasikan = 0
  WHERE bahan_aktif IN ('Diafentiuron', 'Buprofezin', 'Dimpropiridaz', 'Lambda-sihalotrin', 'Siantraniliprol');

UPDATE obat_katalog SET phi_hari = 0, phi_sumber = 'Label AS untuk selada (UC IPM Lettuce PMG 04/17)'
  WHERE bahan_aktif IN ('Azadirachtin (neem)', 'Sabun insektisida');

INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT k.id_katalog, h.kode_hama FROM obat_katalog k CROSS JOIN hama h
  WHERE h.kode_hama IN ('aphids', 'whitefly')
    AND k.bahan_aktif IN ('Flupiradifuron', 'Tiametoksam', 'Diafentiuron', 'Dimpropiridaz', 'Lecanicillium lecanii');
INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT id_katalog, 'whitefly' FROM obat_katalog
  WHERE bahan_aktif IN ('Dinotefuran', 'Spiromesifen', 'Buprofezin');
INSERT INTO katalog_hama (id_katalog, kode_hama)
  SELECT id_katalog, 'aphids' FROM obat_katalog WHERE bahan_aktif = 'Menochilus sexmaculatus';

-- Status registrasi: database pestisida terdaftar Kementan, diambil 28 November 2026
-- (8.085 produk dan 30 baris perluasan; ringkasan di docs/data/registri/). Tidak ada satu pun entri
-- selada, jadi tidak ada bahan yang boleh disebut terdaftar untuk selada.
UPDATE obat_katalog SET status_registrasi = 'bukan_pestisida'
  WHERE bahan_aktif IN ('Perangkap lengket kuning', 'Perangkap lengket biru', 'Buang daun terserang',
    'Encarsia formosa', 'Eretmocerus eremicus', 'Amblyseius swirskii', 'Aphidius colemani', 'Menochilus sexmaculatus');
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 40 produk (cabai, kentang, jeruk); kutu kebul 4 produk (cabai, melon, tomat); thrips 99 produk (cabai, bawang merah, kentang). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Abamektin';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 10 produk (cabai, terung, apel); kutu kebul 5 produk (cabai, tomat, terung); thrips 9 produk (cabai, tomat, apel). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Asetamiprid';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 2 produk (kelapa, bawang merah); kutu kebul 1 produk (cabai); thrips 3 produk (cabai, bawang putih). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Azadirachtin (neem)';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 3 produk (cabai, kacang panjang); kutu kebul 1 produk (cabai); thrips 2 produk (bawang merah, cabai). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Beauveria bassiana';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 1 produk (kedelai); kutu kebul 2 produk (kedelai); thrips 3 produk (cabai). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Buprofezin';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 2 produk (cabai, apel, semangka); kutu kebul 6 produk (cabai, tomat); thrips 6 produk (cabai, bawang merah, cabai merah). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Diafentiuron';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 1 produk (kentang, cabai); kutu kebul 1 produk (tomat, kentang, cabai). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Dimpropiridaz';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 3 produk (cabai, kacang panjang, tomat); kutu kebul 3 produk (cabai, tomat, kacang panjang); thrips 5 produk (bawang merah, cabai, tomat). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Dinotefuran';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 8 produk (cabai, kacang panjang, tomat); kutu kebul 3 produk (tomat, cabai); thrips 4 produk (bawang merah, cabai). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Flonikamid';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 1 produk (cabai, jeruk, tembakau); kutu kebul 1 produk (cabai, tembakau, terung). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Flupiradifuron';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 38 produk (cabai, kacang panjang, semangka); kutu kebul 7 produk (kedelai, tomat, cabai); thrips 48 produk (cabai, kentang, semangka). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Imidakloprid';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 16 produk (cabai, jagung, kacang panjang); kutu kebul 2 produk (tomat, tembakau); thrips 9 produk (cabai, bawang merah). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Lambda-sihalotrin';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 1 produk (tomat); kutu kebul 1 produk (cabai). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Lecanicillium lecanii';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 1 produk (kacang panjang); thrips 1 produk (cabai). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Metarhizium anisopliae';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 3 produk (cabai); kutu kebul 2 produk (cabai); thrips 1 produk (ketimun). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Pimetrozin';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 4 produk (cabai, tomat, kacang panjang); kutu kebul 6 produk (tomat, cabai, kacang panjang); thrips 6 produk (cabai, tomat, bawang merah). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Siantraniliprol';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 2 produk (cabai); thrips 2 produk (cabai, kentang). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Spinosad';
UPDATE obat_katalog SET status_registrasi = 'tidak_ditemukan',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: tidak ada produk berizin untuk kutu daun, kutu kebul, atau thrips.'
  WHERE bahan_aktif = 'Spiromesifen';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 5 produk (cabai, apel, tomat); kutu kebul 3 produk (tomat, melon, cabai); thrips 6 produk (cabai, semangka, bawang merah). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Spirotetramat';
UPDATE obat_katalog SET status_registrasi = 'tercatat_komoditas_lain',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: kutu daun 13 produk (cabai, jagung, kacang panjang); kutu kebul 4 produk (cabai, tomat); thrips 8 produk (bawang merah, cabai, jeruk). Selada tidak tercantum.'
  WHERE bahan_aktif = 'Tiametoksam';
UPDATE obat_katalog SET status_registrasi = 'tidak_ditemukan',
    catatan_registrasi = 'Registri Kementan 28 Nov 2026: tidak ada produk berizin untuk kutu daun, kutu kebul, atau thrips.'
  WHERE bahan_aktif = 'Sabun insektisida';
