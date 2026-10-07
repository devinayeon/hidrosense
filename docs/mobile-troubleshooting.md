# Panduan Pemecahan Masalah Koneksi Mobile Flutter & Backend (Troubleshooting)

Dokumen ini menjelaskan akar masalah, solusi perbaikan, dan panduan konfigurasi jaringan untuk aplikasi mobile **HidroSense (Flutter)** saat berkomunikasi dengan server backend lokal (**Fastify**).

---

## 1. Gejala & Masalah

### Pesan Error yang Ditampilkan:
> *"Tidak dapat menghubungi layanan. Periksa koneksi lalu coba lagi."*

### Kondisi Terjadinya:
Percobaan login dengan pengguna `petani` dan kata sandi `Petani123456!` gagal di aplikasi Flutter, bukan karena kode status `HTTP 401 (Invalid Credentials)`, melainkan karena kegagalan pada lapisan konektivitas jaringan (`SocketException` / `ClientException` / `Connection Refused`).

---

## 2. Analisis Akar Masalah (Root Cause Analysis)

Setelah penelusuran komprehensif, ditemukan 4 penyebab utama:

1. **Resolusi Base URL Flutter Tidak Memiliki Fallback Otomatis**:
   - Di [session_viewmodel.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/viewmodels/session_viewmodel.dart), konfigurasi mengandalkan `String.fromEnvironment('API_BASE_URL')`.
   - Jika dijalankan tanpa parameter `--dart-define=API_BASE_URL=...`, URL bernilai string kosong `""`, yang memicu error konfigurasi.
   - Jika developer mengisikan `http://localhost:3000` pada **Android Emulator**, request diarahkan ke `127.0.0.1` internal emulator (bukan komputer host pengembang), sehingga menghasilkan `Connection Refused`.
   - Endpoint backend memiliki prefix `/api/v1` (contoh: `/api/v1/auth/login`). Jika Base URL diisi tanpa `/api/v1`, rute menjadi tidak cocok (*unmatched route / 404*).

2. **Pemblokiran Lalu Lintas Cleartext HTTP oleh Android OS**:
   - Android 9 (API level 28)+ secara default memblokir semua lalu lintas HTTP tanpa enkripsi (`http://`).
   - Di [AndroidManifest.xml](file:///d:/Dev/Projects/hidrosense/apps/mobile/android/app/src/main/AndroidManifest.xml), atribut `android:usesCleartextTraffic="true"` belum terpasang pada `<application>` berkas utama, sehingga OS Android langsung memutus koneksi sebelum paket keluar.

3. **Backend Binds Hanya ke Loopback `127.0.0.1`**:
   - Di [apps/backend/.env](file:///d:/Dev/Projects/hidrosense/apps/backend/.env), `HOST` terkonfigurasi ke `127.0.0.1`.
   - Jembatan jaringan Android emulator (`10.0.2.2`) dan perangkat fisik (LAN Wi-Fi `192.168.x.x`) membutuhkan Fastify mendengarkan pada seluruh antarmuka jaringan (`HOST=0.0.0.0`).

4. **Validasi Host Localhost pada `ApiClient` Menolak IP LAN**:
   - Di [api_client.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/data/services/api_client.dart), `_validateBase()` hanya mengizinkan host `localhost`, `127.0.0.1`, `10.0.2.2`, dan `::1`.
   - Pengujian menggunakan ponsel fisik melalui Wi-Fi lokal (`192.168.x.x` / `10.x.x.x`) ditolak secara internal oleh klien mobile.

---

## 3. Perbaikan yang Telah Diterapkan

### A. Otomatisasi Base URL Cerdas ([session_viewmodel.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/viewmodels/session_viewmodel.dart))
Ditambahkan fungsi `resolveApiBaseUri()`:
- **Android Emulator**: Otomatis menggunakan `http://10.0.2.2:3000/api/v1` saat debug mode.
- **Desktop / iOS Simulator / Web**: Otomatis menggunakan `http://127.0.0.1:3000/api/v1`.
- **Auto Remap `localhost`**: Jika developer memasukkan `localhost` atau `127.0.0.1` saat berjalan di Android, otomatis dialihkan ke `10.0.2.2`.
- **Auto Append `/api/v1`**: Jika URL yang diberikan belum memiliki akhiran `/api/v1`, otomatis ditambahkan.
- **Logging Transparan**: Saat debug mode, log `baseUri` dan detail error dicetak ke konsol via `debugPrint`.

### B. Izin Cleartext HTTP ([AndroidManifest.xml](file:///d:/Dev/Projects/hidrosense/apps/mobile/android/app/src/main/AndroidManifest.xml))
Menambahkan `android:usesCleartextTraffic="true"` ke tag `<application>` untuk mengizinkan request HTTP lokal selama pengembangan.

### C. Dukungan IP Jaringan Privat ([api_client.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/data/services/api_client.dart))
Memperluas fungsi `isLocalOrPrivateHost()` agar mengenali rentang IP privat IPv4 (`192.168.*`, `10.*`, `172.16-31.*`) pada mode debug.

### D. Binding Fastify ke Semua Antarmuka ([apps/backend/.env](file:///d:/Dev/Projects/hidrosense/apps/backend/.env))
Mengubah `HOST=127.0.0.1` menjadi `HOST=0.0.0.0` sehingga server siap menerima koneksi dari loopback, emulator, maupun perangkat lain di jaringan LAN.

---

## 4. Panduan Menjalankan & Pengujian untuk Developer Flutter

### Langkah 1: Pastikan Backend Aktif
Di terminal backend:
```bash
cd apps/backend
npm run db:migrate
npm run db:seed
npm run dev
```
*(Server akan menampilkan listening di `http://127.0.0.1:3000` dan IP LAN Anda)*.

### Langkah 2: Jalankan Aplikasi Flutter

#### Skenario 1: Perangkat Android Fisik (Kabel USB via `adb reverse`) - Direkomendasikan
Pastikan port 3000 dibalik dari ponsel ke PC:
```bash
adb reverse tcp:3000 tcp:3000
cd apps/mobile
flutter run
```
*(Aplikasi otomatis tersambung ke `http://127.0.0.1:3000/api/v1` melalui USB tunnel).*

#### Skenario 2: Windows Desktop / macOS / Linux / iOS Simulator
```bash
cd apps/mobile
flutter run -d windows
```
*(Aplikasi otomatis tersambung ke `http://127.0.0.1:3000/api/v1`).*

#### Skenario 3: Android Emulator (Tanpa `adb reverse`)
```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

#### Skenario 4: Perangkat Fisik Android/iOS (Tanpa Kabel, via Wi-Fi LAN)
Cari IP lokal komputer host (misal: `192.168.1.15`), lalu jalankan:
```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://192.168.1.15:3000/api/v1
```

### Langkah 3: Login Akun Pengujian
Gunakan akun uji yang sudah terverifikasi:
- **Petani**: Username `petani`, Password `Petani123456!`
- **Pegawai**: Username `pegawai`, Password `Pegawai123456!`
