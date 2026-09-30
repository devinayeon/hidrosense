-- Adapted from docs/database/hidrosense.dbml for SQLite/libSQL.
-- See apps/backend/README.md for type mapping and limitations.

CREATE TABLE roles (
  id_role INTEGER PRIMARY KEY AUTOINCREMENT,
  nama_role TEXT NOT NULL UNIQUE CHECK (length(nama_role) <= 30)
);

CREATE TABLE users (
  id_user INTEGER PRIMARY KEY AUTOINCREMENT,
  id_role INTEGER NOT NULL,
  nama TEXT NOT NULL CHECK (length(nama) <= 100),
  username TEXT NOT NULL UNIQUE CHECK (length(username) <= 50),
  password TEXT NOT NULL CHECK (length(password) <= 255),
  email TEXT CHECK (length(email) <= 100),
  no_telepon TEXT CHECK (length(no_telepon) <= 20),
  alamat TEXT,
  status_aktif INTEGER NOT NULL DEFAULT 1 CHECK (status_aktif IN (0, 1)),
  FOREIGN KEY (id_role) REFERENCES roles (id_role) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE jenis_inventaris (
  id_jenis_inventaris INTEGER PRIMARY KEY AUTOINCREMENT,
  nama_jenis TEXT NOT NULL UNIQUE CHECK (length(nama_jenis) <= 50)
);

CREATE TABLE obat (
  id_obat INTEGER PRIMARY KEY AUTOINCREMENT,
  nama_obat TEXT NOT NULL CHECK (length(nama_obat) <= 100),
  jenis_obat TEXT CHECK (length(jenis_obat) <= 50),
  dosis TEXT CHECK (length(dosis) <= 100),
  aturan_penggunaan TEXT,
  deskripsi TEXT,
  status_aktif INTEGER NOT NULL DEFAULT 1 CHECK (status_aktif IN (0, 1))
);

CREATE TABLE inventaris (
  id_inventaris INTEGER PRIMARY KEY AUTOINCREMENT,
  id_jenis_inventaris INTEGER NOT NULL,
  id_obat INTEGER,
  nama_barang TEXT NOT NULL CHECK (length(nama_barang) <= 100),
  satuan TEXT NOT NULL CHECK (length(satuan) <= 30),
  stok_minimum DECIMAL(10,2),
  status_aktif INTEGER NOT NULL DEFAULT 1 CHECK (status_aktif IN (0, 1)),
  FOREIGN KEY (id_jenis_inventaris) REFERENCES jenis_inventaris (id_jenis_inventaris) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_obat) REFERENCES obat (id_obat) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE penyemaian (
  id_penyemaian INTEGER PRIMARY KEY AUTOINCREMENT,
  id_user INTEGER NOT NULL,
  tanggal_semai TEXT NOT NULL,
  jumlah_benih INTEGER NOT NULL,
  status_penyemaian TEXT CHECK (length(status_penyemaian) <= 30),
  keterangan TEXT,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE meja_tanam (
  id_meja INTEGER PRIMARY KEY AUTOINCREMENT,
  kode_meja TEXT NOT NULL UNIQUE CHECK (length(kode_meja) <= 30),
  jumlah_lubang INTEGER NOT NULL,
  status_meja TEXT NOT NULL DEFAULT 'tersedia' CHECK (length(status_meja) <= 30),
  keterangan TEXT
);

CREATE TABLE pemindahan (
  id_pemindahan INTEGER PRIMARY KEY AUTOINCREMENT,
  id_penyemaian INTEGER NOT NULL,
  id_meja INTEGER NOT NULL,
  tanggal_pemindahan TEXT NOT NULL,
  jumlah_tanaman INTEGER NOT NULL,
  keterangan TEXT,
  FOREIGN KEY (id_penyemaian) REFERENCES penyemaian (id_penyemaian) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_meja) REFERENCES meja_tanam (id_meja) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE kerusakan_tanaman (
  id_kerusakan INTEGER PRIMARY KEY AUTOINCREMENT,
  id_pemindahan INTEGER NOT NULL,
  tanggal_kejadian TEXT NOT NULL,
  jumlah_tanaman INTEGER NOT NULL,
  jenis_kerusakan TEXT NOT NULL CHECK (length(jenis_kerusakan) <= 100),
  keterangan TEXT,
  FOREIGN KEY (id_pemindahan) REFERENCES pemindahan (id_pemindahan) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE hasil_deteksi (
  id_hasil_deteksi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_pemindahan INTEGER NOT NULL,
  gambar TEXT NOT NULL CHECK (length(gambar) <= 255),
  nama_hama TEXT NOT NULL CHECK (length(nama_hama) <= 100),
  confidence DECIMAL(5,4),
  tanggal_deteksi TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_pemindahan) REFERENCES pemindahan (id_pemindahan) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE rekomendasi_perawatan (
  id_rekomendasi INTEGER PRIMARY KEY AUTOINCREMENT,
  id_hasil_deteksi INTEGER NOT NULL,
  id_obat INTEGER NOT NULL,
  tanggal_rekomendasi TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status_rekomendasi TEXT NOT NULL DEFAULT 'menunggu' CHECK (length(status_rekomendasi) <= 20),
  alasan_penolakan TEXT,
  FOREIGN KEY (id_hasil_deteksi) REFERENCES hasil_deteksi (id_hasil_deteksi) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_obat) REFERENCES obat (id_obat) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE perawatan (
  id_perawatan INTEGER PRIMARY KEY AUTOINCREMENT,
  id_rekomendasi INTEGER NOT NULL,
  id_user INTEGER NOT NULL,
  tanggal_perawatan TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  catatan TEXT,
  FOREIGN KEY (id_rekomendasi) REFERENCES rekomendasi_perawatan (id_rekomendasi) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE stok (
  id_stok INTEGER PRIMARY KEY AUTOINCREMENT,
  id_user INTEGER NOT NULL,
  id_penyemaian INTEGER,
  id_perawatan INTEGER,
  tanggal_stok TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  jenis_stok TEXT NOT NULL CHECK (length(jenis_stok) <= 10),
  keterangan TEXT,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_penyemaian) REFERENCES penyemaian (id_penyemaian) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_perawatan) REFERENCES perawatan (id_perawatan) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE detail_stok (
  id_detail_stok INTEGER PRIMARY KEY AUTOINCREMENT,
  id_stok INTEGER NOT NULL,
  id_inventaris INTEGER NOT NULL,
  jumlah DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (id_stok) REFERENCES stok (id_stok) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_inventaris) REFERENCES inventaris (id_inventaris) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE penanganan_cuaca (
  id_penanganan_cuaca INTEGER PRIMARY KEY AUTOINCREMENT,
  kondisi_cuaca TEXT CHECK (length(kondisi_cuaca) <= 100),
  suhu_min DECIMAL(5,2),
  suhu_max DECIMAL(5,2),
  kelembapan_min DECIMAL(5,2),
  kelembapan_max DECIMAL(5,2),
  curah_hujan_min DECIMAL(8,2),
  curah_hujan_max DECIMAL(8,2),
  rekomendasi TEXT NOT NULL,
  status_aktif INTEGER NOT NULL DEFAULT 1 CHECK (status_aktif IN (0, 1))
);

CREATE TABLE panen (
  id_panen INTEGER PRIMARY KEY AUTOINCREMENT,
  id_user INTEGER NOT NULL,
  tanggal_panen TEXT NOT NULL,
  keterangan TEXT,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE detail_panen (
  id_detail_panen INTEGER PRIMARY KEY AUTOINCREMENT,
  id_panen INTEGER NOT NULL,
  id_pemindahan INTEGER NOT NULL,
  jumlah_tanaman INTEGER NOT NULL,
  berat DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (id_panen) REFERENCES panen (id_panen) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_pemindahan) REFERENCES pemindahan (id_pemindahan) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE penjualan (
  id_penjualan INTEGER PRIMARY KEY AUTOINCREMENT,
  id_user INTEGER NOT NULL,
  tanggal_penjualan TEXT NOT NULL,
  keterangan TEXT,
  FOREIGN KEY (id_user) REFERENCES users (id_user) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE detail_penjualan (
  id_detail_penjualan INTEGER PRIMARY KEY AUTOINCREMENT,
  id_penjualan INTEGER NOT NULL,
  id_panen INTEGER NOT NULL,
  jumlah_kg DECIMAL(10,2) NOT NULL,
  harga_per_kg DECIMAL(12,2) NOT NULL,
  FOREIGN KEY (id_penjualan) REFERENCES penjualan (id_penjualan) ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY (id_panen) REFERENCES panen (id_panen) ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE INDEX idx_users_id_role ON users (id_role);

CREATE INDEX idx_inventaris_id_jenis_inventaris ON inventaris (id_jenis_inventaris);

CREATE INDEX idx_inventaris_id_obat ON inventaris (id_obat);

CREATE INDEX idx_penyemaian_id_user ON penyemaian (id_user);

CREATE INDEX idx_pemindahan_id_penyemaian ON pemindahan (id_penyemaian);

CREATE INDEX idx_pemindahan_id_meja ON pemindahan (id_meja);

CREATE INDEX idx_kerusakan_tanaman_id_pemindahan ON kerusakan_tanaman (id_pemindahan);

CREATE INDEX idx_hasil_deteksi_id_pemindahan ON hasil_deteksi (id_pemindahan);

CREATE INDEX idx_rekomendasi_perawatan_id_hasil_deteksi ON rekomendasi_perawatan (id_hasil_deteksi);

CREATE INDEX idx_rekomendasi_perawatan_id_obat ON rekomendasi_perawatan (id_obat);

CREATE INDEX idx_perawatan_id_rekomendasi ON perawatan (id_rekomendasi);

CREATE INDEX idx_perawatan_id_user ON perawatan (id_user);

CREATE INDEX idx_stok_id_user ON stok (id_user);

CREATE INDEX idx_stok_id_penyemaian ON stok (id_penyemaian);

CREATE INDEX idx_stok_id_perawatan ON stok (id_perawatan);

CREATE INDEX idx_detail_stok_id_stok ON detail_stok (id_stok);

CREATE INDEX idx_detail_stok_id_inventaris ON detail_stok (id_inventaris);

CREATE INDEX idx_panen_id_user ON panen (id_user);

CREATE INDEX idx_detail_panen_id_panen ON detail_panen (id_panen);

CREATE INDEX idx_detail_panen_id_pemindahan ON detail_panen (id_pemindahan);

CREATE INDEX idx_penjualan_id_user ON penjualan (id_user);

CREATE INDEX idx_detail_penjualan_id_penjualan ON detail_penjualan (id_penjualan);

CREATE INDEX idx_detail_penjualan_id_panen ON detail_penjualan (id_panen);
