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

## 5. Rujukan

- Keputusan: `qa/decisions.md` — **D-14** (online-only), **D-18** (TLS/LAN),
  **D-19** (menu Sinkron), **D-30** (penyebaran cukup didokumentasikan).
- Gap: `qa/rtm.md` — **G-17** (SRS offline-first vs online-only), **G-18** (menu Sinkron).
- Panduan revisi SRS: `qa/srs-revision-guide.md`.
