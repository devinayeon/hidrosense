# Progress — Login v2, logo maskot, dan sesi tersimpan

Dokumen ini catatan kerja untuk tiga tugas lanjutan setelah slice
[`01 Onboarding & Auth`](./progress-v2-onboarding-auth.md): memperbaiki logo
maskot di halaman login v2, menyambungkan login v2 ke login yang sudah ada,
dan mekanisme sesi supaya login bisa dilewati dalam masa berlaku tertentu.

Terakhir diperbarui: 17 November 2026.

## Tujuan

1. Hilangkan latar putih di belakang logo kucing pada halaman login v2.
2. Pakai proses login sungguhan (`SessionViewModel` + API) di halaman login v2,
   dengan rujukan form login lama di `lib/views/pages/login_page.dart`.
3. Saat aplikasi dibuka lagi, lewati halaman login kalau sesi tersimpan masih
   dalam masa berlaku.

## Aturan yang disepakati

- Semua kode view baru tetap di `apps/mobile/lib/views/v2`.
- Komponen khusus halaman diletakkan di `lib/views/v2/components`.
- Tidak menambah file test baru ke suite; tes yang sudah ada tetap dipakai,
  verifikasi tambahan memakai skrip sekali pakai yang langsung dihapus.
- Catatan progress/task di `apps/mobile/docs`.

## Peta file

Diubah:

- `lib/views/v2/components/v2_login_brand.dart` — logo maskot tanpa kotak putih.
- `lib/views/v2/pages/v2_login_page.dart` — `V2LoginResult`/`V2LoginHandler`
  baru; sukses hanya lanjut ke 1.10 di mode pratinjau.
- `lib/views/v2/pages/v2_onboarding_page.dart` — teruskan `onLogin` ke login.
- `lib/views/pages/login_page.dart` — `_v2Login` (login sungguhan) + tombol
  “Coba tampilan v2” meneruskan handler itu.
- `lib/data/services/api_client.dart` — getter token & kedaluwarsa,
  `setTokens(accessExpiresAt:, refreshExpiresAt:)`, `clearSession` mereset
  kedaluwarsa, `SessionUser.toJson()`, dan `me()` (`GET auth/me`).
- `lib/viewmodels/session_viewmodel.dart` — `SessionFailure` +
  `classifyFailure`, `SessionState.failure`, `restore()`, `_verify()`,
  `_persist()`, `_clearStore()`.
- `lib/main.dart` — `main()` async: pulihkan sesi sebelum `runApp` lewat
  `UncontrolledProviderScope`.

Baru:

- `lib/data/services/session_store.dart` — penyimpanan sesi lokal (sqflite),
  `StoredSession` + `SessionStore` (`save`/`read`/`clear`, satu baris per
  alamat layanan).

Tidak diubah: `lib/views/pages/app_gate.dart` — gerbang `user == null ? LoginPage
: MainPage` yang sudah ada, yang otomatis membuat sesi hasil restore langsung
membuka beranda.

## Keputusan penting

- **Logo.** Bingkai `Logo` di FigCraft (node `5177`, 81×112) punya fill putih
  dengan `visible: false`, jadi latarnya harus tembus ke warna halaman.
  `V2LoginBrand` dulu membungkus `Image.asset` dengan
  `ColoredBox(color: V2Colors.white)`, itulah kotak putih yang terlihat.
  Pembungkus itu dihapus; PNG maskot sendiri sudah transparan.
- **Login sungguhan tetap lewat presenter.** `V2LoginPage` tidak menyentuh
  Riverpod; ia menerima `V2LoginHandler`. Di aplikasi nyata, handler itu
  disuntikkan dari titik pemanggil (`login_page.dart` → `_v2Login`) sehingga
  halaman v2 tidak perlu tahu Riverpod dan entry pratinjau
  (`v2_auth_preview_main.dart`) tetap jalan tanpa provider.
- **Pemetaan kegagalan ke layar alur.** `SessionFailure` dibuat agar pengalih
  bahasa error tidak bergantung pada teks pesan:
  `invalidCredentials` → 1.7, `accountDeactivated` → 1.8, `offline` → 1.9,
  sisanya (mis. kuota permintaan) → 1.7 dengan pesan asli layanan.
  Backend: 401 `INVALID_CREDENTIALS` → `rejected`; 403 `ACCOUNT_DEACTIVATED`
  → `inactiveAccount`; tanpa jaringan/timeout/`CONFIGURATION` → `offline`;
  `ApiException`/`FormatException` lain → `rejected` + pesan layanan.
- **Sukses ganda.** Tanpa handler (pratinjau) sukses mendorong 1.10 izin
  notifikasi; dengan handler sungguhan, `AppGate` yang mengganti seluruh layar
  begitu `state.user` terisi, jadi halaman v2 tidak mendorong apa pun.
- **Penyimpanan sesi pakai sqflite, bukan dependency baru.** Polanya mengikuti
  `InventoryCache` (injeksi `Database` + `static open()`), memakai `session.db`
  dengan satu baris per `server_origin`. `SessionStore.open()` mengembalikan
  `null` kalau basis data tidak tersedia (mis. tes tanpa plugin) dan
  `save`/`read`/`clear` menelan error, jadi tak ada satu pun jalur yang
  melempar ke UI.
- **Restore ditunggu, verifikasi tidak.** `main()` menunggu hanya pembacaan
  lokal, jadi aplikasi yang punya sesi langsung membuka beranda tanpa kedipan
  splash. Setelah itu `auth/me` dipanggil di latar; logout hanya terjadi kalau
  layanan benar-benar menolak dengan 401. Gangguan jaringan tidak membuang
  sesi lokal.
- **Masa berlaku berasal dari layanan.** Yang dipakai `refresh_expires_at`
  (sliding 7 hari, maksimal 30 hari sejak login). Sesi tanpa tanggal
  kedaluwarsa dianggap kedaluwarsa (gagal tertutup). Karena itu klien tidak
  perlu menebak TTL sendiri.
- **Token hanya di penyimpanan sesi.** Password tidak pernah disimpan; token
  disalin ke `SessionStore` hanya setelah login sukses dan dihapus saat logout
  atau saat sesi kedaluwarsa.

## Masalah yang ditemukan dan solusinya

1. **Kotak putih di belakang logo.** Penyebabnya pembungkus `ColoredBox`
   putih, bukan PNG-nya (PNG transparan). Solusi: pembungkus dihapus.
2. **Login v2 dulu tidak memanggil layanan** dan hasil suksesnya selalu
   mendorong 1.10. Solusi: `V2LoginOutcome` diperluas + `V2LoginResult`
   membawa pesan server opsional; percabangan sukses dibedakan pratinjau vs
   sungguhan.
3. **Tes lama membangun `SessionViewModel(api, initialState: ...)`** tanpa
   basis data. Solusi: `openStore` opsional dan `SessionStore.open()` tidak
   pernah melempar, jadi tes tetap jalan tanpa plugin sqflite.
4. **Sesi tersimpan tapi token sudah mati.** Solusi: `restore()` langsung
   memakai data lokal, lalu `_verify()` memanggil `auth/me`; hanya 401 yang
   mengakhiri sesi.

## Verifikasi

- `flutter analyze`: bersih, kecuali 2 warning lama (folder aset
  `assets/illustrations/inventory/` dan `assets/illustrations/features/` tidak
  ada).
- `flutter test`: 424 tes lulus (dua run penuh terakhir).
- **Login sungguhan + sesi (backend hidup di `127.0.0.1:3000`).** Diuji lewat
  skrip verifikasi sementara (`flutter test` pada satu berkas di `tool/`, lalu
  dihapus) yang memakai `ApiClient`/`SessionViewModel`/`SessionStore` asli:
  1. password salah → `ApiException` `INVALID_CREDENTIALS` →
     `classifyFailure` = `invalidCredentials` (layar 1.7). Lulus.
  2. kredensial seed `petani` / `Petani123456!` → `SessionUser` role `petani`,
     `access_token` & `refresh_token` terisi, `refresh_expires_at` di masa
     depan. Lulus.
  3. sesi disimpan, lalu klien baru tanpa token + `restore()` → `true`, user
     terbaca, dan setelah 2 detik verifikasi latar (`auth/me`) user tetap ada
     tanpa error (tidak terlempar ke login). Lulus.
  4. sesi kedaluwarsa (`refresh_expires_at` di masa lalu) → `restore()` =
     `false`, user `null`, baris sesi ikut dihapus. Lulus.
  5. layanan tidak bisa dihubungi (port tertutup) → error bukan `ApiException`
     → `classifyFailure` = `offline` (layar 1.9). Lulus.
  6. kode 403 `ACCOUNT_DEACTIVATED` → `accountDeactivated` (layar 1.8),
     429/`FormatException` → `service`. Lulus.
- **Logo maskot (regresi).** Skrip verifikasi sementara merender
  `V2LoginBrand` di dalam `RepaintBoundary` dengan latar merah, lalu membaca
  piksel sudut kotak logo 81×112 (PNG-nya transparan di sana):
  - versi diperbaiki → `#ff0000` (latar halaman tembus), lulus;
  - versi lama (dengan `ColoredBox` putih) → `#ffffff`, gagal.
  Jadi tes ini memang menangkap bug lama; berkas skrip lalu dihapus.
- **Catatan emulator.** Emulator `Medium_Phone_API_37.0` di mesin ini
  `SIGSEGV` saat cold boot (sudah dicoba tanpa window, `-gpu off`, `-gpu
  swiftshader_indirect`, `-wipe-data`, `QT_QPA_PLATFORM=xcb`, dan `-feature
  -Vulkan`); `emulator -accel-check` melaporkan KVM sehat. Karena itu
  verifikasi berjalan di host (skrip di atas) dan bukan lewat tangkapan layar
  emulator. Jalur UI-nya sendiri tidak berubah selain yang terdokumentasi.
- `graphify update .` dijalankan di root repo.

## Catatan

- `growth_backend_flow_test` menyalakan server backend sungguhan. Saat seluruh
  suite berjalan bersamaan, proses itu sesekali lambat sampai halaman melewati
  batas tunggu 150×20 ms milik tes (“Memuat meja...”), padahal lulus saat
  dijalankan sendiri; dua run penuh terakhir lulus 424. Tes tidak diubah karena
  bukan regresi deterministik.

## Rencana lanjutan

1. Izin notifikasi sistem sungguhan di 1.10 dan dorong 1.10 setelah login
   sungguhan (saat ini hanya pratinjau).
2. Tautkan halaman alur v2 dari galeri v2 (`v2_gallery_page.dart`).
3. Aksi “Tambah meja tanam” ke alur 6.6.

## Cara menguji ulang

```bash
cd apps/mobile
flutter analyze
flutter test
# aplikasi biasa + backend di 127.0.0.1:3000 (adb reverse tcp:3000 tcp:3000)
flutter run
```
