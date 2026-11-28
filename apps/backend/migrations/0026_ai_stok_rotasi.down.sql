DROP TABLE merek_bahan;
DROP TABLE merek_obat;
ALTER TABLE rekomendasi_perawatan DROP COLUMN tingkat_model;
UPDATE hama SET indeks_model = indeks_model + 100;
UPDATE hama SET indeks_model = 0 WHERE kode_hama = 'thrips';
UPDATE hama SET indeks_model = 1 WHERE kode_hama = 'whitefly';
UPDATE hama SET indeks_model = 2 WHERE kode_hama = 'aphids';
ALTER TABLE hama DROP COLUMN ambang_berat;
ALTER TABLE hama DROP COLUMN ambang_sedang;
