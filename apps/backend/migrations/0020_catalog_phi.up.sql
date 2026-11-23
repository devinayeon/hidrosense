-- Migration 0020: masa tunggu panen (PHI) untuk bahan kimia di katalog.
-- Angka berasal dari label dan panduan Amerika Serikat untuk selada/sayuran daun, BUKAN label
-- terdaftar di Indonesia. phi_sumber wajib terisi bila phi_hari terisi, supaya aplikasi bisa
-- menampilkan asal angka dan pengguna tetap mengecek label produknya sendiri.
ALTER TABLE obat_katalog ADD COLUMN phi_sumber TEXT CHECK (phi_sumber IS NULL OR length(phi_sumber) <= 300);

UPDATE obat_katalog SET phi_hari = 1, phi_sumber = 'Label AS untuk selada (UC IPM Lettuce PMG)' WHERE bahan_aktif = 'Spinosad';
UPDATE obat_katalog SET phi_hari = 7, phi_sumber = 'Label AS untuk selada (UC IPM; LSU AgCenter 2025)' WHERE bahan_aktif = 'Abamektin';
UPDATE obat_katalog SET phi_hari = 7, phi_sumber = 'Label AS untuk selada (UC IPM Lettuce PMG)' WHERE bahan_aktif = 'Asetamiprid';
UPDATE obat_katalog SET phi_hari = 7, phi_sumber = 'Label AS, aplikasi daun pada selada (UC IPM crop profile)' WHERE bahan_aktif = 'Imidakloprid';
UPDATE obat_katalog SET phi_hari = 3, phi_sumber = 'Label AS untuk selada (New England Vegetable Guide; PNW Handbook)' WHERE bahan_aktif = 'Spirotetramat';
UPDATE obat_katalog SET phi_hari = 0, phi_sumber = 'Label AS untuk selada (New England Vegetable Guide; PNW Handbook)' WHERE bahan_aktif = 'Flonikamid';
UPDATE obat_katalog SET phi_hari = 7, phi_sumber = 'Label AS untuk selada (New England Vegetable Guide)' WHERE bahan_aktif = 'Pimetrozin';

-- Angka tanpa sumber tidak boleh masuk: dijaga di database, bukan hanya di migrasi ini.
CREATE TRIGGER trg_obat_katalog_phi_sumber_insert BEFORE INSERT ON obat_katalog
  WHEN NEW.phi_hari IS NOT NULL AND NEW.phi_sumber IS NULL
BEGIN
  SELECT RAISE(ABORT, 'phi_hari wajib disertai phi_sumber');
END;
CREATE TRIGGER trg_obat_katalog_phi_sumber_update BEFORE UPDATE OF phi_hari, phi_sumber ON obat_katalog
  WHEN NEW.phi_hari IS NOT NULL AND NEW.phi_sumber IS NULL
BEGIN
  SELECT RAISE(ABORT, 'phi_hari wajib disertai phi_sumber');
END;
