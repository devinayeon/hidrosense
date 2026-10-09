# Penyemaian Bibit Petani: review dan remediasi

Tanggal: 2026-10-09. Baseline pembanding: `dd04e66`, termasuk empat perubahan penyemaian yang sudah ada di working tree saat tugas dimulai. Sumber kebutuhan: dua lampiran pengguna, *Mobile QA Test Plan & Feature Review* dan *QA Walkthrough & Test Report*, serta empat alur Petani yang disebutkan dalam permintaan.

## Hasil

Tambah, daftar/detail, edit jumlah/catatan, dan pemberitahuan kesiapan sejak usia 15 hari sekarang mempunyai implementasi dan pengujian regresi. Notifikasi berupa alert dashboard dan status pada daftar/detail aplikasi. Perhitungan usia memakai tanggal kalender Asia/Jakarta dari backend. Provider memperbarui data pada tengah malam Jakarta dan ketika aplikasi kembali aktif; timer dibatalkan saat provider dibuang atau sesi berubah.

Tanggal semai dan material yang sudah dikonsumsi tidak diedit melalui PATCH. Form menjelaskan tanggal tetap; koreksi jumlah benih tidak mengubah ledger konsumsi awal. Jumlah bibit dalam butir dipisahkan dari pemakaian inventaris dalam gram/kg. Inventaris kosong tidak menghasilkan ID atau pilihan benih fiktif.

## Standards

Review independen menemukan target sentuh Ubah terlalu kecil, kontras Ubah tidak cukup, potensi overflow progres usia, dan teks tanggal/jumlah yang tidak mengikuti pembesaran teks. Semuanya diperbaiki. Header, tombol, pencarian, dan susunan status menyesuaikan teks besar; target Ubah minimal 44 × 44. Label tombol terpusat dengan padding, dan warna teks status mengikuti palet dengan kontras yang cukup.

Pemeriksaan akhir reviewer Standards: tidak ada temuan konkret tersisa. Analyzer: nol diagnostik. Pemeriksaan backend: typecheck dan batas 400 baris lulus. `git diff --check` lulus.

Ponytail: hapus wrapper mutasi/status yang tidak memiliki konsumen; gunakan satu metode daftar yang membaca seluruh halaman; sederhanakan validasi angka tanpa BigInt/fallback string kosong yang tidak diperlukan. Tidak ditambah dependency, migrasi, abstraksi notifikasi, atau antrean offline.

## Spec

| Temuan awal | Dampak | Perbaikan dan bukti |
| --- | --- | --- |
| P1: hanya 50 batch dimuat | Batch lama yang siap pindah pada halaman kedua hilang dari dashboard | Repository membaca semua halaman dan memeriksa metadata/ID duplikat. Fixture 51 batch dan tes repository membuktikan batch siap pada halaman kedua tetap dimuat. |
| P2: tanggal edit berubah di form tetapi tidak ada dalam kontrak PATCH | Pengguna mengira tanggal berubah | Date picker hanya untuk tambah; tanggal tetap pada edit. Backend menolak field tanggal pada PATCH dan tanggal tambah setelah hari Jakarta berjalan. |
| P2: catatan kosong tidak dikirim | Catatan lama tetap tersimpan | PATCH mengirim `keterangan: ''`; detail yang dibuka kembali menunjukkan catatan kosong. |
| P2: receipt mutasi diabaikan dan refresh dapat gagal/bergabung dengan read lama | Detail/stok tampak belum berubah atau save dikirim ulang | ViewModel menyimpan receipt, menunggu read sebelumnya, memperbarui record, lalu melakukan refresh. Kegagalan refresh dilaporkan sebagai peringatan setelah simpan. |
| P2: `stok_konsumsi` tidak dipetakan | Riwayat konsumsi tidak tampil | Model membaca kontrak detail backend; detail memakai GET per ID, bukan mengganti detail dengan row daftar tanpa material. |
| P2: klaim pembaruan notifikasi otomatis belum didukung | Status hari ke-15 tetap lama saat aplikasi terbuka | Timer kalender Jakarta dan refresh saat resume; regresi membuktikan 14 → 15 dan disposal/sesi. |
| P2: batch selesai dapat diedit atau dibuka kembali | Status selesai tidak melindungi data | Backend 409 `SOWING_COMPLETED`; UI menyembunyikan edit/transfer pada batch selesai. Replay receipt penyelesaian tetap diterima. |
| P2: satuan stok mengikuti jumlah butir | Pemakaian gram/kg bisa salah | Form memilih benih aktif secara eksplisit dan mengirim jumlah pemakaian stok terpisah. Tes: 100 butir mengonsumsi 1.25 gram. |

Pemeriksaan akhir reviewer Spec: tidak ada temuan actionable tersisa untuk empat alur ini. Klaim A/B, peningkatan conversion, atau latency dari lampiran tidak dipakai sebagai bukti karena tidak tersedia pengukuran runtime yang mendukungnya.

## Matriks konektivitas dan bukti

| Alur Petani | Endpoint/kontrak | Bukti yang dijalankan |
| --- | --- | --- |
| Tambah | `POST /api/v1/penyemaian`: tanggal, jumlah benih, catatan, materials; UUID Idempotency-Key | Real HTTP login Petani + POST; respons dan database fixture tersimpan; replay tidak memotong saldo dua kali. Tes widget memisahkan 100 butir dan 1.25 gram, serta menolak inventaris kosong. |
| Lihat | GET daftar berhalaman dan GET detail per ID; material `stok_konsumsi` | HTTP list/detail dan membuka ulang data setelah edit; repository mempertahankan ID signed64 string; widget pencarian, navigasi dan riwayat material. |
| Ubah | `PATCH /penyemaian/:id`: jumlah benih/catatan, UUID | HTTP PATCH + GET baru menunjukkan 120 benih dan catatan kosong; widget detail → form → simpan → detail. Tanggal/material awal tetap. |
| Notifikasi usia | `usia_hari` dan `siap_pindah`; hanya batch aktif dengan sisa bibit yang dapat dipindah | HTTP fixture hari 14/15/16; tes timer/resume; dashboard membuka detail batch API yang tepat. |
| Session/retry | Permission sesi, scoped command per origin/akun, mounted/attempt guards | Tes timeout, token refresh, UUID/payload sama, submit ganda, receipt setelah disposal, akun berbeda, 422, serta pembatalan timer saat sesi berubah. |

Backend diuji dengan SQLite/LibSQL fixture terisolasi. Salah satu tes membuka listener HTTP pada port acak, melakukan login/POST/GET/PATCH/replay melalui `fetch`, lalu menutup server. Server pengguna pada port 3000 tidak ditulis. Tes widget/provider mobile memakai respons HTTP terkontrol; ini bukan klaim uji end-to-end pada perangkat pengguna atau database produksi.

## Telemetry

| Pemeriksaan | Baseline tugas | Hasil akhir |
| --- | --- | --- |
| Backend | 203 lulus | 208/208 lulus; typecheck dan check:lines lulus |
| Mobile | 138 lulus, 2 gagal dari 140 | 166/166 lulus |
| Flutter analyzer | 0 diagnostik | 0 diagnostik |
| APK debug | Build baseline tersedia | `flutter build apk --debug` lulus |
| Regresi mobile baru | Belum ada | 10 tes repository/ViewModel + 16 tes widget |
| Regresi backend baru | Belum ada | 5 tes, termasuk real HTTP dan 51 batch |

Dua kegagalan baseline mobile terkait detail legacy tanpa ProviderScope dan fixture transfer tanpa sesi/detail API yang valid. Preview legacy tetap kompatibel; fixture transfer sekarang menyediakan sesi berizin dan GET detail yang sesuai. Pemeriksaan izin produksi tetap dipertahankan.

Log lokal: `.codex/tmp/nursery-final-backend.log`, `nursery-final-mobile.log`, `nursery-final-analyze.log`, `nursery-final-apk.log`, `nursery-http-backend.log`, `nursery-widget-captures.log`. Capture dapat dibuat ulang dengan `RECORD_REMEDIATION_UI=1 flutter test test/nursery_widget_remediation_test.dart`; PNG berada di `apps/mobile/build/remediation-verification/nursery-*.png`. Pada Windows capture memakai Segoe UI sebagai font tes; font aplikasi tidak diganti.

## Delivery Gate antislop

Mode: during, global preference. Design Read: form dan pemantauan semaian Petani, mengikuti HidroSense. ENERGY 1 / RHYTHM 2 / MOTION 1. Bukti visual: daftar, detail, form, loading, empty, error pada 320 × 568, teks 2×, tema aplikasi dan konteks dark. Seluruh 12 kombinasi lulus tanpa overflow; screenshot diperiksa. Keyboard/insets, picker, search, navigasi, validasi dan simpan diuji.

- R-02 PASS: copy baru tidak memakai em dash; CTA menyebut tindakan penyemaian.
- R-03 PASS: 12 kombinasi ukuran/state/theme lulus; header/progres/status/tombol menyesuaikan teks 2× dan target Ubah ≥44.
- R-17 PASS: jumlah batch dan benih berasal dari records API; ketika belum dimuat, ringkasan menyatakan Belum dimuat tanpa statistik rekaan.
- R-18 PASS: tidak menambah testimonial atau identitas pelanggan pada layar pencatatan.
- R-23 PASS: tidak membuat logo, avatar/foto, statistik atau struktur navigasi baru; hanya menghubungkan kontrol penyemaian yang ada ke data aktual.
- R-24 PASS: navigasi daftar → detail → edit/tambah → kembali diuji dan seluruh halaman target tersedia; ikon akun existing menuju AccountPage.
- R-25 PASS: kontras textPrimary/white 17.74:1, textSecondary/white 4.83:1, textSecondary/canvasWarm 4.62:1, textPrimary/warningBg 16.29:1, dan lime/navy 13.11:1. Teks Ubah/status/pencarian memakai pasangan tersebut; capture kedua konteks tema diperiksa.
- R-26 PASS: search → detail → kembali → tambah, picker, selector, edit dan simpan memiliki handler dan tes klik aktual.
- R-27 PASS: loading/empty/error tercakup capture; inventaris kosong divalidasi; timeout menjaga draft; refresh gagal tidak mengulang POST.
- R-28 PASS: tidak ada FAQ generik pada layar penyemaian.
- R-32 PASS: Tab mempertahankan fokus input; Escape menutup selector; date picker dan keyboard/insets diuji.
- R-33 PASS: fitur berada dalam source versioned; perubahan source dan format diperiksa lewat diff, analyzer dan tes; tidak ada runtime patch/CSS injection.
- R-34 PASS: seluruh kombinasi state lulus di tema aplikasi dan konteks ThemeData.dark; warna foreground/surface eksplisit tetap terbaca.
- R-35 PASS: flutter analyze/test dijalankan, APK debug dibangun; klik kontrol tercatat pada tes widget dan persistensi backend diuji melalui HTTP.
- R-36 PASS: tidak mengklaim angka latency/conversion, keamanan penuh, atau verifikasi database produksi.
- R-37 PASS: Design Read dan dials diumumkan sebelum edit.
- R-38 PASS: data fixture diberi konteks tes; UI tidak menambahkan varietas, material, damage, atau statistik rekaan.
- R-01 PASS: tidak menambah gradient/glow.
- R-04 PASS: ikon calendar/edit/search/transfer menggambarkan tindakan yang diuji.
- R-06 PASS: AppTypography existing dipertahankan; tidak menambah font monospace/uppercase dekoratif.
- R-07 PASS: tidak ada grid/blueprint/dot pattern dekoratif.
- R-08 PASS: panah menunjukkan back/transfer yang benar-benar membuka alur; tombol simpan tidak memakai panah dekoratif.
- R-09 PASS: badge menunjukkan kesiapan/stage batch dari respons API, tanpa label promosi.
- R-10 PASS: tidak menambah glassmorphism.
- R-12 PASS: elevasi kartu existing dipertahankan, tanpa shadow baru setiap input.
- R-13 PASS: tidak menambah glow.
- R-14 PASS: kartu berisi batch API dengan catatan dan tindakan kondisional berdasarkan kesiapan/izin.
- R-19 PASS: motion existing hanya feedback tekan dan progres usia; timer data tidak menambah animasi template.
- R-22 PASS: tidak menambah ilustrasi generik.
- Dials PASS: ENERGY 1 / RHYTHM 2 / MOTION 1 sesuai form operasional dan hierarki daftar/detail.
- Focal point PASS: tombol navy/lime menandai simpan/tambah; status siap menandai pemantauan.
- Whitespace PASS: AppSpacing memisahkan tanggal, benih, konsumsi dan catatan; progres/detail memiliki kelompok tersendiri.
- Accent PASS: lime dipakai untuk tindakan utama sesuai palet HidroSense.
- Identity PASS: AppTypography, warna navy/lime/mint dan radius existing dipertahankan.
- Design Read PASS: arah Petani dan dials dinyatakan sebelum implementasi.
- C-1 PASS: perubahan memiliki alasan kontrak, persistensi, kontras, atau keterbacaan yang diuji.
- C-2 PASS: tidak ada kontrol penyemaian baru tanpa handler; save/search/date/seed/edit/back diuji.
- C-3 PASS: setiap bagian berasal dari tanggal/jumlah/material/catatan/kesiapan batch.
- C-4 PASS: retry, disposal, sesi, tema, keyboard, layar kecil dan error memiliki regresi.
- C-5 PASS: tidak menambah testimonial atau statistik pemasaran.
- R-05 PASS: layout mengikuti tugas pencatatan dan pemantauan, bukan template hero/bento.
- R-11 PASS: radius input, kartu/modal dan tombol berbeda sesuai token produk.
- R-15 PASS: CTA menyebut Simpan Penyemaian, Mulai Penyemaian Baru, Ubah dan Pindah ke Meja.
- R-16 PASS: copy tidak memakai buzzword pemasaran AI.
- R-20 PASS: bentuk input tanggal/benih/konsumsi dan palet existing mempertahankan konteks pencatatan pertanian.
- R-21 PASS: tema produk tetap; konteks dark diuji tanpa memaksa dark mode baru.
- R-29 PASS: memakai palet AppColors existing, tanpa warna inti tambahan.
- R-30 PASS: tidak meniru layout produk lain.
- R-31 PASS: tiap perubahan visual dijelaskan oleh target sentuh, kontras, teks besar, atau data aktual.

## Batas dan backlog

`graphify update .` memperbarui `graph.json`, `graph.html` dan `GRAPH_REPORT.md`: 6577 nodes, 9608 edges, 426 communities. Command berakhir dengan exit 1 disertai warning lingkungan existing: parser `tree_sitter_sql` tidak tersedia untuk 20 file SQL dan header Linux `my_application.h` diekstrak sebagian. Pembaruan graph AST berhasil; tidak ada klaim ekstraksi SQL lengkap.

Notifikasi OS/push saat aplikasi ditutup, penyimpanan retry ke disk setelah proses mati, antrean offline, serta pengukuran pada perangkat/Turso pengguna belum termasuk remediasi ini. Retry disimpan di memori selama proses hidup dan tidak dikirim otomatis. Tidak ada migrasi atau dependency tambahan. Deploy backend guard batch selesai/tanggal sebelum memakai mobile baru. Klaim readiness mengikuti backend yang berhasil dimuat; kegagalan jaringan menampilkan error dan dapat diperbarui kembali.
