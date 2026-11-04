# Scope HidroSense vs Kode

Tanggal: 2026-11-04
Sumber scope: `hidrosense-plan-docs/Hidrosense Plan Document.md` (System Request, SRS, Product Backlog, Project Charter, WBS), ditambah `docs/rencana-backend.md` dan `docs/backend-b001-b002.md` yang dibaca dari git `HEAD`, karena sudah dihapus di working tree.
Yang dibandingkan: kode `main` lokal dan `origin/main`. Tidak ada kode yang diubah untuk dokumen ini.

## 1. Kesimpulan

1. **Dua cabang menyimpang dan belum bisa digabung apa adanya.** `main` lokal 9 commit di depan dan 24 commit di belakang `origin/main`. Penjualan dan BMKG ada di `origin/main`; semua perbaikan keamanan dan rework saya ada di lokal.
2. **Fitur prioritas tinggi belum ada di backend.** PB-05 (hasil deteksi) dan PB-06 (rekomendasi dan perawatan) belum punya route, walau Sprint 2 sudah berakhir dan Sprint 3 berakhir 7 November.
3. **Inti offline belum ada.** Antrean sinkronisasi lokal, penyimpanan sesi di perangkat, dan endpoint pengambilan perubahan belum ada, padahal itu kriteria keberhasilan proyek.

Sisa waktu sampai penyerahan 28 November 2026: 24 hari.

## 2. Status per backlog

| PB | Fitur | Prioritas | Backend | Mobile | Catatan |
|---|---|---|---|---|---|
| PB-01 | Autentikasi, hak akses | Tinggi | Ada | Ada; **token hanya di memori** | Lihat 4.2 |
| PB-02 | Inventaris, stok | Tinggi | Ada | Ada | |
| PB-03 | Penyemaian | Tinggi | Ada | Ada | |
| PB-04 | Meja, pemindahan, kerusakan | Tinggi | Ada | Ada | |
| PB-05 | Deteksi hama | Tinggi | **Belum ada** (B11) | **Belum ada**: tidak ada TFLite, kamera, atau galeri di `pubspec.yaml` | Tabel `hasil_deteksi` ada. `ml/` berisi skrip latih dan ekspor |
| PB-06 | Rekomendasi, perawatan | Tinggi | **Belum ada** (B12–B14) | Belum diperiksa | Tabel ada. Aturan rotasi perlu validasi mitra |
| PB-07 | Lokal dan sinkronisasi | Tinggi | Sebagian: anti-duplikat ada (B04), **pengambilan perubahan belum** (B17) | **Sebagian**: `sqflite` hanya dipakai `inventory_cache.dart` | Lihat 4.1 |
| PB-08 | Panen | Sedang | Ada | Ada | |
| PB-09 | Penjualan | Sedang | **Hanya di `origin/main`** | Lokal masih data contoh (`defaultPenjualanList`) | Laporan saya sebelumnya salah; lihat bagian 6 |
| PB-10 | Cuaca BMKG | Sedang | Tidak ada | **Hanya di `origin/main`**; lokal masih `mockData` | Lihat 5.3 |
| PB-11 | Akun | Sedang | Ada | Ada | |

## 3. Temuan paling berisiko: penyimpangan cabang

Hasil simulasi, tanpa mengubah repo:

| Hal | Bukti |
|---|---|
| Nomor migrasi bentrok | Lokal `0012_operation_key_lower`, origin `0012_table_occupancy_status`. Digabung: `ERROR: Duplicate migration version: 0012`, sehingga backend gagal start |
| Konflik teks antar commit | 4 file berubah di kedua sisi, 2 penanda konflik |
| Rework yang belum di-commit | 11 file backend juga berubah di origin, antara lain `app.ts`, `tables/store.ts`, `tables/service.ts`, `harvest/service.ts` |

Bentrok migrasi tidak akan terlihat sebagai konflik git, karena nama filenya berbeda. Ia baru muncul saat aplikasi dijalankan.

Jika salah satu dari dua migrasi sudah diterapkan ke Turso, urutan penomoran ulang harus mengikuti riwayat `_schema_migrations` di sana. Itu belum saya periksa.

## 4. Kesenjangan dengan kriteria keberhasilan

### 4.1 Pencatatan luring (kriteria 3 dan 4, PB-07)
SRS mewajibkan pencatatan saat tidak ada internet dan data tetap ada setelah aplikasi dibuka lagi. Di kode, `sqflite` hanya dipakai cache inventaris. Perintah yang tertunda pada fitur lain tampak disimpan di memori. Kesimpulan ini dari pembacaan kode; saya belum mengujinya di perangkat.

Di sisi backend, rencana B17 meminta pengambilan perubahan untuk klien lain, dan endpoint itu belum ada.

### 4.2 Sesi di perangkat (PB-01)
`docs/backend-b001-b002.md` menetapkan token disimpan di penyimpanan aman perangkat. Aplikasi belum melakukannya, jadi:
- Menutup aplikasi berarti harus login lagi, dan login butuh internet.
- Masa sesi 7 hari dan 30 hari dari T-05 belum terasa manfaatnya.
- Pencatatan luring tidak bisa berjalan setelah aplikasi dibuka ulang di tempat tanpa sinyal.

### 4.3 Refresh di jaringan buruk (risiko "koneksi tidak stabil")
Refresh token sekali pakai. Kalau respons refresh hilang, token lama sudah tidak berlaku dan aplikasi menghapus sesi (`_rotate` di `api_client.dart`). Di kebun tanpa sinyal, petani jadi tidak bisa bekerja sampai bisa login online. Ini bukan bug baru, tetapi dampaknya lebih besar dalam konteks SRS, dan cold start serverless bisa menambah kemungkinannya.

Opsi perbaikannya masa tenggang singkat untuk token sebelumnya. Itu butuh migrasi, perubahan mobile, dan keputusan keamanan, jadi belum saya kerjakan.

### 4.4 Aturan konflik terdokumentasi (PB-07)
`expected_version` dari rework sebelumnya sudah tersedia di server dan ditulis di panduan bagian 5, tetapi aplikasi belum mengirimkannya.

### 4.5 Target kinerja (kriteria 5)
Target kurang dari 3 detik dan kurang dari 1 menit belum pernah diukur di Turso atau serverless. Batas 120 request per menit per IP juga perlu dicek terhadap antrean sinkronisasi yang nanti dikirim sekaligus; antrean itu sendiri belum ada.

## 5. Perbedaan antara dokumen dan kode

| # | Hal | Status |
|---|---|---|
| 5.1 | Akses panen pegawai: System Request memberi akses; SRS 1.5, PB-01, PB-08 dan WBS tidak | **Sudah diputuskan** di `rencana-backend.md`: System Request yang berlaku. Kode mengikutinya. Plan Document belum diselaraskan |
| 5.2 | Estimasi panen: "±45 hari" vs "15 + 45 = 60 hari" di dokumen yang sama | Kode memakai semai + 45 hari. Hitungan 60 hari di Business Value perlu dikoreksi Product Owner |
| 5.3 | BMKG: SRS dan B19 menempatkan integrasi di backend; `origin/main` memanggilnya langsung dari aplikasi | **Perlu keputusan** |
| 5.4 | Umur pindah: dokumen "±15 hari"; kode menolak di bawah 15 hari | **Perlu konfirmasi mitra**, karena pemindahan hari ke-14 ditolak |
| 5.5 | Serverless belum tercatat di SRS atau Project Charter | Perlu dicatat. Cocok dengan Turso dan Cloudinary |

## 6. Koreksi laporan saya sebelumnya

- **"Backend tidak punya penjualan"** di review dan hunt-002: hanya benar untuk `main` lokal. `origin/main` punya `features/sales` dan migrasi `0013_sales`.
- **"Backend tidak punya fitur penjualan, jadi tidak diuji"**: fitur itu belum pernah saya baca. `features/sales` belum direview.
- **Review backend membaca `main` lokal saja.** Perubahan 24 commit di origin belum direview, termasuk perubahan `tables` dan `transfers`.
- **Rencana kerja di rework sebelumnya kurang tepat.** Saya mengurutkannya hanya dari temuan kode, tanpa melihat backlog. Fitur prioritas tinggi yang belum ada lebih penting daripada sebagian besar T-item.

## 7. Urutan kerja yang saya sarankan

1. **Satukan cabang.** Commit rework ke branch, gabungkan `origin/main`, nomori ulang migrasi `0012_operation_key_lower`, lalu jalankan seluruh test.
2. **Review `features/sales`** dan selaraskan dengan aturan baru (`expected_version`, status HTTP).
3. **B11–B14:** hasil deteksi, rekomendasi, keputusan, perawatan. Prioritas tinggi; B12 butuh aturan rotasi yang tervalidasi.
4. **B17:** endpoint pengambilan perubahan. Bersamaan dengan frontend: penyimpanan token aman, antrean lokal, dan `expected_version`.
5. **B18:** uji di Turso staging dan platform serverless, ukur target kinerja, lalu dokumentasi serah terima.

Daftar ini padat untuk 24 hari. Item yang berisiko tidak selesai sebaiknya dibicarakan dengan Product Owner lebih awal.

## 8. Belum diperiksa

- Isi `features/sales` dan 24 commit di `origin/main`.
- Riwayat migrasi yang sudah diterapkan di Turso.
- Layar mobile untuk rekomendasi dan perawatan, serta perilaku offline di perangkat nyata.
- Gambar diagram di Plan Document (ERD, use case, Gantt): hanya teksnya yang saya baca.
- `ml/` selain daftar file.
