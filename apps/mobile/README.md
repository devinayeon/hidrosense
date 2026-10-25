# hidrosense_mobile

Aplikasi Flutter HidroSense.

## Integrasi cuaca BMKG

Halaman **Cuaca & Iklim** mengambil prakiraan langsung dari
`https://api.bmkg.go.id/publik/prakiraan-cuaca` memakai kode wilayah `adm4`
Desa Sabrang, Kecamatan Ambulu, Kabupaten Jember: `35.09.12.2002`.

Kode wilayah bisa diganti saat build tanpa mengubah kode:

```bash
flutter run --dart-define=BMKG_ADM4=35.09.12.2002
```

Data dipetakan ke suhu, kelembapan, curah hujan, angin, dan prakiraan harian.
Aturan rekomendasi perawatan berada di `lib/core/weather_rules.dart`. Jika BMKG
tidak dapat dihubungi, halaman menampilkan status gagal dan tombol coba lagi
(tidak memakai data contoh).

Dokumentasi lengkap: [`docs/bmkg-weather-integration.md`](docs/bmkg-weather-integration.md).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
