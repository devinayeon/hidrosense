-- Gagal dengan sengaja (kunci asing) bila bahan baru sudah dipakai rekomendasi atau inventaris.
DELETE FROM katalog_hama WHERE id_katalog IN (SELECT id_katalog FROM obat_katalog WHERE bahan_aktif IN
  ('Flupiradifuron', 'Dinotefuran', 'Tiametoksam', 'Spiromesifen', 'Diafentiuron', 'Buprofezin',
   'Dimpropiridaz', 'Lecanicillium lecanii', 'Menochilus sexmaculatus'));
DELETE FROM obat_katalog WHERE bahan_aktif IN
  ('Flupiradifuron', 'Dinotefuran', 'Tiametoksam', 'Spiromesifen', 'Diafentiuron', 'Buprofezin',
   'Dimpropiridaz', 'Lecanicillium lecanii', 'Menochilus sexmaculatus');
DELETE FROM moa_groups WHERE kode_moa IN ('4D', '12A', '16', '36');
UPDATE obat_katalog SET phi_hari = NULL, phi_sumber = NULL
  WHERE bahan_aktif IN ('Azadirachtin (neem)', 'Sabun insektisida');
ALTER TABLE rekomendasi_perawatan DROP COLUMN alasan_diisi;
ALTER TABLE rekomendasi_perawatan DROP COLUMN rencana;
ALTER TABLE obat_katalog DROP COLUMN catatan_registrasi;
ALTER TABLE obat_katalog DROP COLUMN status_registrasi;
ALTER TABLE obat_katalog DROP COLUMN boleh_direkomendasikan;
