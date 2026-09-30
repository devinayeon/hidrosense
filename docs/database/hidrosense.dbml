Project HidroSense {
  database_type: "PostgreSQL"
  Note: "Sistem Manajemen Budidaya Selada Hidroponik NFT"
}

Table roles {
  id_role int [pk, increment]
  nama_role varchar(30) [not null, unique]
}

Table users {
  id_user int [pk, increment]
  id_role int [not null]
  nama varchar(100) [not null]
  username varchar(50) [not null, unique]
  password varchar(255) [not null]
  email varchar(100)
  no_telepon varchar(20)
  alamat text
  status_aktif boolean [not null, default: true]
}

Table jenis_inventaris {
  id_jenis_inventaris int [pk, increment]
  nama_jenis varchar(50) [not null, unique]
}

Table obat {
  id_obat int [pk, increment]
  nama_obat varchar(100) [not null]
  jenis_obat varchar(50)
  dosis varchar(100)
  aturan_penggunaan text
  deskripsi text
  status_aktif boolean [not null, default: true]
}

Table inventaris {
  id_inventaris int [pk, increment]
  id_jenis_inventaris int [not null]
  id_obat int
  nama_barang varchar(100) [not null]
  satuan varchar(30) [not null]
  stok_minimum decimal(10,2)
  status_aktif boolean [not null, default: true]
}

Table penyemaian {
  id_penyemaian int [pk, increment]
  id_user int [not null]
  tanggal_semai date [not null]
  jumlah_benih int [not null]
  status_penyemaian varchar(30)
  keterangan text
}

Table meja_tanam {
  id_meja int [pk, increment]
  kode_meja varchar(30) [not null, unique]
  jumlah_lubang int [not null]
  status_meja varchar(30) [not null, default: 'tersedia']
  keterangan text
}

Table pemindahan {
  id_pemindahan int [pk, increment]
  id_penyemaian int [not null]
  id_meja int [not null]
  tanggal_pemindahan date [not null]
  jumlah_tanaman int [not null]
  keterangan text
}

Table kerusakan_tanaman {
  id_kerusakan int [pk, increment]
  id_pemindahan int [not null]
  tanggal_kejadian date [not null]
  jumlah_tanaman int [not null]
  jenis_kerusakan varchar(100) [not null]
  keterangan text
}

Table hasil_deteksi {
  id_hasil_deteksi int [pk, increment]
  id_pemindahan int [not null]
  gambar varchar(255) [not null]
  nama_hama varchar(100) [not null]
  confidence decimal(5,4)
  tanggal_deteksi timestamp [not null, default: `CURRENT_TIMESTAMP`]
}

Table rekomendasi_perawatan {
  id_rekomendasi int [pk, increment]
  id_hasil_deteksi int [not null]
  id_obat int [not null]
  tanggal_rekomendasi timestamp [not null, default: `CURRENT_TIMESTAMP`]
  status_rekomendasi varchar(20) [not null, default: 'menunggu']
  alasan_penolakan text
}

Table perawatan {
  id_perawatan int [pk, increment]
  id_rekomendasi int [not null]
  id_user int [not null]
  tanggal_perawatan timestamp [not null, default: `CURRENT_TIMESTAMP`]
  catatan text
}

Table stok {
  id_stok int [pk, increment]
  id_user int [not null]
  id_penyemaian int
  id_perawatan int
  tanggal_stok timestamp [not null, default: `CURRENT_TIMESTAMP`]
  jenis_stok varchar(10) [not null]
  keterangan text
}

Table detail_stok {
  id_detail_stok int [pk, increment]
  id_stok int [not null]
  id_inventaris int [not null]
  jumlah decimal(10,2) [not null]
}

Table penanganan_cuaca {
  id_penanganan_cuaca int [pk, increment]
  kondisi_cuaca varchar(100)
  suhu_min decimal(5,2)
  suhu_max decimal(5,2)
  kelembapan_min decimal(5,2)
  kelembapan_max decimal(5,2)
  curah_hujan_min decimal(8,2)
  curah_hujan_max decimal(8,2)
  rekomendasi text [not null]
  status_aktif boolean [not null, default: true]
}

Table panen {
  id_panen int [pk, increment]
  id_user int [not null]
  tanggal_panen date [not null]
  keterangan text
}

Table detail_panen {
  id_detail_panen int [pk, increment]
  id_panen int [not null]
  id_pemindahan int [not null]
  jumlah_tanaman int [not null]
  berat decimal(10,2) [not null]
}

Table penjualan {
  id_penjualan int [pk, increment]
  id_user int [not null]
  tanggal_penjualan date [not null]
  keterangan text
}

Table detail_penjualan {
  id_detail_penjualan int [pk, increment]
  id_penjualan int [not null]
  id_panen int [not null]
  jumlah_kg decimal(10,2) [not null]
  harga_per_kg decimal(12,2) [not null]
}

Ref: users.id_role > roles.id_role
Ref: inventaris.id_jenis_inventaris > jenis_inventaris.id_jenis_inventaris
Ref: inventaris.id_obat > obat.id_obat
Ref: penyemaian.id_user > users.id_user
Ref: pemindahan.id_penyemaian > penyemaian.id_penyemaian
Ref: pemindahan.id_meja > meja_tanam.id_meja
Ref: kerusakan_tanaman.id_pemindahan > pemindahan.id_pemindahan
Ref: hasil_deteksi.id_pemindahan > pemindahan.id_pemindahan
Ref: rekomendasi_perawatan.id_hasil_deteksi > hasil_deteksi.id_hasil_deteksi
Ref: rekomendasi_perawatan.id_obat > obat.id_obat
Ref: perawatan.id_rekomendasi > rekomendasi_perawatan.id_rekomendasi
Ref: perawatan.id_user > users.id_user
Ref: stok.id_user > users.id_user
Ref: stok.id_penyemaian > penyemaian.id_penyemaian
Ref: stok.id_perawatan > perawatan.id_perawatan
Ref: detail_stok.id_stok > stok.id_stok
Ref: detail_stok.id_inventaris > inventaris.id_inventaris
Ref: panen.id_user > users.id_user
Ref: detail_panen.id_panen > panen.id_panen
Ref: detail_panen.id_pemindahan > pemindahan.id_pemindahan
Ref: penjualan.id_user > users.id_user
Ref: detail_penjualan.id_penjualan > penjualan.id_penjualan
Ref: detail_penjualan.id_panen > panen.id_panen
