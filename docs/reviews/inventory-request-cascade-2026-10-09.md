# Diagnosis inventaris: request berulang dan simpan lambat

Tanggal: 9 Oktober 2026, Asia/Jakarta. HEAD diperiksa: `f039056`. Source aplikasi tidak diubah dalam investigasi ini.

**Status terbaru:** remediasi sudah diterapkan di working tree. Backend 203/203, mobile 139/139, analyzer nol diagnostik. Hasil implementasi dan batas verifikasi tercatat pada [Remediasi terverifikasi](#remediasi-terverifikasi).

Akar utama yang terbukti ada di integrasi mobile: orchestration refresh berulang dan pembacaan saldo per barang secara sequential. Endpoint backend menerima request yang berbeda untuk URL yang sama. Pada fixture 10 barang, 39 request memiliki 39 request ID berbeda; tidak ditemukan bukti satu respons backend dikirim berkali-kali.

## Findings berdasarkan bukti

1. **P1** [`inventory_repository.dart:120`](../../apps/mobile/lib/data/repositories/inventory_repository.dart#L120): POST stok sudah commit, tetapi kegagalan refresh berikutnya dilempar sebagai kegagalan penyimpanan. Form menangkap error di [`add_form_inventaris_page.dart:139`](../../apps/mobile/lib/views/pages/add_form_inventaris_page.dart#L139), tetap terbuka, dan retry menjalankan create dari awal. Pada backend fixture 100 barang, GET saldo terkena 429 setelah barang ID `101` dan saldo awal 10 tersimpan; ulang POST sesudah rate window berakhir membuat ID `102` dengan nama yang sama. Pisahkan receipt mutasi dari refresh; simpan ID hasil create dan UUID command supaya retry melanjutkan/replay tahap yang sama.
2. **P2** [`inventory_repository.dart:58`](../../apps/mobile/lib/data/repositories/inventory_repository.dart#L58), [`inventory_repository.dart:120`](../../apps/mobile/lib/data/repositories/inventory_repository.dart#L120), [`add_form_inventaris_page.dart:134`](../../apps/mobile/lib/views/pages/add_form_inventaris_page.dart#L134): satu tambah dengan stok awal memuat ulang seluruh katalog tiga kali. Setiap refresh memakai GET list lalu GET saldo setiap item di [`inventory_repository.dart:183`](../../apps/mobile/lib/data/repositories/inventory_repository.dart#L183). Letakkan satu refresh sesudah seluruh mutasi pada pemilik state; sertakan saldo dalam read model list untuk menghapus N+1 HTTP.
3. **P2** [`add_form_inventaris_page.dart:79`](../../apps/mobile/lib/views/pages/add_form_inventaris_page.dart#L79): `_saveForm` tidak memiliki guard `if (_saving) return`. Dua tap sebelum rebuild masih memakai callback enabled yang lama dan menghasilkan dua POST create pada probe widget. Tambahkan guard sinkron di handler dan UUID stabil pada create. Menonaktifkan tombol saat rebuild saja belum menutup race ini.
4. **P2** [`add_form_inventaris_page.dart:82`](../../apps/mobile/lib/views/pages/add_form_inventaris_page.dart#L82): nama kosong tidak mengubah `_saving`; setiap tap mengantrekan SnackBar baru. Probe tiga tap menunjukkan tiga notifikasi berurutan. Gunakan validasi inline atau ganti notifikasi aktif; ini masalah antrean notifikasi, bukan tiga request backend.

## Trace tambah barang dengan saldo awal

```text
AddFormInventarisPage._saveForm
  InventoryRepository.createItem
    POST inventaris                         barang sudah commit
    GET inventaris/:id/saldo
    refresh #1: GET list + GET saldo/item
  InventoryRepository.recordStockMovement
    POST stok + UUID                         stok sudah commit
    refresh #2: GET list + GET saldo/item
  ConnectedInventoryViewModel.refresh
    refresh #3: GET list + GET saldo/item
  Navigator.pop                             baru selesai menunggu
```

Dengan `N >= 1` barang aktif setelah penyimpanan dan `P = ceil(N/20)`, tambah dengan saldo awal memakai `3 + 3(N + P)` request aplikasi pada sesi valid, tanpa background load. Dua POST adalah create dan stok; satu GET saldo langsung dilakukan untuk barang baru. Tambah tanpa saldo awal memakai `2 + 2(N + P)`. Login/token refresh, load awal provider, dan request layar lain tidak dimasukkan.

## Reproduksi

| Skenario | Katalog sebelum/sesudah | Refresh list | GET saldo | Mutasi | Total |
| --- | --- | --- | --- | --- | --- |
| Tambah tanpa saldo awal, UI aktual + MockClient | 10 / 11 | 2 | 23 | 1 POST | 26 |
| Tambah saldo awal 10, UI aktual + MockClient | 10 / 11 | 3 | 34 | 2 POST | 39 |
| Ubah barang, UI aktual + MockClient | 10 / 10 | 2 | 21 | 1 PATCH | 24 |
| Tambah saldo awal, backend Fastify/LibSQL fixture | 10 / 11 | 3 | 34 | 2 POST | 39, seluruhnya berhasil |
| Tambah saldo awal, backend fixture lebih besar | 100 / 101 | Berhenti pada refresh kedua | Berhenti saat saldo ID 9 | Kedua POST 201 | 120 percobaan; terakhir 429 |

Fixture backend memakai database in-memory dan clock tetap. Login ikut mengonsumsi satu slot rate limit; 120 request pada operasi simpan berarti 121 request API termasuk login. Batas global existing 120 request/60 detik di [`app.ts:66`](../../apps/backend/src/app.ts#L66) menghasilkan 429 pada percobaan terakhir. Ini memperlihatkan request amplification yang dapat menghabiskan budget rate limit; bukan alasan menaikkan/menghapus limiter.

Pada fixture kecil, satu POST create terukur sekitar 5.3 ms dan request terlama sekitar 7.2 ms. Ini pengukuran lokal `app.inject`, tidak mencakup TCP, emulator, Turso atau jaringan pengguna. Durasi aktual insiden belum diketahui karena lampiran berupa analisis, bukan log runtime dengan timestamp. Reproduksi membuktikan jumlah dan urutan request; latency jaringan menambah biaya pada setiap `await` sequential.

Lima probe widget selesai dan mengonfirmasi perilaku bermasalah: 26 request tanpa stok awal, 39 dengan stok awal, 24 saat edit, tiga SnackBar untuk tiga tap nama kosong, dan dua POST saat dua tap sebelum rebuild. Probe backend mengonfirmasi commit, rate-limit, retry duplicate, serta penolakan body besar. Keberhasilan probe berarti gejala berhasil direproduksi, bukan bug sudah diperbaiki.

Tes existing `inventory_repository_test.dart` dan `inventory_archive_test.dart` juga dijalankan: 5/5 lulus. Tes tersebut membuktikan kontrak/cache/arsip tetap berjalan, tetapi tidak membatasi request count alur tambah/edit; sebab itu cascade bisa lolos dari tes existing.

Bukti disimpan di direktori temporary pengguna:

- `C:/Users/Delion/AppData/Local/Temp/hidrosense_inventory_trace_test.dart`
- `C:/Users/Delion/AppData/Local/Temp/hidrosense-inventory-trace-output.txt`
- `C:/Users/Delion/AppData/Local/Temp/hidrosense_inventory_backend_trace.mjs`
- `C:/Users/Delion/AppData/Local/Temp/hidrosense-inventory-backend-trace-output.jsonl`

Tidak melakukan mutasi pada server pengguna di port 3000 atau database produksi. Request yang menulis data hanya dijalankan pada fixture terisolasi.

## Cakupan empat fungsi inventaris

- **Tambah:** triple refresh bila saldo awal positif, double refresh tanpa saldo awal; create dan stock merupakan dua transaksi terpisah. Kegagalan GET/cache setelah commit tidak boleh memaksa create ulang.
- **Lihat:** satu refresh membaca semua halaman aktif dan satu saldo per item. Untuk 10 item satu halaman, pembacaan memerlukan 11 GET. Ini jalur N+1 yang sama dengan tambah/edit.
- **Ubah:** `updateItem` membaca saldo dan refresh penuh, kemudian form memanggil refresh ViewModel lagi. Probe UI mengonfirmasi 24 request untuk 10 item.
- **Arsip:** repository hanya POST deactivate; ViewModel melakukan satu refresh. Perbaikan ownership dari remediasi sebelumnya tetap ada. Namun refresh itu masih mempunyai N+1 saldo untuk barang aktif yang tersisa. Tes arsip existing memverifikasi satu mutasi, satu refresh list, cache/state, dan pesan sesudah sheet ditutup.

## Koreksi klaim backend dalam lampiran

| Klaim lampiran | Hasil pemeriksaan |
| --- | --- |
| GET inventaris tidak memiliki saldo | Benar. Kontrak list master memang belum menyertakan saldo. Ini peluang menggabungkan read model, bukan bukti INSERT/SELECT backend menggandakan respons. |
| COUNT dan SELECT tanpa read transaction | Tidak benar. Route memakai `db.batch([...], 'read')` di `inventaris.ts:34-40`; client LibSQL terpasang memulai transaksi dan commit batch, untuk SQLite maupun Hrana HTTP. |
| Request body limit tidak ada | Tidak benar. Fastify memakai `bodyLimit: 16 * 1024` di `app.ts:40`; probe JSON sekitar 20 KB menghasilkan 413 `PAYLOAD_TOO_LARGE`. |
| JSON round-trip merupakan bottleneck | Tidak terbukti. Tidak ada profile insiden yang menunjukkannya; request amplification sudah terukur. Normalisasi JSON juga membuang properti `undefined`, sedangkan `structuredClone` mempertahankannya. Mengganti clone saja belum tentu mempertahankan hash/idempotency. |
| COUNT(*) OVER() wajib sebagai simplifikasi | Tidak diperlukan untuk bug ini. Batch read existing sudah transactional; halaman kosong/out-of-range tetap membutuhkan total metadata, sehingga penggantian tidak otomatis lebih sederhana. |
| Log berulang berarti respons backend duplikat | Probe menunjukkan request ID berbeda untuk URL berulang. Logging bawaan request dimatikan; satu hook `onResponse` menulis `Request completed` di `app.ts:76-79`. Log asli pengguna belum tersedia untuk memastikan pola yang persis sama. |

`ApiClient` hanya retry setelah 401/token rotation, bukan setiap respons 200. Semua request pada fixture kecil berhasil tanpa 401, sehingga auth retry bukan penyebab pengulangan yang direproduksi.

## Ponytail-review

1. `inventory_repository.dart:L58`: delete: orchestration refresh setelah create yang sudah dimiliki caller. Reuse satu refresh akhir pada ViewModel.
2. `inventory_repository.dart:L91`: delete: orchestration refresh setelah update yang diulang form. Reuse refresh akhir yang sama.
3. `inventory_repository.dart:L120`: delete: orchestration refresh stok yang diulang form. Reuse refresh akhir setelah rangkaian mutasi.

`net: -3 lines possible.` Angka ini hanya menghitung tiga pemanggilan refresh duplikat yang terverifikasi; tidak mengklaim pengurangan 48 baris. Perubahan harus menyesuaikan ekspektasi cache pada tes/caller existing, bukan menghapus refresh tanpa memperbarui pemiliknya.

## Arah perbaikan yang diperlukan

1. Pisahkan status mutasi sukses, hasil tidak pasti, dan refresh gagal. Pertahankan ID barang setelah create; retry stok memakai ID itu, payload yang sama, dan UUID stok yang sama. Create juga memerlukan UUID stabil untuk replay setelah respons hilang.
2. Jadikan `ConnectedInventoryViewModel` pemilik satu refresh akhir untuk tambah/edit/stok, mengikuti ownership arsip yang sudah ada. Hindari full refresh di repository mutasi.
3. Perluas GET list dengan `LEFT JOIN stok_saldo`, baca exact minor units sebagai string, dan pakai pola `fromMinor` existing; sesuaikan mapper/cache mobile. Pertahankan batch read, izin, bounds pagination dan batas 400 baris. Tidak perlu dependency, tabel saldo baru, atau endpoint POST batch tambahan untuk kasus ini.
4. Guard `_saving` di awal handler; gunakan validasi field agar tap input invalid tidak menumpuk snackbar. Guard submit dan penghilangan antrean notifikasi adalah dua masalah terpisah.

Verifikasi perbaikan nanti harus mengukur request count setelah save, bukan hanya memastikan POST/cache berhasil. Sertakan kegagalan refresh/cache sesudah POST commit, kegagalan stok sesudah create, replay setelah respons hilang, dua tap sebelum rebuild, token refresh, dan katalog multipage. Jangan menyebut insiden selesai sebelum rerun membuktikan perilaku baru.

## Skill yang dijalankan

Perintah pengguna `npx skills use "https://github.com/celigo/ai" --skill "troubleshooting-flows"` selesai dengan exit 0. Output lengkap dibaca dan tersimpan di `C:/Users/Delion/AppData/Local/Temp/hidrosense-troubleshooting-flows.txt`. Output tidak menyediakan supporting-files directory. Workflow diagnosis diterapkan pada tahap form/repository/API/persistence HidroSense: klasifikasi lambat dan partial failure, request/response tracing, pengelompokan URL, fixture aman dan bukti commit. Perintah Celigo berbasis flow/job ID tidak relevan untuk aplikasi Fastify/Flutter ini.

Graphify dipakai untuk menemukan hubungan caller sebelum pembacaan source. `caveman-review`, `ponytail-review`, `backend-code-review`, dan `investigate-first` dipakai untuk review berdasarkan bukti. Tidak ada perbaikan source dalam turn diagnosis ini.

## Remediasi terverifikasi

Implementasi 9 Oktober 2026, sesudah diagnosis di atas; perubahan belum di-commit. Baseline source `f039056`, backend 202 tes dan mobile 113 tes. Findings P1/P2 di atas sudah diperbaiki untuk alur yang direproduksi. Klaim pagination P3 dari audit awal tetap tidak terbukti; validasi pagination existing dipertahankan.

- Backend menambahkan `saldo` (desimal exact berupa string) dan `di_bawah_minimum` pada list, detail, serta receipt mutasi inventaris. `LEFT JOIN stok_saldo` memakai saldo nol jika belum ada transaksi. Perhitungan memakai minor units, `fromMinor` dan `BigInt`; batch read, izin, limiter dan schema pagination dipertahankan. Tidak ada migrasi backend atau dependency aplikasi baru.
- Repository mengirim mutasi tanpa full refresh dan tanpa GET saldo. Satu refresh akhir dimiliki `ConnectedInventoryViewModel`; refresh membaca semua halaman dari read model yang sudah memuat saldo dan mengganti cache hanya setelah pembacaan lengkap. Refresh sesudah write menunggu pembacaan lama selesai agar snapshot sebelum mutasi tidak menjadi hasil akhir.
- ViewModel mempertahankan UUID create/PATCH, UUID stok, payload dan ID receipt create. Kegagalan stok melanjutkan ID yang sama; respons hilang memakai replay. Attempt counter mencegah respons dari ViewModel yang sudah disposed menghapus command retry yang lebih baru. Token refresh mempertahankan body/header; `SESSION_CHANGED` diperlakukan sebagai hasil belum pasti.
- Command di memori dipisahkan berdasarkan server dan akun, sehingga sesi kedaluwarsa tidak membuang receipt ketika akun yang sama login kembali. Akun/server lain tidak melihat draft tersebut. Form yang membuka barang berbeda menawarkan navigasi ke draft sebelumnya. State layar lama tidak diterapkan setelah disposal atau pergantian akun.
- Form memvalidasi nama dan angka secara inline sebelum POST, menahan dua tap sebelum rebuild, dan mengunci payload retry yang belum pasti. Kegagalan refresh/cache setelah commit menghasilkan pesan **barang tersimpan**, lalu menutup form. Pilihan **Selesai tanpa saldo awal** hanya tersedia setelah penolakan stok yang pasti; respons hilang atau 429 sesudah respons hilang tidak dapat dilewati. Pengguna dapat kembali setelah gagal karena command tetap disimpan di memori.

### Request count sesudah perbaikan

Penghitungan widget memakai form aktual, MockClient dan SQLite cache; load awal sesi/provider tidak dimasukkan. Dengan `P = ceil(N/20)`, tambah dengan saldo awal menggunakan `2 + P` request; tambah tanpa saldo awal dan edit menggunakan `1 + P`.

| Skenario | Sebelum | Sesudah | GET saldo sesudah |
| --- | ---: | ---: | ---: |
| Tambah, 10 menjadi 11 barang, tanpa saldo awal | 26 | 2 | 0 |
| Tambah, 10 menjadi 11 barang, saldo awal 10 | 39 | 3 | 0 |
| Edit, 10 barang | 24 | 2 | 0 |
| Tambah, 100 menjadi 101 barang, saldo awal 10 | 120 percobaan lalu 429 pada reproduksi lama | 8 berhasil | 0 |

Angka ini mengukur request, bukan kecepatan jaringan produksi. Tidak menaikkan rate limit untuk memperoleh hasil tersebut.

### Matriks bukti konektivitas

| Fungsi | Bukti UI | Bukti persistensi backend |
| --- | --- | --- |
| Tambah dan saldo awal | `inventory_save_widget_test.dart`: form → create → stok → satu refresh; dua tap menghasilkan satu POST | `inventory_backend_flow_test.dart`: fixture Fastify/LibSQL melalui HTTP lokal, 101 barang; respons stok dibuang setelah commit, replay tetap satu barang ID `101` dan satu histori stok dengan saldo `10` |
| Lihat | Provider/cache dan halaman existing tercakup suite mobile; form memakai hasil refresh | Fixture HTTP membaca 6 halaman tanpa GET saldo per item; cache menyimpan 101 record lengkap |
| Ubah | Form edit menghasilkan satu PATCH dan satu refresh | PATCH fixture yang sama mengubah nama/minimum, mempertahankan saldo `10`, dan memperbarui status minimum |
| Arsip | Tes arsip existing membuktikan sheet → satu mutasi → satu refresh dan pesan aman; tes backend/UI existing tetap lulus | Fixture HTTP mengarsip ID `101`, memuat 5 halaman aktif, memperbarui cache menjadi 100 record; detail arsip tetap menyimpan saldo `10` |

Tes tambah/edit UI menggunakan mock HTTP; tes persistensi tambah/edit menggunakan ViewModel/repository aktual dengan server fixture. Ini bukti gabungan, bukan klaim bahwa tambah/edit sudah diuji lewat perangkat fisik atau server produksi. Server pengguna port 3000 tidak dimutasi.

### Telemetry dan review

- `npm run check`: **203/203 PASS**, typecheck dan batas 400 baris backend PASS. Log `.codex/tmp/inventory-fix-backend-check.log`.
- `flutter test`: **139/139 PASS**. Log `.codex/tmp/inventory-fix-mobile-tests.log`.
- `flutter analyze`: **0 diagnostik**. Log `.codex/tmp/inventory-fix-analyze.log`.
- `flutter build apk --debug`: PASS; `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. Log `.codex/tmp/inventory-fix-build.log`.
- `git diff --check -- apps/backend apps/mobile`: PASS; analyzer dan kompilasi suite tidak menemukan dangling import.
- Regresi mencakup kehilangan receipt create/stok/PATCH, UUID/body replay, penolakan pasti, kegagalan refresh/cache setelah commit, 401/token refresh, pergantian sesi, disposal, respons stale, pembacaan lama sebelum mutasi, katalog multipage, validasi desimal, resume form berbeda, serta penyelesaian tanpa saldo.
- Review independen memakai requesting-code-review, caveman-review, ponytail-review dan backend-code-review. Dua putaran menemukan masalah pemulihan sesi/form dan race respons stale; semuanya diperbaiki dengan regresi. Putaran akhir tidak menemukan issue penting atau over-engineering.
- find-skills dijalankan; panduan [flutter-add-widget-test dari Flutter](https://github.com/flutter/agent-plugins/tree/main/skills/flutter-add-widget-test) dipakai tanpa menambah dependency. Output lengkap `.codex/tmp/inventory-widget-test-skill.txt`.
- `graphify update .` memperbarui graph JSON/HTML/report melalui AST. CLI keluar dengan status 1 sambil melaporkan warning: parser SQL opsional belum terpasang dan header Linux `my_application.h` diekstrak sebagian. Keduanya tidak diubah dalam remediasi; graph aplikasi TS/Dart berhasil diperbarui. Log `.codex/tmp/inventory-fix-graphify.log` mencatat `Code graph updated`.

### Delivery Gate antislop: PASS

Cakupan gate adalah form inventaris yang diubah dan kontrol pemulihannya. `inventory_form_layout_test.dart` menjalankan tema terang/gelap pada 320×568 dengan text scale 2, Tab/Enter/Escape, kategori/satuan, validasi, loading, retry, resume, dan selesai tanpa saldo. PNG di `apps/mobile/build/remediation-verification/inventory-{light,dark}-{large-text,validation,saving,retry}.png`; font capture memakai Segoe UI sebagai pengganti Inter, sesuai helper existing. PNG ditinjau langsung; font produksi tidak diubah.

- R-02 PASS: copy form baru tidak menggunakan em dash.
- R-03 PASS: dua tes layar 320×568/teks 2× lulus tanpa overflow; tinggi tombol simpan 52 pada skala 1 dan 104 pada skala 2; judul dapat dua baris.
- R-17 PASS: angka stok berasal dari isian/API; angka laporan berasal dari trace tes.
- R-18 PASS: tidak ada testimonial pada form.
- R-23 PASS: tidak membuat logo, avatar foto atau aset ilustrasi baru.
- R-24 PASS: back dan resume menuju route aktual; tidak menambah tab/link fiktif.
- R-25 PASS: kontras terhitung lime/navy 13.11:1, teks/putih 17.74:1, placeholder abu/putih 4.83:1; label pilihan memakai teks gelap. Ikon pilihan teal/putih 4.41:1.
- R-26 PASS: kategori/satuan dipilih dalam tes, Escape menutup sheet; save memanggil API; resume dan selesai tanpa saldo diklik dalam tes.
- R-27 PASS: form kosong menunjukkan validasi inline, loading menahan submit/back, kegagalan menampilkan error dan mempertahankan isian; refresh gagal dilaporkan terpisah dari save.
- R-28 PASS: tidak ada FAQ pada form.
- R-32 PASS: Tab dari input menuju selector, Enter membuka sheet, Escape menutupnya; selector memakai InkWell dengan fokus Material.
- R-33 PASS: perubahan fitur ditulis dalam source melalui apply_patch; tidak ada runtime patch/CSS injection.
- R-34 PASS: kedua tema lulus tes dan capture; pesan, placeholder dan pilihan memakai warna eksplisit dengan kontras yang dihitung.
- R-35 PASS: aplikasi dibangun, kontrol form diuji klik/keyboard, snapshot ditinjau; jalur persistensi memakai fixture terisolasi.
- R-36 PASS: tidak mengklaim latency produksi atau audit keamanan penuh.
- R-37 PASS: arah mempertahankan bahasa visual HidroSense telah diumumkan sebelum edit, ENERGY 1 / RHYTHM 2 / MOTION 1.
- R-38 PASS: data bernama Fixture/Benih dalam bukti adalah data tes; UI produksi tidak menambah statistik atau identitas rekaan.
- R-01 PASS: tidak menambah gradient/glow.
- R-04 PASS: ikon kategori existing mewakili benih, nutrisi, obat dan alat; tidak menambah ikon dekorasi AI.
- R-06 PASS: font dan bobot mengikuti AppTypography existing; tidak menambah monospace atau label uppercase.
- R-07 PASS: tidak ada pola grid/blueprint dekoratif.
- R-08 PASS: panah hanya untuk back dan membuka pilihan, bukan dekorasi tombol simpan.
- R-09 PASS: tidak menambah badge promosi.
- R-10 PASS: tidak menambah glassmorphism.
- R-12 PASS: mempertahankan elevasi existing; tidak menambah shadow setiap field.
- R-13 PASS: tidak menambah glow.
- R-14 PASS: komposisi mengikuti input nama, kategori, stok/satuan dan minimum; tidak menambah kartu fitur.
- R-19 PASS: motion existing tombol/sheet dipertahankan sebagai feedback; tidak menambah animasi masuk serentak.
- R-22 PASS: tidak menambah ilustrasi generik.
- Dials PASS: ENERGY 1 / RHYTHM 2 / MOTION 1 tertulis dan sesuai form operasional.
- Focal point PASS: tombol navy/lime tetap menjadi tindakan utama, terlihat pada capture.
- Whitespace PASS: jarak AppSpacing memisahkan kelompok input; stok/satuan berbagi satu baris.
- Accent PASS: lime menandai tindakan utama sesuai palet produk.
- Identity PASS: AppTypography, palet navy/lime dan radius field existing dipertahankan.
- Design Read PASS: arahan UI HidroSense dan dials disampaikan sebelum implementasi.
- C-1 PASS: perubahan warna untuk kontras, validasi untuk menghindari antrean SnackBar, dan tinggi header/tombol untuk teks besar punya tujuan terukur.
- C-2 PASS: save, kedua selector, resume, back, dan selesai tanpa saldo punya handler aktual yang diuji.
- C-3 PASS: setiap bagian adalah input inventaris atau informasi hasil simpan.
- C-4 PASS: tema, layar kecil, keyboard, loading/error dan sesi berbeda tercakup tes; receipt tidak dipakai setelah disposal oleh layar lama.
- C-5 PASS: tidak menambah testimonial/statistik pemasaran.
- R-05 PASS: komposisi form mengikuti data inventaris, bukan template hero/kartu.
- R-11 PASS: field radius 16, sheet radius 24 dan tombol pill mengikuti hierarki existing.
- R-15 PASS: CTA menyebut Simpan Barang, Simpan Perubahan, resume penyimpanan, dan selesai tanpa saldo.
- R-16 PASS: copy tidak menambah buzzword pemasaran.
- R-20 PASS: palet HidroSense dan field stok/satuan mempertahankan identitas aplikasi pertanian.
- R-21 PASS: remediasi mempertahankan tema existing; kedua tema yang diuji tetap berfungsi.
- R-29 PASS: palet produk existing dipakai, tanpa warna inti tambahan.
- R-30 PASS: tidak mengganti form dengan komposisi produk populer lain.
- R-31 PASS: layout tetap; perubahan visual terbatas pada kontras, field error, pesan hasil dan keterbacaan teks besar.

### Batas dan backlog

Deploy backend yang menyertakan read model saldo sebelum mobile baru: mapper sekarang memerlukan field saldo dalam list/receipt. Command retry dipertahankan di memori selama proses aplikasi hidup dan tidak dikirim otomatis; menutup aplikasi sepenuhnya belum mempunyai pemulihan command dari disk. Antrean offline/pemulihan lintas restart tetap backlog terpisah. Dua POST create/stok tetap transaksi terpisah; pilihan penyelesaian tanpa saldo tidak menghapus barang yang sudah dibuat. Pengukuran latency perangkat/Turso/jaringan pengguna memerlukan log runtime aktual dan belum diklaim di sini.
