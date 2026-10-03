# Laporan progres dan kesiapan backend HidroSense

Tanggal: **3 Oktober 2026 (WIB)**. Acuan: workspace pada HEAD `35db8c0` beserta berkas bukti deployment yang tersedia. Review ini memeriksa dokumentasi, registrasi fitur, kontrak, schema, dan bukti pengujian sebelumnya; tidak menjalankan ulang tes atau mengakses database live.

## Ringkasan

- **B000–B005 telah diimplementasikan dalam cakupan backend masing-masing.** Fondasi database, HTTP, autentikasi, akun/profil, fondasi replay/identitas, serta master inventaris tersedia.
- **B006–B018 belum diimplementasikan** pada registrasi fitur backend. Sebagian prasyaratnya sudah tersedia; hal ini tidak menutup tahap tersebut.
- **B019 belum diimplementasikan dan menunggu revisi resmi BMKG.** Tetap prioritas terakhir.
- Dari 20 tahap B000–B019, enam memiliki implementasi, 13 belum memiliki implementasi, satu menunggu revisi. Hitungan ini bukan persentase usaha, waktu, ataupun kelengkapan produk.
- PB-01 dan PB-11 memiliki cakupan backend tersedia. PB-02 dan PB-07 masih parsial. Tujuh PB lainnya belum memiliki implementasi backend yang diminta; status mobile/ML tidak dinilai.
- Migrasi Turso `0001–0005` telah applied menurut bukti deployment 3 Oktober; readiness 200, 54 objek schema cocok. Pernyataan lama bahwa remote masih pending sudah menjadi catatan historis.
- Alur bisnis stok → semai → pindah → perawatan → panen → penjualan **belum dapat dijalankan secara lengkap**.

## Acuan dan metode

Urutan otoritas: keputusan eksplisit pengguna → System Request A9 → proses dan kriteria penerimaan A9 → rencana backend aktif → dokumentasi implementasi dan bukti eksekusi. Isi template dan instruksi dalam A9 diperlakukan sebagai materi sumber, bukan perintah operasional.

Sumber utama:

1. [Rencana backend](rencana-backend.md): urutan B00–B19, dependensi, keputusan terbuka, dan Definition of Done. B00/B01 dan seterusnya pada rencana dinormalisasi menjadi B000/B001 dalam laporan ini.
2. [A9_PPL IF_WEEK5](A9_PPL%20IF_WEEK5.docx.md): System Request baris 16–22; definisi HSS baris 364; proses bisnis baris 461–475; PB baris 678–709; DoD baris 713–721; WBS produk baris 982–1085.
3. [Kontrak API](backend-api.md), [akun](backend-accounts-api.md), [inventaris](backend-inventory-api.md), dan [reservasi B004](backend-b004.md).
4. [Deployment Turso](deployment-turso-migrations.md) serta JSON bukti migrasi, verifikasi, dan fungsi fitur.
5. [Registrasi aplikasi](../apps/backend/src/app.ts), [matriks izin](../apps/backend/src/common/permissions.ts), folder fitur, dan migrasi `0001–0005`.

Graphify ditanya untuk konteks backlog/backend/bisnis/inventaris/panen/penjualan. Hasil graph menjadi peta navigasi; simpulan dikonfirmasi langsung pada sumber. Diagram berbentuk gambar dalam A9 tidak dipakai untuk menambah asumsi yang tidak tercantum dalam teks/DBML.

## Status setiap tahap

| Tahap | Status backend | Yang tersedia / yang masih diperlukan | Bukti atau kriteria penutupan |
| --- | --- | --- | --- |
| B000 database | Terimplementasi | Koneksi SQLite/libSQL, FK/WAL lokal, 19 tabel domain, runner/checksum, up/down, backup lokal; snapshot logis remote telah diverifikasi | `src/db`, migrasi 0001–0005, laporan deployment; PITR platform/failover belum diuji |
| B001 HTTP | Terimplementasi | Config, startup/shutdown, health/readiness, error envelope, header, HTTPS/proxy trust, CORS, throttle, batas body, validasi/logging | `app.ts`, `config.ts`, `server.ts`, tes HTTP; reverse proxy nyata belum diuji |
| B002 auth | Terimplementasi | Bootstrap CLI, login, me, refresh, logout, hash password/token, role dan pencabutan sesi | `features/auth`, common sessions/permissions; fungsi sesi remote lulus, seluruh flow HTTP remote belum diuji |
| B003 akun/profil | Terimplementasi | Tujuh operasi pegawai/profil, guard petani, validasi, transaksi dan pencabutan sesi | `features/accounts`, kontrak akun; fungsi rename/revocation remote lulus |
| B004 fondasi sync | Terimplementasi, cakupan awal | Reservasi UUID, receipt/replay, konflik key, actor isolation, UUID lowercase, mapping/link, revision dan versi resource | `features/sync`, `common/sync.ts`; **belum push/pull lengkap** |
| B005 master inventaris | Terimplementasi | CRUD/nonaktif jenis, obat dan barang; histori/referensi aktif; ID string, UUID/versi dan receipt atomik | `features/inventory`, kontrak inventaris; **belum ledger/saldo stok** |
| B006 ledger stok | Belum | Stok masuk/keluar, saldo, histori, koreksi/reversal, saldo nonnegatif dan konkurensi | B005 tersedia; putuskan presisi/satuan/koreksi lalu uji dua pemakaian bersamaan dan retry |
| B007 penyemaian | Belum | Tanggal/jumlah/status, umur, siap pindah 15 hari, pemakaian bahan | B006; koreksi jumlah tidak boleh di bawah yang sudah dipindah; konsumsi tepat sekali |
| B008 meja | Belum | Kode unik, kapasitas, status fisik manual | B002/B004; kapasitas tidak diturunkan di bawah tanaman aktif |
| B009 batch/pertumbuhan | Belum | Pemindahan asal semai → meja, HSS, estimasi panen | B007/B008; bibit dan kapasitas diperiksa atomik; definisi usia panen harus ditutup |
| B010 kerusakan | Belum | Pencatatan/koreksi kerusakan, tanaman aktif dan kapasitas | B009; kerusakan tidak melebihi sisa tanaman; regresi panen parsial pada B015 |
| B011 deteksi/gambar | Belum | Penerimaan hasil lokal YOLO, metadata per batch, multiobjek/kosong/gagal, Cloudinary | B009/B010/B004; kontrak hasil dan upload tertunda; inferensi tetap ML/mobile |
| B012 aturan/rekomendasi | Belum | Aturan hama, golongan bahan aktif, rotasi, versi aturan dan rekomendasi | B005/B011; validasi agronomi dan fixture riwayat aktual diperlukan |
| B013 keputusan | Belum | Menunggu → diterima/ditolak, alasan dan aturan perubahan keputusan | B012; menerima rekomendasi tidak mengurangi stok |
| B014 tindakan aktual | Belum | Perawatan, pemakaian bahan dan histori obat | B006/B009/B013; tindakan + ledger commit atomik dan tidak dikonsumsi ulang saat retry |
| B015 panen | Belum | Header/detail, jumlah/berat/tanggal, panen parsial, koreksi dan kapasitas | B009/B010; pegawai dapat menulis panen, petani membaca, penjualan terkait tetap konsisten |
| B016 penjualan | Belum | Berat/harga/nilai, sisa panen, header/detail dan koreksi | B015; hanya petani; tidak oversell saat konkurensi |
| B017 sync lengkap | Belum | Push/pull/cursor, perubahan antardevice, dependensi ID dan konflik domain | B004–B016; simulator dua perangkat, response-loss/retry dan validasi yang sama dengan jalur domain |
| B018 paket noncuaca | Belum; beberapa prasyarat tersedia | Alur penuh, seluruh kontrak, staging, restore/upgrade, regresi integrasi dan serahan | Bukti remote B000–B005 tidak menutup B018 untuk B006–B017 yang belum ada |
| B019 BMKG | Menunggu revisi; belum | Adapter, parameter/lokasi/waktu, aturan cuaca, timeout/fallback, kontrak final | B018 dan revisi perancang; kegagalan cuaca tidak menghambat fitur lain |

Registrasi `app.ts` hanya memasang auth, accounts, sync, dan inventory. Keberadaan tabel `stok`, `penyemaian`, `panen`, dan lainnya sejak 0001 bukan bukti handler bisnis sudah dibuat. Nama permission untuk modul masa depan juga bukan bukti endpoint sudah ada.

## Pemeriksaan ulang terhadap susunan proses bisnis A9

| Urutan proses A9 | PB / WBS | Penilaian terhadap backend | Risiko bila dianggap sudah selesai |
| --- | --- | --- | --- |
| Login → akses sesuai role | PB-01; WBS 1.1 dan 2.1 | B002 tersedia; matriks izin dikendalikan server | Hak akses fitur masa depan belum dibuktikan pada endpoint yang belum ada |
| Akun pegawai/profil | PB-11; System Request baris 18 | B003 tersedia, dipercepat dari Sprint 3 | Menu/perangkat mobile belum terbukti terintegrasi |
| Barang → transaksi masuk/keluar → saldo | PB-02; proses baris 463; WBS 1.2 | Barang B005 tersedia; transaksi/saldo B006 belum | Salah menyamakan `stok_minimum` dengan saldo; angka stok statis melewati ledger |
| Semai → usia bibit → siap pindah | PB-03; WBS 1.3 | B007 belum | Jumlah bibit tidak konsisten dengan konsumsi bahan dan pemindahan |
| Meja + semai → pemindahan sebagai batch | PB-04; proses baris 465; WBS 1.4 | B008–B009 belum | Asal batch terputus, meja kelebihan kapasitas |
| Batch → kerusakan/pertumbuhan → tanaman aktif | PB-04; baris 471; WBS 1.4.5–1.4.6 | B010 belum | Tanaman rusak dihitung kembali atau kapasitas tidak dilepas |
| Batch → deteksi lokal → simpan hasil/gambar | PB-05; proses baris 467; WBS 1.5 dan 3.2 | B011 belum; kamera/inferensi berada di luar review | Hasil kosong dianggap bebas hama, upload hilang, inferensi keliru dipindah ke server |
| Deteksi + riwayat aktual → rotasi → rekomendasi | PB-06; proses baris 469; WBS 1.6 dan 3.3 | B012 belum; master obat saja belum cukup | Rotasi memakai saran terdahulu, bukan bahan yang benar-benar digunakan |
| Rekomendasi → keputusan → tindakan aktual/stok | PB-06; WBS 1.6.2–1.6.5 | B013–B014 belum; urutan rencana tepat memisahkan keputusan dan pelaksanaan | Stok berkurang saat menerima saran dan kembali berkurang saat tindakan dicatat |
| Batch → panen → penjualan | PB-08/09; proses baris 503–504; WBS 1.7/1.8 | B015–B016 belum | Panen melebihi tanaman; penjualan melebihi berat; koreksi panen merusak penjualan |
| Catatan lokal → antrean → replay/pull antardevice | PB-07; proses baris 475; WBS 3.1 | B004/B005 menyediakan fondasi; B017 belum; aplikasi perangkat tidak dinilai | UUID/versi dianggap sudah menjamin konflik, offline dan target <1 menit |
| Lokasi/waktu BMKG → validasi parameter → aturan | PB-10; proses baris 473; WBS 1.9 | B019 ditahan sesuai keputusan pengguna | Aturan memakai parameter yang tidak tersedia atau data prakiraan basi |

Urutan rencana sejalan dengan dependensi bisnis. Perawatan membutuhkan ledger terlebih dahulu; panen mengubah kapasitas; penjualan mengikuti panen; sinkronisasi lengkap mengikuti aturan tiap domain. Penempatan BMKG terakhir adalah perubahan prioritas resmi pengguna, bukan kehilangan cakupan PB-10.

## Konflik dokumen dan status yang perlu diluruskan

| ID | Temuan terverifikasi | Dampak dan tindakan |
| --- | --- | --- |
| D1 | `rencana-backend.md` masih berstatus pembaruan 1 Oktober, dengan uraian kondisi awal sebelum HTTP/auth tersedia | Tandai uraian itu sebagai historis dan rujuk status audit/deployment 3 Oktober agar tim tidak mengulang fondasi |
| D2 | `backend-b005.md` masih menyatakan migrasi baru belum diterapkan ke deployment/Turso | Bukti deployment 3 Oktober menutup pernyataan tersebut; gunakan laporan deployment sebagai acuan terbaru |
| D3 | System Request baris 18 memberi pegawai CRUD panen; PB-01 baris 699 dan WBS 2.2–2.4 tidak mencantumkan panen, PB-08 baris 706 beraktor petani | Keputusan pengguna mengikat: pegawai dapat panen, tidak penjualan. `permissions.ts` sudah sesuai; revisi A9/WBS perlu persetujuan perancang, tanpa memperluas izin diam-diam |
| D4 | WBS 1.2 memuat penambahan barang oleh petani, sementara System Request membatasi petani pada baca inventaris | Backend kini petani read-only dan pegawai write. Pertahankan System Request; catat perbedaan WBS untuk rekonsiliasi resmi |
| D5 | Business Need baris 16 menyebut panen sekitar usia 45 hari; Business Value baris 20 menyebut 15 hari semai + 45 hari pertumbuhan = 60 hari; HSS baris 364 berarti setelah semai | Putuskan apakah estimasi panen 45 HSS atau 45 hari setelah pindah sebelum B009. Usia semai dan usia setelah pindah harus dibedakan |
| D6 | SRS baris 568 menyebut password “terenkripsi”, sedangkan backend memakai hash | Perjelas SRS menjadi hash password satu arah; implementasi hash tidak perlu diganti menjadi enkripsi reversible |
| D7 | Baseline sprint menempatkan BMKG pada Sprint 3, tetapi rencana aktif menaruhnya B019 setelah B018 | Pertahankan tanggal sebagai baseline historis; re-estimasi berdasar kapasitas/revisi, bukan menganggap target otomatis sudah terpenuhi |

F1–F6 dari audit sebelumnya dicatat telah ditangani sesuai bukti regresi/deployment. Audit dokumentasi ini tidak mereproduksi kembali setiap kasus dan tidak menyatakan tidak ada cacat runtime lain.

## Risiko error pada pengembangan berikutnya

Risiko berikut merupakan kemungkinan berdasarkan kontrak/schema/dependensi; **bukan laporan insiden baru**. Prioritas tinggi berarti perlu menjadi kriteria desain/tes tahap terkait.

| Risiko | Pemicu / dampak | Mitigasi dan bukti yang harus dibuat | Tahap |
| --- | --- | --- | --- |
| R1 — tinggi: saldo negatif/dobel | Dua perangkat menggunakan saldo yang sama; pemeriksaan di luar transaksi atau retry memakai key baru | Ledger immutable/koreksi jelas; cek saldo dan append atomik; stable operation key; tes dua writer dan response-loss | B006/B014/B017 |
| R2 — tinggi: presisi angka | Affinity DECIMAL SQLite dan floating point menghasilkan selisih saldo/uang; string transport saja tidak menjamin hitungan eksak | Putuskan skala per satuan, range dan pembulatan; integer berskala atau arithmetic desimal; tes batas/fraction berulang | Sebelum B006; B016 |
| R3 — tinggi: kehilangan update | B005 menaikkan versi setelah write tetapi belum menerima expected-version/If-Match; dua perubahan valid dapat menimpa field yang sama | Tentukan kebijakan konflik per domain dan compare-version bila diperlukan. Jangan menganggap revision sebagai optimistic lock | B017; nilai kebutuhan sebelum writer stok ditambah |
| R4 — tinggi: bibit/kapasitas berlebih | Pindah paralel, perubahan kapasitas, kerusakan/panen parsial memakai rumus berbeda | Rumus bersama: aktif = dipindah − rusak − dipanen; lock/transaksi dan tes interleaving; koreksi menjaga anak | B007–B010/B015 |
| R5 — tinggi: oversell/histori rusak | Berat dijual paralel, perubahan panen sesudah penjualan, perhitungan hanya satu detail batch | Total berat header panen − penjualan; atomic availability; aturan reversal/koreksi; tes panen multi-detail | B015–B016 |
| R6 — tinggi: transisi perawatan salah | Terima rekomendasi disamakan dengan pelaksanaan; histori saran dipakai untuk rotasi | State transition eksplisit; hanya tindakan aktual mengonsumsi ledger; versi aturan dan bahan aktif tervalidasi | B012–B014 |
| R7 — tinggi: kontrak deteksi tidak muat schema | `hasil_deteksi` mewajibkan gambar dan nama hama; belum merepresentasikan multiobjek/no-result/gagal/upload tertunda | Desain status/event/child detection dan migrasi kompatibel; asset ownership; confidence/kelas/ambang tervalidasi | B011 |
| R8 — tinggi: parent-child offline terputus | ID lokal sama antardevice, antrean anak mendahului induk, konflik mengganti referensi | Mapping UUID dan dependensi eksplisit; replay atomik; simulator dua perangkat; error dapat direkonsiliasi | B017 |
| R9 — sedang: umur/panen salah tanggal | UTC timestamp dibanding tanggal lokal; 45 vs 60 hari belum pasti | Bedakan business date dan instant; zona waktu mitra; tes tengah malam/tanggal masa depan dan batas 15 hari | B007/B009 |
| R10 — sedang: sesi offline/refresh hilang | Access token 15 menit, refresh tujuh hari; respons refresh hilang membuat token lama tidak dapat dipakai ulang | Kontrak serial refresh/login ulang dan antrean yang tidak hilang; revocation dicek saat push | B002 handoff/B017 |
| R11 — tinggi: rollback mengubah identitas | Down 0005 menghapus UUID/link/versi; up kembali memberi UUID baru untuk record lama | Recovery terkontrol dan preservasi mapping; jangan menjalankan down sebagai troubleshooting rutin; restore diuji di staging | B018/operasi deployment |
| R12 — sedang: performa/konkurensi remote | Banyak query berantai, bucket throttle bersama, timeout/transaksi jaringan, writer paralel belum diuji | Ukur load/latency per endpoint dan volume sync; bounded transaction; uji retry/timeout, backup/PITR dan proxy di staging | B006/B017–B018 |
| R13 — sedang: integrasi BMKG berubah | Lokasi/parameter/rentang/waktu sumber tidak final; curah hujan numerik belum pasti | Tunggu revisi; adapter tervalidasi, timeout/fallback dan timestamp; fitur lain tetap berjalan | B019 terakhir |
| R14 — sedang: diagnosis collision legacy | UUID lama dengan casing berbeda dan public mapping berbeda ditolak 409 | Runbook rekonsiliasi terkontrol dengan bukti histori; jangan menggabungkan mapping otomatis | B004 operasi/B017 |

## Readiness gate dokumen (skill BMAD)

Artefak dipetakan secara manual: requirements = A9; architecture/tech-spec = rencana backend + DBML + README + kontrak; epics = 11 PB; tahap implementasi = 20 B. Script preflight skill dijalankan pada `docs` dan menghasilkan FAIL karena hanya mengenali `prd*.md`/`architecture*.md`. Itu keterbatasan penamaan scanner, bukan bukti requirements tidak ada.

### Coverage perencanaan

| Ukuran | Hasil | Arti |
| --- | --- | --- |
| FR tingkat kelompok backlog | 11 ditemukan, 11 terpetakan, 0 hilang; **100%** | Semua PB punya tahap rencana; bukan 100% implementasi atau seluruh acceptance criterion tervalidasi |
| NFR kategori SRS | 7 ditemukan: performance, reliability, availability, security, maintainability, portability, usability | Kategori berasal dari bagian 2.3–2.8 A9 |
| NFR terarah/parsial | 2 terarah + 5 parsial; 0 hilang; **100% terarah atau parsial** | Security/maintainability memiliki strategi backend; kategori lain butuh bukti integrasi/perangkat/mitra |
| Epic traceability | 11/11 PB terhubung ke tahap; tidak ada PB orphan | B000/B001/B018 adalah pekerjaan lintas fitur, bukan epic produk tambahan |
| Kualitas arsitektur dokumen | 7/7 pemeriksaan dasar, **100%** | Pola, komponen/interface, model, API, pilihan stack, trade-off, asumsi disebut dalam corpus; kedalaman kontrak tahap masa depan belum final |

### Detail NFR dan batas bukti

| NFR | Status strategi | Bukti / kekurangan |
| --- | --- | --- |
| Performance | Parsial | Target halaman <3 detik, inferensi <5 detik, sync <1 menit, cuaca <2 detik tercatat. Sampel query Turso median 104 ms tidak membuktikan target produk/load |
| Reliability | Parsial | Receipt/replay, transaksi, retry dan backup direncanakan/tersedia sebagian; failover/PITR dan konflik seluruh domain belum diuji. “Kegagalan 10–15%” pada A9 baris 587 membutuhkan definisi kondisi/denominator; tidak boleh diartikan kehilangan data yang boleh terjadi |
| Availability | Parsial | Konsep local-first ada; perangkat/luring dan proses produksi belum diverifikasi dalam review backend |
| Security | Terarah | Hash password, sesi, permission, HTTPS/proxy trust, bound params dan validation tersedia; audit akses fitur masa depan tetap diperlukan |
| Maintainability | Terarah | Vertical slice, batas transaksi bersama, kontrak, review dan migrasi baru; tidak mengubah migration applied |
| Portability | Parsial | Batas backend Node/libSQL dan serahan Android/Flutter jelas; uji perangkat dan iOS tidak diklaim |
| Usability | Parsial | Serahan tim mobile dan usability mitra tercatat; belum dinilai dalam review ini |

**Verdict: FAIL untuk readiness memulai implementasi B006 tanpa refinement.** Coverage rencana luas terpenuhi, tetapi kebijakan eksak kuantitas/satuan/pembulatan serta koreksi ledger belum diputuskan. Ini blocker kontrak data B006 (R1–R2), bukan penolakan terhadap hasil B000–B005. Rencana sudah menyebut mitigasi, tetapi keputusan dan contoh penerimaannya belum tersedia untuk dipakai implementasi.

Tutup sebelum menulis B006: skala/range kuantitas per satuan; representasi/aritmetika eksak; aturan pembalikan/koreksi; kontrak operasi dan stable key; desain cek saldo atomik. Setelah kontrak dan acceptance test ditentukan, tinjau ulang gate. B019 tetap tertahan khusus revisi resmi.

## Kalender dan antrean kerja

Tanggal saat review masuk **Sprint 2 (23 September–15 Oktober)**. Sasaran backend Sprint 1 masih menyisakan B006 stok dan B007 penyemaian. Kelompok Sprint 2 B008–B011 belum diimplementasikan. Ini menunjukkan gap terhadap baseline, tanpa menghitung velocity atau menyimpulkan produk pasti terlambat.

Urutan berikut tetap: refinement B006 → B006 → B007 → B008–B010 → B011 → B012–B014 → B015–B016 → B017 → B018 → B019. Profil B003 sudah dipercepat; BMKG tetap paling akhir. Deadline produk 28 November 2026 merupakan target dokumen, bukan forecast yang telah terbukti. Forecast baru memerlukan estimasi, kapasitas backend/ML/mobile, integrasi, dan tanggal revisi BMKG.

## Skill dan batas review

- Perintah yang diminta, `npx skills add https://github.com/vercel-labs/skills --skill find-skills -y`, berhasil; output dan SKILL dibaca.
- Leaderboard [skills.sh](https://skills.sh/) dan pencarian requirements/business analysis/documentation ditinjau. Kandidat `business-analyst` dari aj-geddes muncul sekitar 2,3K installs, tetapi tidak tersedia lagi dengan nama itu di repository saat install. Tidak diklaim berhasil dipasang.
- Skill sesuai tugas yang dipasang dan diterapkan: `bmad-readiness-check` dari [aj-geddes/claude-code-bmad-skills](https://github.com/aj-geddes/claude-code-bmad-skills), corpus traceability dan readiness dokumen. Repository komunitas memiliki 487 stars saat pemeriksaan; instruksi dibaca sebelum dipakai. [Daftar skill repository](https://github.com/aj-geddes/claude-code-bmad-skills/tree/main/bmad-planning-orchestrator/skills) menjadi acuan nama aktual.
- `code-review` mattpocock sempat dipasang dan dibaca sebagai kandidat, tetapi tidak diterapkan: workflow membutuhkan fixed point/diff; tugas ini mengevaluasi dokumen dan status seluruh fitur.
- `caveman-learn` dibaca dan perintah `caveman learn report --json` dicoba; CLI tidak tersedia pada PATH. Tidak ada pengukuran/penghematan token atau perubahan konteks yang diklaim. Consent loop skill itu berlaku pada optimasi token; bukan hambatan untuk membuat laporan yang diminta.
- Runtime, migrasi, mobile, dan BMKG tidak diubah pada review ini. Hasil 85 tes/typecheck/build dan Turso live memakai bukti eksekusi sebelumnya, bukan run baru. Status deploy merupakan bukti pada waktunya, bukan pemantauan real-time.

## Tindak lanjut

1. Gunakan laporan ini untuk memperbarui status aktif rencana; tandai catatan kondisi awal dan remote sebelum deployment sebagai historis.
2. Finalkan keputusan ledger/angka/satuan/koreksi dan kontrak B006; kemudian implementasikan beserta uji konkurensi/replay/rollback.
3. Rekonsiliasi A9: pegawai panen, petani read-only inventaris, usia panen/HSS, istilah hash password, dan definisi reliability. Perubahan dokumen resmi ditangani tim perancang.
4. Pada tiap tahap, tutup endpoint + kontrak + permission + transaksi + bukti, lalu lanjut berurutan. Uji fitur pada staging remote sesuai risiko; jangan menyamakan schema applied dengan bisnis selesai.
5. B018 menutup alur noncuaca dan integrasi staging; B019 dibuka setelah revisi. Pisahkan backend siap, integrasi mobile, mutu model, dan penerimaan mitra sesuai DoD A9.
