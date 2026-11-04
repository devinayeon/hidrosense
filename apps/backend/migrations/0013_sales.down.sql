DROP INDEX idx_penjualan_date_id;
ALTER TABLE detail_penjualan DROP COLUMN harga_per_kg_minor;
ALTER TABLE detail_penjualan DROP COLUMN jumlah_kg_minor;
ALTER TABLE penjualan DROP COLUMN status_pembayaran;
ALTER TABLE penjualan DROP COLUMN pembeli;
DELETE FROM sync_resource_versions WHERE resource_type = 'penjualan';
DELETE FROM sync_resource_links WHERE resource_type = 'penjualan';
