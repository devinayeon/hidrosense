# Integrasi Prakiraan Cuaca BMKG

Dokumen ini menjelaskan implementasi data cuaca BMKG pada aplikasi mobile
HidroSense, termasuk sumber data, pemetaan field, aturan rekomendasi, dan
penanganan kegagalan.

## 1. Ringkasan

Fitur **Cuaca & Iklim** sekarang mengambil prakiraan langsung dari API publik
BMKG. Data contoh statis sudah dihapus. Jika layanan BMKG tidak dapat diakses,
aplikasi menampilkan status gagal dan tombol **Coba Lagi**, bukan data palsu.

| Item | Nilai |
|---|---|
| Endpoint | `https://api.bmkg.go.id/publik/prakiraan-cuaca` |
| Kode wilayah default | `35.09.12.2002` |
| Lokasi | Desa Sabrang, Kecamatan Ambulu, Kabupaten Jember |
| Mitra | Hidro Selada |
| Format respons | JSON |
| Autentikasi | Tidak diperlukan |

Kode wilayah dapat diganti tanpa mengubah kode sumber:

```bash
flutter run --dart-define=BMKG_ADM4=35.09.12.2002
```

## 2. Alur Data

```text
CuacaPage
  -> weatherViewModelProvider
    -> BmkgWeatherService.fetchWeather()
      -> GET api.bmkg.go.id/publik/prakiraan-cuaca?adm4=...
        -> parseBmkgWeather()
          -> WeatherData + List<PrakiraanHarian>
            -> CuacaBody
            -> RekomendasiCuacaBody
```

Service dibuat sebagai provider `autoDispose` dan `http.Client` ditutup saat
halaman tidak lagi digunakan. Tidak ada penyimpanan riwayat cuaca, sesuai
kebutuhan PRD.

## 3. Berkas Utama

| Berkas | Fungsi |
|---|---|
| `lib/data/services/bmkg_weather_service.dart` | HTTP client, validasi respons, parser, dan pemetaan ke model aplikasi |
| `lib/core/weather_rules.dart` | Aturan rekomendasi perawatan berbasis parameter cuaca |
| `lib/viewmodels/weather_viewmodel.dart` | State loading, data, error, retry, dan refresh |
| `lib/views/pages/cuaca_page.dart` | Halaman cuaca dan tombol refresh |
| `lib/views/components/cuaca_body.dart` | Ringkasan kondisi dan daftar prakiraan harian |
| `lib/views/components/rekomendasi_cuaca_body.dart` | Detail tindakan rekomendasi |
| `test/bmkg_weather_service_test.dart` | Tes HTTP, parser, dan validasi lokasi |
| `test/weather_rules_test.dart` | Tes ambang aturan rekomendasi |
| `test/weather_test.dart` | Tes viewmodel dan widget halaman cuaca |

## 4. Pemetaan Data BMKG

| Field BMKG | Pemakaian di HidroSense |
|---|---|
| `lokasi.desa`, `lokasi.kecamatan`, `lokasi.kotkab` | Nama lokasi pada header |
| `lokasi.timezone` | Label WIB/WITA/WIT |
| `data[0].cuaca[].local_datetime` | Pengelompokan hari dan pemilihan prakiraan terdekat |
| `t` | Suhu saat ini dan suhu maksimum harian |
| `hu` | Kelembapan saat ini dan maksimum harian |
| `tp` | Akumulasi curah hujan harian (mm) |
| `weather_desc` | Kondisi cuaca dan dasar deteksi hujan |
| `ws` | Kecepatan angin (km/jam) |
| `wd` | Arah angin, ditampilkan sebagai arah datangnya angin |

Data dipetakan ke `WeatherData` dan `PrakiraanHarian` yang sudah dipakai UI.
Prakiraan dikelompokkan per tanggal menjadi label `Hari Ini`, `Besok`, lalu nama
hari.

## 5. Aturan Rekomendasi

Aturan berada di `lib/core/weather_rules.dart` dan dijalankan setiap kali data
BMKG berhasil diparse.

| Kondisi | Tindakan | Label |
|---|---|---|
| Suhu maksimum `> 32°C` | Atur debit nutrisi meja NFT dan cek EC/pH | Penting |
| Suhu maksimum `30–32°C` | Pantau suhu larutan | Rutin |
| Ada deskripsi hujan atau curah hujan `>= 0,5 mm` | Lindungi instalasi dan sesuaikan EC larutan | Penting |
| Kelembapan maksimum `>= 85%` | Waspadai jamur daun dan atur ventilasi | Penting |
| Angin maksimum `>= 20 km/jam` | Periksa rangka dan naungan | Rutin |
| Tidak ada kondisi di atas | Lanjutkan perawatan rutin | Rutin |

Ringkasan dan daftar tindakan ditampilkan pada halaman rekomendasi cuaca.

## 6. Penanganan Kegagalan

- Timeout koneksi: 20 detik.
- Status HTTP bukan `200`: layanan dianggap tidak tersedia.
- Respons bukan JSON atau struktur tidak lengkap: data ditolak.
- `adm4` yang dikembalikan berbeda dari lokasi mitra: data ditolak.
- UI menampilkan pesan gagal dan tombol retry.
- Data lama tidak dipertahankan sebagai data palsu atau riwayat.

## 7. Pengujian

```bash
cd apps/mobile
flutter analyze
flutter test
```

Hasil terakhir:

- `flutter analyze`: tidak ada issue.
- `flutter test`: 364 tes lulus, termasuk tes parser, service, aturan, dan
  widget cuaca.
- Respons API nyata untuk `35.09.12.2002` sudah diverifikasi mengembalikan
  lokasi `Sabrang, Ambulu, Jember`.

## 8. Batasan

- Aplikasi memanggil BMKG langsung dari perangkat. Untuk target Flutter Web,
  kebijakan CORS BMKG dapat memerlukan proxy backend.
- Data cuaca tidak disimpan sebagai riwayat, sesuai PRD.
- Rekomendasi bersifat pendukung keputusan dan tetap perlu disesuaikan dengan
  pengamatan lapangan.
