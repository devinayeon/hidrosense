# Remediasi panen Petani, 10 Oktober 2026

Status: backend dan mobile panen persisten telah diimplementasikan. Empat kebutuhan dibuktikan melalui UI HTTP terisolasi dan AVD. Final review dan perbaikan UI disetujui tanpa temuan Critical/Important terbuka. Suite lengkap, analyzer, kedua build debug, serta QA native setelah perbaikan lulus. Pemeriksaan integrasi workspace dan graph dicatat di bagian penutupan.

## Baseline

Base `56d8f96`; perubahan QA pengguna dipertahankan sebelum penggantian mock. Pemeriksaan awal: backend 214/214, mobile 234/234, panen 8/8. Analyzer: enam unused-import warning dan empat deprecated `debugState` info pada tes panen. Tes lama memakai state dalam memori sehingga tidak membuktikan persistensi.

## Standards

- Selesai: validasi desimal dan kalkulasi sortasi dipindahkan ke model/draft; repository, Riverpod ViewModel, serta UI memakai layering existing.
- Selesai: state produksi memakai snapshot server; mock `panen_model.dart` dihapus. Provider mengikuti server/akun; respons lama tidak mengganti receipt yang lebih baru.
- Selesai: tombol PDF dan cabang modal/helper tanpa pemanggil dihapus. Implementasi persistensi menambah kode model/repository/state yang dibutuhkan; potensi penghapusan 55 baris bukan target pengurangan net seluruh fitur.
- Review Task 2 menemukan hydration edit dari cache sebelum GET sendiri serta refresh beberapa meja yang saling membatalkan. Keduanya diperbaiki dan diregresikan memakai provider meja nyata.
- QA native menemukan target kembali 40 dp; ukuran efektif kini 44×44 dp. Final review menemukan day-cell kalender 37,7×32 dp dan batas input 1,24:1. Picker memakai inputOnly; warna input/chip diperbaiki khusus tema panen, dengan pemeriksaan warna efektif yang dirender.
- Diagnostik kegagalan baca yang sengaja diinjeksi pada tes tetap memakai logger existing; final reviewer menerima ini sebagai Minor nonblocking. Tidak ada refactor logging produksi.

## Spec

- Selesai: GET list/detail, POST dua atau lebih batch, PATCH berat/catatan, dan `panen:write` Petani tersedia. Izin Pegawai existing dipertahankan; anonim/nonaktif ditolak.
- Selesai: estimasi semai +45 hari dan HSS/HST berasal dari seluruh halaman pemindahan nyata dengan tanaman aktif. Tidak ada proyeksi berat, grade, harga, atau pcs rekaan. Usia diperbarui pada tengah malam Jakarta/resume dan timer dibatalkan saat disposal.
- Selesai: jumlah tanaman adalah integer; total/reject/layak adalah kg desimal exact. NaN, infinity, eksponen, pecahan berlebih, duplikasi batch, dan saldo tidak cukup ditolak.
- Selesai: tanggal, sumber batch, dan jumlah immutable saat koreksi; berat layak tidak boleh turun di bawah penjualan tercatat. Konflik version/saldo memberi 409 dengan rollback receipt/version/data.
- Selesai: detail dibuka melalui ID; GET milik halaman edit harus selesai sebelum hydration. Loading/error/404 tidak memakai objek navigasi atau cache lama sebagai fallback.
- Selesai: UUID/payload/receipt disimpan per server/akun/target selama proses aplikasi hidup. Hasil belum pasti diulang dengan command yang sama. Receipt digabung sebelum satu siklus refresh panen, batch, dan setiap meja terkait; refresh gagal tetap berstatus tersimpan.

## Implementasi backend

GET list/detail dan POST/PATCH panen tersedia; kedua role membaca/menulis dengan pemeriksaan route dan transaksi. Payload multi-batch, tanggal Jakarta, batas tanaman aktif, sold floor, optimistic version, receipt/replay, dan rollback seluruh aggregate diuji. Jumlah tanaman mencakup semua hasil panen; reject kg tidak membuat laporan kerusakan tambahan. PATCH bobot/catatan tidak mengubah tanaman aktif.

Migrasi `0011_harvest_weights` menambah integer skala100 dan nullable reject, mempertahankan kolom legacy. Backfill menolak desimal tidak valid dan roundtrip REAL ambigu; tidak membulatkan atau mengoreksi data otomatis. Legacy reject/total belum tercatat, layak tetap tersedia. Angka DECIMAL SQLite tidak menjamin penyimpanan desimal presisi. [Dokumentasi SQLite](https://www.sqlite.org/datatype3.html)

## Matriks konektivitas

| Kebutuhan | Bukti wajib | Status |
| --- | --- | --- |
| Melihat estimasi | Semai 2026-09-20, pindah 2026-10-05, estimasi 2026-11-04, HSS20/HST5. HTTP widgets dan capture `harvest-light-estimates.png` memakai respons pemindahan nyata | Terverifikasi pada fixture HTTP/AVD |
| Menambahkan panen | UI memilih batch1/2, jumlah10/20, total2,50/3,00 kg, reject0,50/1,00 kg. SQL membuktikan satu header/dua detail/satu receipt. Rapid taps native tetap satu POST; tanaman aktif100/80 menjadi90/60 | Terverifikasi pada fixture HTTP/AVD |
| Melihat panen | Fresh ProviderContainer, API client dan sesi HTTP membaca ID1; AVD force-stop/login ulang membaca dua batch melalui GET detail. `device-reopened-state.json` dan `harvest-light-reopened.png` mendukungnya | Terverifikasi pada fixture HTTP/AVD |
| Mengubah panen | Total batch1 menjadi3,00, reject0,50; layak agregat4,00 menjadi4,50 kg. Catatan diubah lalu null, version3, tiga UUID receipt. Jumlah10/20, tanggal, batch, tanaman aktif90/60 dan kapasitas sisa10/20 tetap | Terverifikasi pada fixture HTTP/AVD |

Tes persistensi memakai production widgets/repository/ViewModel melalui Fastify HTTP dan LibSQL `:memory:` yang dimigrasikan. Setiap fixture independen. Fixture native pertama membuktikan create dan dua PATCH sampai version3; prosesnya berhenti sebelum login ulang dan penyebabnya tidak terkonfirmasi. Root mengulangi create dua batch pada fixture kedua yang dikelola sendiri, lalu force-stop/login ulang untuk bukti sesi baru. Snapshot kedua bukan hasil restore snapshot fixture pertama. Capture dan rekaman memakai data uji yang jelas; tidak ada klaim bahwa ini database produksi.

## Telemetry

| Gate | Hasil |
| --- | --- |
| Backend `npm run check` | 230/230, typecheck dan 400-line gate lulus |
| Mobile analyzer | Nol diagnostik, 2,9 detik setelah final UI fix |
| Mobile tests | 313/313, concurrency1, 2 menit 05 detik setelah final UI fix; scoped52/52 |
| HTTP UI persistence | Lulus: dua batch, fresh sessions, dua koreksi, note null, version/UUID/capacity; bounded EOF fixture diregresikan |
| APK | Final debug main lulus11,9 detik; seeded dark QA entrypoint lulus14,2 detik. Keduanya diinstal dan dijalankan pada AVD |
| AVD/capture | Medium_Phone_API_36.1: create/edit/clear-note/re-login, keyboard, filter, batch picker, validation, loading/error/empty;320×568 font setting2.0 light/dark |
| Graphify | Hasil update workspace utama dicatat di bagian penutupan |

Backend check terakhir230/230,80,07 detik, tanpa skipped/cancelled/failure; typecheck dan400-line gate lulus. Task1/2/3 mendapat review Spec/Quality; final whole-branch review dan scoped final UI re-review tersimpan bersama log, SQL fixture, capture, dan rekaman pada [direktori bukti](artifacts/harvest-2026-10-10/README.md). Tidak ada deployment atau migrasi database pengguna.

## Audit data dan rollout

Audit database lokal existing dengan SQLite `mode=ro`/`query_only`: panen 0, detail panen 0, detail penjualan 0, pemindahan 3, meja 4. Tidak ada pemindahan masa depan atau meja melebihi kapasitas pada 10 Oktober Jakarta. Ini audit database lokal, bukan klaim keadaan produksi. Fixture legacy tetap menguji backfill valid dan abort data ambigu.

Urutan rollout: backup dan audit target, migrasi, backend, mobile. Data ambigu menghentikan migrasi untuk ditinjau; tidak ada koreksi SQL otomatis. Jangan rollback kontrak backend saat mobile baru masih aktif.

## Delivery Gate antislop

Mode during, global preference. Direction: HidroSense ENERGY1 / RHYTHM2 / MOTION1. Identitas memakai palet dan interaksi produk existing. Focal point daftar adalah estimasi/hasil panen, form adalah batch serta bobot, detail adalah hasil tersimpan. Spasi memisahkan setiap batch; aksen menandai tindakan simpan. Badge selalu disertai teks. Angka produksi hanya berasal dari backend; sumber yang belum tersedia ditampilkan belum tercatat.

Native320×568 memakai override960×1704/density480 dan font setting2.0; widget tests juga memakai TextScaler.linear(2). Android dapat memakai scaling nonlinear sehingga kedua bukti dicatat terpisah. Production `main.dart` tetap light; dark adalah seeded debug QA entrypoint dan konteks widget. Tidak ada klaim60fps, perangkat fisik, atau iOS. AVD sempat menampilkan System UI/Pixel Launcher ANR sebelum alur aplikasi; dialog OS ditutup. Prompt Gboard perubahan font ditutup sebelum menilai keterlihatan input.

Gate berikut diperiksa oleh controller setelah meninjau capture final light/dark, rekaman melalui contact sheet kronologis, hasil tes, dan sumber panen. Scope gate adalah layar panen yang diubah, bukan audit seluruh aplikasi.

### Hard Gate

- R-02 PASS: pencarian source UI panen tidak menemukan em dash pada copy yang dikirim.
- R-03 PASS: 16 skenario layout320×568/teks2 dan capture final form/list/detail tidak menunjukkan overflow; label jumlah diperpendek setelah pemeriksaan truncation.
- R-17 PASS: HSS20/HST5, estimasi4 November, berat dan kapasitas cocok dengan respons HTTP serta snapshot SQL fixture.
- R-18 PASS: tidak ada testimonial atau avatar rekaan pada layar panen.
- R-23 PASS: navigasi, tema, dan ikon produk dipertahankan; tidak ada logo/aset baru atau statistik buatan.
- R-24 PASS: estimasi membuka form dengan batch nyata; daftar membuka ID server; kembali/cancel dibuktikan pada AVD.
- R-25 PASS: pemeriksaan warna efektif menghasilkan teks light minimal6,46:1 dan dark minimal7,25:1 pada input/chip yang diperbaiki; outline light4,49:1 dan dark4,56:1 melampaui batas nonteks3:1. Pair lengkap ada pada final-fix-report.md.
- R-26 PASS: tambah/hapus baris, pilihan batch, sortasi, simpan, edit, retry, tanggal, dan navigasi berfungsi; PDF placeholder dihapus.
- R-27 PASS: loading/error/empty native light/dark serta 404 pada widget/HTTP diuji; tidak ada fallback objek lama.
- R-28 PASS: layar panen tidak menambahkan FAQ.
- R-32 PASS: fokus field, keyboard, Tab, tombol submit, dan Escape/cancel picker diperiksa; capture final-focus dan final-keyboard menunjukkan input yang terjangkau.
- R-33 PASS: fitur ditulis di source Dart/TypeScript dan direview; script packaging hanya menyalin bukti, tidak menambal fitur saat runtime.
- R-34 PASS: tidak ada toggle tema produksi; konteks light dan seeded QA dark lolos tes serta native setelah perbaikan.
- R-35 PASS: dua APK final dibangun/diinstal; rekaman dan action log mencakup create, edit, read, login ulang, keyboard, cancel, retry, dan rapid taps. Receipt SQL memverifikasi efek simpan.
- R-36 PASS: laporan tidak mengklaim fps, perangkat fisik, iOS, deployment, atau keamanan di luar pemeriksaan yang dicatat.
- R-37 PASS: arah pengguna ENERGY1/RHYTHM2/MOTION1 dipakai; Design Read adalah pencatatan panen Petani dalam bahasa visual HidroSense.
- R-38 PASS: data uji diberi konteks fixture; estimasi berasal dari tanggal backend, tanpa proyeksi grade/harga/berat rekaan.

### Purpose Gate

- R-01 PASS: tidak menambahkan gradient/glow; palet datar membantu membedakan data dan tindakan simpan.
- R-04 PASS: ikon kembali, dropdown, edit, hapus, dan status memiliki fungsi; tidak ada ikon dekoratif baru.
- R-06 PASS: tipografi tema existing mempertahankan identitas; angka umur/kapasitas memakai tabular figures agar mudah dibandingkan.
- R-07 PASS: tidak ada grid/dot/blueprint dekoratif pada UI.
- R-08 PASS: panah hanya digunakan untuk navigasi/dropdown, tidak menghiasi semua tombol.
- R-09 PASS: chip adalah filter estimasi/selesai, bukan label marketing; perubahan warna selected menunjukkan state nyata.
- R-10 PASS: tidak ada glassmorphism tambahan.
- R-12 PASS: tidak menambahkan bayangan besar; batas input menjaga keterlihatan kontrol.
- R-13 PASS: tidak ada glow tambahan pada kartu, tombol, atau latar.
- R-14 PASS: struktur baris batch berulang diperlukan untuk kontrak multi-batch; daftar dan detail memiliki hierarki berbeda.
- R-19 PASS: transisi Material existing serta feedback submitting dipertahankan; tidak ada animasi serentak tambahan.
- R-22 PASS: tidak ada ilustrasi generik baru; empty state menjelaskan tindakan pengguna berikutnya.

### Liveliness

- Dials PASS: ENERGY1/RHYTHM2/MOTION1 eksplisit sesuai arahan pengguna.
- Konsistensi PASS: layar tenang; daftar, form batch, dan ringkasan detail memberi variasi struktur tanpa motion tambahan.
- Focal point PASS: daftar memusatkan estimasi/hasil, form memusatkan input batch, detail memusatkan berat tersimpan.
- Whitespace PASS: jarak16/24 memisahkan metadata, batch, dan tindakan; capture final menunjukkan pemisahan saat teks besar.
- Accent PASS: teal HidroSense menandai tindakan utama dan fokus input, bukan seluruh konten.
- Motif PASS: nama meja/batch, umur HSS/HST, dan berat kg memakai bahasa serta pola produk yang sama.
- Design Read PASS: arah pencatatan panen Petani/HidroSense tercatat pada brief dan laporan sebelum perubahan visual.

### Craftsmanship dan quality locks

- C-1 PASS: warna untuk identitas/kontras, layout untuk multi-batch, tipografi untuk baca angka, dan spacing untuk grouping memiliki alasan tertulis.
- C-2 PASS: kontrol memiliki perilaku nyata; persistensi dan idempotensi diverifikasi HTTP/SQL, termasuk rapid taps.
- C-3 PASS: setiap bagian menampilkan batch, hasil, atau status request; PDF dan harga/pcs tanpa sumber dihapus.
- C-4 PASS:16 skenario layout, inputOnly dengan inset keyboard, native light/dark, read404, error, loading, empty, cancel, dan retry lulus dalam scope yang diuji.
- C-5 PASS: klaim konektivitas didukung receipt, snapshot SQL, sesi baru, dan rekaman; batas verifikasi dinyatakan.
- R-05 PASS: komposisi mengikuti daftar/form/detail panen, tidak memakai template landing page.
- R-11 PASS: input dan kartu mempertahankan radius tema; chip hanya untuk filter, tidak semua elemen menjadi pil.
- R-15 PASS: CTA memakai Catat Panen, Simpan, dan Coba lagi sesuai tindakan nyata.
- R-16 PASS: copy panen tidak memakai klaim marketing AI.
- R-20 PASS: istilah HSS/HST, meja, batch, reject kg dan tema HidroSense mengikat tampilan ke kegiatan Petani.
- R-21 PASS: tema light baseline dipertahankan; dark QA dinyatakan harness, tanpa perubahan default produksi.
- R-29 PASS: teal dan warna permukaan tema dipertahankan; error memakai semantic error untuk validasi.
- R-30 PASS: pola produk existing dipakai, tidak meniru layout produk lain.
- R-31 PASS: grouping batch mendukung multi-detail, inputOnly memenuhi target44, outline mendukung kontras, dan aksen teal menunjukkan aksi utama.

Hasil Delivery Gate: PASS dalam scope panen dan konteks pengujian yang dicatat. Ini bukan sertifikasi semua perangkat, tema produksi dark, atau performa render.

## Keputusan pelaksanaan

1. Worktree lokal terpisah; hanya file scope terverifikasi disalin kembali dengan pemeriksaan hash perubahan pengguna. Risiko keputusan: konflik copy; guard hash mencegah overwrite diam-diam.
2. Brief/report/review package memakai PowerShell native pada Windows menggantikan helper bash. Risiko: perbedaan konvensi artifact, bukan perilaku produk.
3. Batas body POST/PATCH panen64KB mendukung100 detail, global16KB tetap. Risiko: batas memori request panen meningkat64KB; tes boundary tersedia.
4. Tema aplikasi tetap light seperti baseline; pengujian dark memakai konteks widget dan entrypoint debug QA. Risiko: bukti dark bukan dukungan dark aplikasi produksi.

## Backlog dan A/B

PDF, foto, harga estimasi, hitungan pcs/ikat, offline queue, retry lintas restart, dan koneksi penjualan belum diimplementasikan. Blueprint penjualan mempertahankan transaksi atomik, izin khusus Petani, berat tersedia, serta desimal uang.

Panduan `ab-testing` dijalankan dari skill yang diminta. Hipotesis backlog: menampilkan berat layak otomatis langsung di tiap batch dibanding ringkasan akhir dapat mengurangi kesalahan sortasi bagi Petani. Kedua varian harus menggunakan backend dan validasi yang sama. Metrik utama: proporsi form yang menghasilkan receipt panen terkonfirmasi; guardrail: duplikasi, konflik saldo, dan kegagalan penyimpanan. Baseline, sample size, durasi, MDE, serta hasil belum tersedia; tidak ada eksperimen atau telemetry produksi yang dipasang. Jika kelak dijalankan, tetapkan kohort stabil50/50, ukuran sampel dan jadwal analisis sebelum exposure, tanpa penghentian dini karena peeking.

