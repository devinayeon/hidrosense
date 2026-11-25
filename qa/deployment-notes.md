# qa/deployment-notes.md — Catatan penyebaran & model koneksi

Catatan ini merangkum **model penyebaran aplikasi** dan hal-hal koneksi yang perlu
diputuskan/didokumentasikan. Dibuat pada sesi 4 (24 Nov 2026) mengikuti **D-30**
(D-18 cukup didokumentasikan, keputusan final masih menunggu PM/tim).

Bahasa singkat: ini **catatan**, bukan bug. Isinya dipakai saat menyiapkan APK rilis
dan saat menjawab pertanyaan penguji "aplikasi ini online atau offline?".

---

## 1. Aplikasi bersifat online-only (D-14)

- **Keputusan PM (24 Nov 2026, D-14):** aplikasi dipakai **saat online**. Tidak bisa
  mencatat/mengakses menu saat offline adalah perilaku **wajar, bukan bug**.
- Implikasi: setiap simpan langsung dikirim ke server. Antrean sinkron hanya berisi
  kiriman yang **gagal** (mis. jaringan putus di tengah proses); saat online antrean
  kosong berarti semua data sudah aman di server (D-19).
- Test case yang mengasumsikan kerja offline diubah menjadi **N/A** (tanpa dihapus),
  lihat `qa/manual_checklist.md` §E/§F dan `qa/testing.md` §5.
- Pengecualian: **inferensi deteksi hama TFLite tetap lokal** (di perangkat, tanpa
  server). Hanya layar Deteksi hama yang memuat data meja/batch dari server, sehingga
  membukanya tetap butuh internet — ini bukan bug.

## 2. Alamat server & keamanan transport

- Klien hanya menerima **HTTPS** secara bawaan. Default `kAllowInsecureHttp = false`
  di `apps/mobile/lib/viewmodels/session_viewmodel.dart`.
- Untuk **uji LAN** (server di laptop, satu WiFi, `http://192.168.x.x:3000`) dipakai
  build khusus dengan flag:

  ```bash
  flutter build apk --release --dart-define=ALLOW_INSECURE_HTTP=true
  ```

  Flag ini **hanya** untuk uji internal; **tidak** mengubah default build rilis.
  Perilakunya diuji di `apps/mobile/test/session_insecure_http_test.dart`.
- **Perlu keputusan PM/tim:** model penyebaran rilis — server **HTTPS** (cloud/TLS)
  atau **LAN**? Selama belum diputuskan, rilis resmi diasumsikan HTTPS.

## 3. Yang harus disiapkan agar rilis jalan

| Hal | Status | Catatan |
|---|---|---|
| Base URL API | perlu diisi | lewat konfigurasi build/`dart-define`; arahkan ke server HTTPS |
| Kredensial Cloudinary (server) | **sudah diisi backend** | tanpa ini simpan pindaian gagal (BUG-16) |
| Kunci TFLite & aset model | sudah ada | inferensi jalan lokal di perangkat |
| Izin notifikasi (`POST_NOTIFICATIONS`) | gap (D-17) | belum ada alur permintaan izin; notifikasi native belum ada |
| Mode gelap | ditunda (D-16) | hanya satu tema terang |

## 4. Lingkungan uji yang dipakai QA

- DB uji selalu di `/tmp/opencode/hsqa/` (kueri audit & skrip), **bukan** data produksi.
- Kredensial Cloudinary untuk uji = **palsu** khusus QA (`hsqa`).
- Skrip menjalankan ulang ada di `qa/README.md`.

## 5. Kontrak respons & prasyarat data (catatan Sesi 6, 25 Nov 2026)

- **Respons 204 tanpa body.** `POST /api/v1/employees/:id/deactivate`, `.../activate`, dan
  `POST /api/v1/auth/logout` membalas **204 No Content** (tanpa body). Klien menerima body
  kosong pada status 2xx sebagai `{}` (BUG-48). Bila menambah endpoint "aksi tanpa isi"
  lain, pakai pola yang sama dan pastikan klien tidak menuntut body.
- **Prasyarat data, bukan kontrak.** Pesan "Kategori barang belum tersedia" (K-08/BUG-50)
  muncul bila `GET /jenis-inventaris` mengembalikan **0 kategori aktif**. Seed backend lokal
  mengembalikan **4 kategori aktif** (Benih, Nutrisi, Obat & Pestisida, Perlengkapan) dan
  `POST /inventaris` **201**, jadi jalur ini menandakan data/jaringan, bukan kontrak yang
  tak didukung. **Perlu diverifikasi tim backend:** pastikan server deploy juga ter-seed
  kategori & obat (kalau kosong, pengguna petani tak bisa menambah barang).
- **Peran dropdown meja di deteksi (K-28/BUG-55).** Pemilih "Meja tanam" hanya memuat meja
  dengan `tanaman_aktif > 0` (dihitung server, `tables/store.ts`). Bila semua meja kosong,
  klien kini menjelaskan prasyaratnya; ini perilaku data, bukan bug tombol.

## 6. Rujukan

- Keputusan: `qa/decisions.md` — **D-14** (online-only), **D-18** (TLS/LAN),
  **D-19** (menu Sinkron), **D-30** (penyebaran cukup didokumentasikan),
  **D-33..D-39** (triase Sesi 6 dan keputusan yang menunggu).
- Gap: `qa/rtm.md` — **G-17** (SRS offline-first vs online-only), **G-18** (menu Sinkron),
  **G-19..G-21** (NFR-5, profil petani, aktivasi ulang pegawai).
- Panduan revisi SRS: `qa/srs-revision-guide.md`.
