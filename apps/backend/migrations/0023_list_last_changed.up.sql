-- Daftar fitur menaruh baris yang paling baru diubah di paling atas. Waktu perubahan itu dibaca
-- dari sync_changes (termasuk perubahan turunan seperti saldo stok dan tanaman aktif). Indeks ini
-- menjaga pencarian MAX(changed_at) per record tetap murah saat daftar diurutkan.
CREATE INDEX idx_sync_changes_resource_domain ON sync_changes (resource_type, domain_id, changed_at DESC);

-- Akun pegawai tidak ikut registry resource sync, jadi waktu ubahnya disimpan di tabelnya sendiri.
-- ADD COLUMN tidak bisa memakai CURRENT_TIMESTAMP sebagai default; nilai diisi jalur tulis akun.
-- Baris lama dibiarkan NULL dan diurutkan paling bawah lewat COALESCE.
ALTER TABLE users ADD COLUMN updated_at INTEGER;
