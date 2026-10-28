# Setup Mobile HidroSense

Prasyarat: Flutter SDK dan perangkat atau emulator yang tersedia melalui `flutter devices`. Untuk Android, siapkan Android SDK dan `adb`.

Jalankan backend dan seeder terlebih dahulu sesuai [panduan backend](../../docs/panduan-menjalankan-backend.md). Gunakan kredensial akun uji yang dicetak oleh seeder untuk login.

## Memasang dependensi

Dari root repository:

```powershell
cd apps/mobile
flutter pub get
flutter devices
```

Perintah berikut dijalankan dari `apps/mobile`.

## Android melalui USB

Aktifkan USB debugging dan hubungkan perangkat:

```powershell
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

## Android Emulator

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

`10.0.2.2` menunjuk ke komputer host dari Android Emulator.

## Windows Desktop

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

## Perangkat melalui Wi-Fi

Atur `HOST=0.0.0.0` pada `.env` backend, restart backend, lalu gunakan IP LAN komputer host. Ganti IP contoh berikut dengan IP komputer Anda:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.15:3000/api/v1
```

Perangkat dan komputer harus terhubung ke jaringan yang sama, dan firewall komputer harus mengizinkan koneksi ke port backend.

## Build release

Isi URL backend HTTPS saat build:

```powershell
flutter build apk --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

Ganti URL contoh dengan backend deployment Anda. HTTP lokal hanya diizinkan oleh klien saat debug.

## Konfigurasi lokasi cuaca

Gunakan `BMKG_ADM4` untuk mengganti kode wilayah prakiraan cuaca saat menjalankan aplikasi:

```powershell
flutter run --dart-define=BMKG_ADM4=35.09.12.2002
```

Tambahkan `--dart-define=API_BASE_URL=...` sesuai perangkat yang digunakan.
