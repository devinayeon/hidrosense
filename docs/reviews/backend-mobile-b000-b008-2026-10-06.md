# Audit konteks backend dan mobile B000–B008

> Pembaruan setelah audit: [integrasi login dan inventaris baca mobile](../mobile-integration-2026-10-06.md) telah dikerjakan. Temuan di bawah menggambarkan kondisi sebelum slice tersebut; status fitur lain tetap berlaku.

Tanggal: 6 Oktober 2026 (Asia/Jakarta). Cakupan: working tree saat audit, termasuk perubahan lokal yang sudah ada. Audit kode/dokumen dan pemeriksaan lokal; tidak melakukan deployment atau perubahan kode aplikasi. B00/B01 pada rencana sama dengan B000/B001 pada laporan implementasi; nomor migrasi bukan nomor tahap backend.

## Kesimpulan

**B000–B008 telah diimplementasikan sebagai slice backend lokal. Mobile masih UI dengan data dummy/state memori, belum terintegrasi dengan API dan penyimpanan SQLite.** Karena itu, klaim seluruh backlog PPL atau aplikasi sudah selesai belum benar. `npm run check` lulus dengan 177/177 tes pada audit ini.

Baseline 19 tabel/23 relasi dipertahankan migrasi awal. Skema aktif memiliki perluasan terencana melalui migrasi berikutnya; perbedaannya dari DBML tidak otomatis merupakan cacat. Ketidaksesuaian yang perlu ditangani untuk integrasi terutama berada pada DTO/model mobile, identitas, saldo inventaris, bahan penyemaian, dan representasi meja/batch.

## Planning

1. Gunakan graphify sebagai navigasi, lalu verifikasi kode dan dokumen sumber langsung. Graph mengembalikan hasil terpotong dan beberapa lokasi Dart kosong, sehingga tidak dipakai sebagai bukti lengkap implementasi.
2. Pisahkan tiga pertanyaan: slice backend tersedia, deployment terverifikasi, dan produk mobile memenuhi DoD PPL.
3. Bandingkan PPL → rencana aktif → kontrak API → migrasi → model/viewmodel mobile.
4. Jalankan gate lokal yang tersedia; simpan kegagalan sebagai temuan, bukan menutupnya dengan perubahan di luar audit.
5. Hasil akhir: matriks status, mapping data, task/todo, review, dan checklist dalam satu dokumen. Tidak perlu rewrite backend atau menambah tabel hanya untuk menyesuaikan dummy UI.

## Task audit

| Task | Pelaksana | Hasil |
| --- | --- | --- |
| A01 — PPL, timeline, urutan B000–B008 | Sub-agent `docs_audit` | Selesai; status historis dipisahkan dari status terkini |
| A02 — backend, migrasi, endpoint, tes | Sub-agent `backend_audit` | Selesai; implementasi lokal ditemukan untuk semua tahap |
| A03 — model, viewmodel, alur mobile | Sub-agent `mobile_audit` | Selesai; dummy dan gap kontrak teridentifikasi |
| A04 — pemeriksaan lokal dan sintesis | Agent utama | Selesai; hasil check dicatat di bawah |
| A05 — pemasangan tiga skill | Agent utama | Selesai; nama arsitektur dikoreksi, database memakai commit historis |

## Review status B000–B008

Lokasi `path:line` mengacu pada snapshot saat audit. Path pada kolom bukti yang dimulai `src/`, `test/`, atau `migrations/` relatif terhadap `apps/backend/`.

| Tahap | Status backend lokal | Bukti utama | Batas terhadap PPL/mobile |
| --- | --- | --- | --- |
| B000 | Tersedia | `migrations/0001_initial_schema.up.sql:4`; `test/migrations.test.js:21` memeriksa tabel, kolom, constraint dan 23 FK; backup/restore `:195` | Database server bukan SQLite perangkat |
| B001 | Tersedia | `src/app.ts:26`, health/readiness `:79`, registrasi fitur `:90` | Tes injection tidak membuktikan server eksternal aktif |
| B002 | Tersedia | `src/features/auth/index.ts:8`; `src/common/permissions.ts:3`; migrasi sesi 0002 | Mobile belum login/session/role guard |
| B003 | Tersedia | `src/features/accounts/index.ts:9`; tests accounts/profile | Profil mobile masih mock |
| B004 | Fondasi tersedia | `src/common/sync.ts:23`, `:94`, `:129`; `docs/backend-b004.md:3` | Reservasi identitas, replay, versi; belum outbox perangkat/push-pull lengkap B017 |
| B005 | Tersedia | `src/features/inventory/index.ts:7`; migrasi 0004/0005 | Master bukan saldo; DTO mobile belum cocok |
| B006 | Ledger tersedia lokal | `src/features/stock/service.ts:8`; `store.ts:115`; migrasi 0006 | D01–D04 staging masih terbuka di `docs/b006/staging-deployment-0006.md:3`; mobile masih edit saldo langsung |
| B007 | Penyemaian tersedia lokal | `src/features/nursery/service.ts:12`, `:44`; `store.ts:10` | Bahan terstruktur dan konsumsi stok belum terhubung dari mobile |
| B008 | Meja tersedia lokal | `src/features/tables/service.ts:6`; `store.ts:7`; `test/tables.test.js:82` | Belum pemindahan B009/kerusakan B010; bukan seluruh PB-04 |

Dokumen `docs/deployment-turso-migrations.md:7–9` menyimpan bukti historis migrasi 0001–0005 applied. `docs/reviews/b007-b008-2026-10-04.md:33` menyebut 0008 belum remote. Audit ini tidak memeriksa ulang remote, sehingga tidak menyatakan kondisi live terkini atau deployment B006–B008 selesai.

DoD PPL pada `docs/A9_PPL IF_WEEK5.docx.md:713–721` mensyaratkan acceptance, review/integrasi, tes, dan dokumentasi. PB-07 (`:705`) meminta persistensi lokal setelah buka ulang dan sinkronisasi; PB-04 (`:702`) juga mencakup pemindahan/kerusakan. Pada 6 Oktober 2026 baseline jadwal berada di Sprint 2 (23 September–15 Oktober), tetapi tanggal sprint bukan bukti target telah selesai.

## Review rancangan database

| Lapisan | Fakta | Implikasi |
| --- | --- | --- |
| DBML konseptual | `docs/database/hidrosense.dbml:2` menyebut PostgreSQL; PPL `:303` memilih SQLite/Turso | Adaptasi SQLite sudah dinyatakan di migrasi awal; jangan mengganti stack berdasarkan label DBML |
| Baseline fisik | Migrasi 0001: 19 tabel domain, 23 FK | Tes baseline tidak membuktikan seluruh skema terbaru identik DBML |
| Skema aktif | Tambahan auth_sessions, auth_rate_limits, sync_id_maps, sync_operations, sync_resource_versions, sync_resource_links, stok_saldo | 26 tabel aplikasi, di luar metadata migrasi/internal SQLite; jadikan seluruh migrasi sumber fisik aktif |
| Master/ledger | 0004 menambah status jenis; 0006 menambah sealing/reversal, jumlah_minor/satuan, stok_minimum_minor, stok_saldo | Saldo berasal ledger; representasi integer minor di DB dan decimal string di API harus dipertahankan |
| Penyemaian | 0007 membatasi status non-null menjadi aktif/selesai; 0008 indeks daftar | Migrasi 0008 bukan implementasi fitur B008 |
| DTO API | ID decimal string, public UUID, version, serta field turunan usia/kapasitas | DTO tidak perlu identik kolom DB; model tampilan memerlukan mapping eksplisit |

Keputusan terdokumentasi yang tidak perlu dibuka ulang sebagai bug: hak pegawai mengelola panen dan larangan penjualan mengikuti System Request (`docs/backend-b001-b002.md:7`); status fisik meja manual; 12 meja × 250 lubang adalah konteks mitra, bukan batas sistem universal. Keputusan terbuka sebelum B009: estimasi 45 HSS versus 15 hari semai + 45 hari pertumbuhan (`docs/A9_PPL IF_WEEK5.docx.md:16`, `:20`; `docs/backend-b008.md:19`).

## Review mobile dan mapping minimum

**P1 — Persistensi dan integrasi belum ada pada alur yang diperiksa.** `apps/mobile/lib/viewmodels/inventaris_viewmodel.dart:50` memuat mock; `:89–109` hanya mengubah state. Pola dummy juga terdapat pada penyemaian, meja, panen, penjualan, cuaca. `apps/mobile/lib/main.dart:20` langsung membuka MainPage; `account_viewmodel.dart:27` memakai mock dan `:34` menampilkan teks sinkronisasi tanpa operasi nyata. Dependency pubspec belum mencakup client HTTP atau SQLite; penelusuran `lib` tidak menemukan lapisan API/repository/database.

**P1 — Kontrak inventaris belum kompatibel.** `apps/mobile/lib/models/inventory_item_model.dart:62` membaca `id/name/stockValue`; backend `apps/backend/src/features/inventory/store.ts:74` mengembalikan `id_inventaris/nama_barang/...`. Jika respons itu dipasok langsung, default menghasilkan ID/nama kosong dan saldo nol. Parser tersebut belum terhubung API, sehingga ini gap integrasi, bukan kegagalan request produksi yang telah diamati.

**P1 — Saldo diedit seperti atribut master.** `apps/mobile/lib/views/pages/add_form_inventaris_page.dart:103` menyimpan stockValue langsung; `:55` dan model `:32` memakai `toInt`, sehingga pecahan tidak dipertahankan dalam tampilan/edit. PPL `:463`, `:700` dan kontrak `docs/backend-stock-api.md:36` mengharuskan transaksi stok serta kuantitas presisi dua desimal.

**P1 — Payload semai belum memadai.** `seeding_batch_model.dart:14` memakai `List<String>` bahan; `seeding_form_page.dart:111` membuat data tanpa material terstruktur dan `:115` dapat memakai tanggal display “Hari ini”. Kontrak backend `src/features/nursery/contracts.ts:26`, `:31` memerlukan tanggal kanonis dan bahan ID/jumlah/satuan; konsumsi ledger dilakukan atomik oleh service.

**P2 — Struktur meja/batch UI perlu keputusan.** `meja_nft_model.dart:3` hanya mengenal aktif/perawatan, sementara backend memakai teks status manual/default tersedia. `baris_tanam_model.dart:5` dan `baris_tanam_viewmodel.dart:47` memakai baris/rentang lubang; DBML `:65`, `:74` menghubungkan pemindahan dan kerusakan ke batch pemindahan, bukan baris. Jangan menambah entitas baris sebelum kebutuhan disetujui.

| Model mobile | Mapping API/domain minimum | Field yang belum punya sumber/aturan |
| --- | --- | --- |
| InventoryItem | id←id_inventaris; name←nama_barang; category←nama_jenis; stockUnit←satuan; isDeleted←status_aktif==0; simpan FK jenis/obat, stok_minimum, public_id/version | Saldo dari `/inventaris/:id/saldo`, bukan master; price/imageUrl/note/mainUnit belum dipetakan; status stok turunan saldo/minimum |
| Account | nama/username; peran←role; noWhatsApp←no_telepon; pertahankan id_user/email/alamat/status | idPerkebunan dan teks sukses sinkronisasi bukan field akun server |
| SeedingBatch | id←id_penyemaian; dateText←format tanggal_semai; seedCount←jumlah_benih; hss←usia_hari; status dari status_penyemaian/siap_pindah; note←keterangan | batchName/variety/healthy/damaged/phase bukan kontrak B007; request materials harus terstruktur, detail konsumsi dari stok_konsumsi |
| MejaNft | id←id_meja; name←kode_meja; capacityTotal←jumlah_lubang; capacityUsed←tanaman_aktif; notes←keterangan; status←status_meja | Lokasi/sistem/maintenance ETA/estimasi panen belum ada pada B008; satu meja dapat memuat banyak pemindahan, bukan satu batchName tetap |

Sumber mapping selain inventaris: `apps/backend/src/features/accounts/store.ts:6`, `nursery/store.ts:16`, `:72`, `tables/store.ts:24`. ID timestamp dari form mobile belum merupakan public UUID + version sesuai B004. Pisahkan ID lokal, ID server, dan identitas operasi; jangan mengonversi ID server besar menjadi angka floating point.

## Todo implementasi berikutnya

T01–T07 belum dikerjakan dalam audit ini; T08 selesai sebagai koreksi dokumentasi. Urutan server tetap B009; integrasi mobile dapat berjalan terpisah dengan kontrak B000–B008 yang sudah tersedia.

| Prioritas / task | Pekerjaan | Check penerimaan |
| --- | --- | --- |
| P1 / T01 | Tetapkan DTO request/response dan mapper ke model presentasi; dokumentasikan delta DBML → migrasi aktif | Fixture respons nyata tidak menjadi nilai default diam-diam; FK, ID, UUID/version, tanggal dan desimal tetap utuh |
| P1 / T02 | Integrasikan login/session/otorisasi → master inventory → saldo/ledger | Login gagal/sesi dicabut ditangani; pegawai tidak mengakses penjualan; saldo 0.25 tidak menjadi 0; mutasi stok melalui transaksi/reversal |
| P1 / T03 | SQLite lokal + outbox/status sinkronisasi sesuai B004 dan penyelesaian B017 | Relaunch mempertahankan data; retry memakai identitas operasi sama; receipt/conflict ditangani; jangan tampilkan sukses sebelum terkonfirmasi |
| P1 / T04 | Integrasikan B007/B008 dengan payload bahan, tanggal, kapasitas/status manual | Membuat semai mengurangi stok tepat sekali; form gagal atomik; kapasitas dan status mengikuti server |
| P1 / T05 | Lengkapi bukti deployment staging per migrasi dan revisi kode | D01–D04 B006 tertutup, upgrade/reconcile/readiness dan smoke B007/B008 terbukti; pisahkan bukti lama dari live |
| P2 / T06 | Putuskan 45 HSS/60 hari dan kebutuhan baris/rentang lubang sebelum B009 | Keputusan tertulis, mapping batch disepakati; baru lanjut pemindahan/kapasitas |
| P2 / T07 | Ganti tes template mobile dengan tes layar/alur aktual; tangani 8 isu analyzer | Widget smoke aktual lulus; fixture mapper, pecahan stok, relaunch dan replay diuji saat fiturnya diimplementasikan |
| Selesai / T08 | Sumber status di awal rencana dan tautan audit dari timeline diperbarui | Status B009 berikutnya jelas; snapshot historis dipertahankan |

## Check dan batas bukti

- [x] Graphify query, refleksi, dan pembacaan sumber langsung dijalankan; query lanjutan menggunakan vocab backend/timeline/inventaris/penyemaian/meja.
- [x] Tiga sub-agent menyelesaikan audit dokumen, backend, dan mobile; hasil dibandingkan pada sintesis.
- [x] Sub-agent melakukan review akhir laporan dan pembukaan dokumen; inkonsistensi status T08 telah dikoreksi.
- [x] `cd apps/backend; npm run check`: exit 0; typecheck dan check:lines lulus; **177 pass, 0 fail, 0 skipped**. Berkas kode terbesar 318 baris dari batas 400. Durasi test sekitar 98 detik.
- [x] `cd apps/mobile; flutter analyze --no-pub`: dijalankan, exit 1; **8 isu (3 warning, 5 info)**. Unused import inventory, unreachable default baris/panen, serta API deprecated pada lima lokasi UI.
- [x] `cd apps/mobile; flutter test --no-pub`: dijalankan, exit 1; **0 pass, 1 fail**. Tes counter template mengharapkan teks `0` yang tidak ada, `test/widget_test.dart:19`.
- [ ] Integrasi mobile end-to-end, persistensi setelah relaunch, retry dua perangkat, uji perangkat/mitra, dan staging terkini belum terbukti.
- [x] Perubahan kode pengguna dipertahankan; audit tidak memperbaiki aplikasi, menerapkan migrasi remote, atau mengubah schema baseline.

Log analyzer/widget tersimpan selama sesi di `%TEMP%/hidrosense-audit-flutter-analyze.txt` dan `%TEMP%/hidrosense-audit-flutter-test.txt`. Hasil ini memotret working tree, bukan sertifikasi keamanan atau pembuktian bahwa tidak ada bug lain.

## Instalasi skill

| Permintaan | Hasil |
| --- | --- |
| flutter-apply-architecture-best-practice | Nama sumber sebenarnya **flutter-apply-architecture-best-practices**; dipasang project-local melalui npx skills untuk Codex |
| flutter-working-with-databases | Tidak tersedia pada main terkini. Riwayat repo menunjukkan penghapusan pada `130378c2e7f847749664a236a150465453f046b9` (“Remove all skills”); dipasang dari parent `430687774a92ab84e4fdf96de6415ee407dd4beb` dengan helper skill-installer |
| mobile-android-design | Dipasang project-local dari wshobson/agents melalui npx skills untuk Codex |

Lokasi: `.agents/skills/<nama>/SKILL.md`. Dua instalasi npx tercatat di `skills-lock.json`; instalasi database memakai helper dan dipin melalui provenance commit pada dokumen ini, bukan entri lock npx yang dibuat-buat. Skill tersedia bagi sesi berikutnya. Instalasi skill Android tidak mengubah target Flutter menjadi native Android.

Reproduksi database: `python <skill-installer>/scripts/install-skill-from-github.py --repo flutter/agent-plugins --ref 430687774a92ab84e4fdf96de6415ee407dd4beb --path skills/flutter-working-with-databases --dest .agents/skills`.
