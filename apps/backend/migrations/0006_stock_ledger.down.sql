-- Populated upgrades/new stock metadata require forward repair, never audit erasure.
CREATE TABLE _b006_down_guard (valid INTEGER CONSTRAINT b006_down_requires_empty_stock CHECK(valid=1));
INSERT INTO _b006_down_guard SELECT 0 WHERE
  EXISTS (SELECT 1 FROM stok) OR EXISTS (SELECT 1 FROM detail_stok)
  OR EXISTS (SELECT 1 FROM stok_saldo)
  OR EXISTS (SELECT 1 FROM sync_resource_links WHERE resource_type='stok')
  OR EXISTS (SELECT 1 FROM sync_resource_versions WHERE resource_type='stok')
  OR EXISTS (SELECT 1 FROM sync_id_maps WHERE resource_type='stok')
  OR EXISTS (SELECT 1 FROM sync_operations WHERE operation_type LIKE 'stok.%');
DROP TRIGGER b006_header_insert;
DROP TRIGGER b006_header_update;
DROP TRIGGER b006_header_delete;
DROP TRIGGER b006_detail_insert;
DROP TRIGGER b006_detail_update;
DROP TRIGGER b006_detail_delete;
DROP TRIGGER b006_inventory_unit;
DROP TRIGGER b006_minimum_insert;
DROP TRIGGER b006_minimum_update;
DROP INDEX idx_detail_stok_header_item;
DROP INDEX idx_detail_stok_item_header;
DROP INDEX idx_stok_reversal;
DROP INDEX idx_stok_sowing_origin;
DROP INDEX idx_stok_care_origin;
DROP TABLE stok_saldo;
ALTER TABLE detail_stok DROP COLUMN jumlah_minor;
ALTER TABLE detail_stok DROP COLUMN satuan;
ALTER TABLE inventaris DROP COLUMN stok_minimum_minor;
ALTER TABLE stok DROP COLUMN reversal_of;
ALTER TABLE stok DROP COLUMN sealed;
DROP TABLE _b006_down_guard;
