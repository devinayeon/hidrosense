-- Mengembalikan katalog tanpa masa tunggu panen.
DROP TRIGGER IF EXISTS trg_obat_katalog_phi_sumber_update;
DROP TRIGGER IF EXISTS trg_obat_katalog_phi_sumber_insert;
UPDATE obat_katalog SET phi_hari = NULL;
ALTER TABLE obat_katalog DROP COLUMN phi_sumber;
