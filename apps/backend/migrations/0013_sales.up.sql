ALTER TABLE penjualan ADD COLUMN pembeli TEXT NOT NULL DEFAULT '' CHECK (length(pembeli) <= 100);
ALTER TABLE penjualan ADD COLUMN status_pembayaran TEXT NOT NULL DEFAULT 'lunas' CHECK (status_pembayaran IN ('lunas', 'belum_lunas'));
ALTER TABLE detail_penjualan ADD COLUMN jumlah_kg_minor INTEGER CHECK (jumlah_kg_minor IS NULL OR (typeof(jumlah_kg_minor) = 'integer' AND jumlah_kg_minor BETWEEN 0 AND 9999999999));
ALTER TABLE detail_penjualan ADD COLUMN harga_per_kg_minor INTEGER CHECK (harga_per_kg_minor IS NULL OR (typeof(harga_per_kg_minor) = 'integer' AND harga_per_kg_minor BETWEEN 0 AND 999999999999));
CREATE INDEX idx_penjualan_date_id ON penjualan(tanggal_penjualan DESC, id_penjualan DESC);
