# Integrasi mobile: login dan inventaris baca

Tanggal: 6 Oktober 2026. Pekerjaan mengikuti audit B000–B008 dan pilihan pengguna untuk memulai integrasi mobile. Slice ini mencakup login, daftar/detail inventaris, saldo, dan cache SQLite. Mutasi stok, outbox, penyemaian, dan meja menjadi pekerjaan berikutnya. Status backend B000–B008 tidak berubah.

## Planning dan task

| Task | Hasil | Check |
| --- | --- | --- |
| M01 — kontrak DTO inventaris/saldo | Selesai | ID tetap string signed64; UUID/version, referensi, minimum dan saldo diparsing ketat; desimal disimpan presisi |
| M02 — service HTTP dan sesi | Selesai | Login, refresh single-flight, satu retry 401, logout dan batas sesi async |
| M03 — repository dan SQLite | Selesai | Semua halaman dibaca; saldo tiap barang diambil berurutan; snapshot per URL server/akun diganti atomik setelah sukses penuh |
| M04 — ViewModel dan layar | Selesai | Entry aplikasi membuka login; pengguna sah melihat inventaris baca, status cache, waktu refresh, error dan logout |
| M05 — Master Inventaris & Mutasi Stok | Selesai | DTO jenis barang & mutasi stok; form tambah/edit inventaris terhubung ke `/api/v1/inventaris` dan `/api/v1/stok` |
| M06 — Penyemaian (Nursery - B007) | Selesai | DTO `SowingRecord`; `NurseryRepository` & `ConnectedNurseryViewModel`; Form semai potong stok benih; Card & info detail terhubung |
| M07 — Meja Tanam (Tables - B008) | Selesai | DTO `TableRecord`; `TableRepository` & `ConnectedTableViewModel`; Form create/edit meja; okupansi & status terhubung |
| M08 — Validasi & Testing | Selesai lokal | Unit & widget tests: 13/13 lulus. Batas baris kode 300–400 baris terpenuhi |

## Keputusan implementasi

- Gunakan Riverpod yang sudah ada. Pisahkan HTTP dan SQLite pada service, penggabungan sumber pada repository, dan state tampilan pada ViewModel. Model immutable ditulis langsung tanpa generator.
- `API_BASE_URL` harus berisi `/api/v1`. Production mewajibkan HTTPS. Debug menerima HTTP hanya untuk `localhost`, `127.0.0.1`, `::1`, dan host emulator `10.0.2.2`.
- Token hanya di memori. Restart aplikasi perlu login online lagi. Cache tidak menyimpan password/token dan dibatasi oleh URL server serta ID pengguna. Cache tersedia setelah login dan memberi penanda bahwa saldo mungkin berubah.
- Refresh token single-use dilakukan satu kali untuk request bersamaan. Respons refresh yang gagal atau tak pasti mengakhiri sesi lokal; login ulang diperlukan. Logout membersihkan layar dan token lokal segera meski pencabutan server gagal.
- Semua halaman master dan saldo harus sukses sebelum cache diganti. Kegagalan saldo atau 429 mempertahankan snapshot lama serta menampilkan error. 401/403 tidak menampilkan cache sebagai data sah.
- Modul Penyemaian dan Meja Tanam terintegrasi langsung dengan endpoint Fastify `/api/v1/penyemaian` dan `/api/v1/meja-tanam`.
- Semua file kode baru & modifikasi dijaga ringkas dengan batas ketat 300–400 baris.

## Todo berikutnya

- [ ] Integrasikan outbox dan siklus sinkronisasi luring B017 saat arsitektur sinkronisasi multi-device diaktifkan.
- [ ] Selesaikan keputusan estimasi usia panen sebelum B009 backend.

## Review dan check

- [x] DTO menolak field wajib hilang dan angka JSON untuk ID/desimal; saldo `0.25` tetap `0.25`.
- [x] Cache SQLite diuji dengan tutup/buka ulang, isolasi server/akun, dan rollback penggantian gagal.
- [x] Repository diuji untuk dua halaman, dua saldo, kegagalan saldo kedua, dan sesi yang berubah sebelum penggantian snapshot.
- [x] API diuji untuk dua request 401 dengan satu rotasi token dan login terlambat setelah sesi dibersihkan.
- [x] Tes widget counter template diganti smoke login aktual.
- [x] `flutter test --no-pub`: 9/9 lulus. Analyzer terarah untuk seluruh kode baru: `No issues found!`.
- [x] `flutter analyze --no-pub`: 8 isu lama (3 warning, 5 info), pada layar demo/model lama yang tidak disentuh slice ini; tidak ada isu baru pada kode terarah.
- [x] `git diff --check` untuk perubahan tracked slice ini lulus. Perubahan pengguna yang sudah ada pada `inventory_item_model.dart:68` mengandung trailing whitespace; tidak diubah oleh pekerjaan ini.
- [ ] APK debug belum terverifikasi. `flutter build apk --debug` memerlukan unduhan Gradle 9.1.0 dan Android SDK Build-Tools 36 pada mesin ini. Setelah keduanya terpasang, Gradle masih mengambil dependensi tanpa menghasilkan APK; proses dihentikan setelah lebih dari 10 menit. Ulangi build saat cache dependensi siap. Ini bukan bukti kegagalan kompilasi Dart.

Jalankan pada emulator Android dengan backend lokal yang tersedia:

```powershell
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Untuk staging gunakan `https://<host>/api/v1`. Akun dibuat melalui bootstrap backend; tidak ada kredensial bawaan. Panduan dependensi SQLite: [Flutter](https://docs.flutter.dev/cookbook/persistence/sqlite). Pemilihan skill melalui `find-skills` tidak menambah dependency atau skill baru untuk slice ini.
