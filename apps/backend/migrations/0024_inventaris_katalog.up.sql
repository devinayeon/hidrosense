-- Barang inventaris jenis Obat dapat ditautkan langsung ke katalog pengetahuan
-- obat bawaan (obat_katalog), bukan hanya ke master `obat` milik pengguna.
-- Nama barang diturunkan dari bahan_aktif saat id_katalog diisi, sehingga
-- kedua kolom tautan tidak perlu terisi bersamaan.
ALTER TABLE inventaris ADD COLUMN id_katalog INTEGER
  REFERENCES obat_katalog (id_katalog) ON UPDATE NO ACTION ON DELETE NO ACTION;

CREATE INDEX idx_inventaris_katalog ON inventaris (id_katalog);