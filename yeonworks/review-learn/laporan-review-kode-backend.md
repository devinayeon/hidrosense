# Laporan Review Kode Backend HidroSense

Tanggal: 2026-11-05
Kode yang diperiksa: `apps/backend`, `main` di commit `726fc64` (sama dengan `origin/main` ditambah satu commit lokal yang belum di-push)
Jenis pekerjaan: baca dan telusuri saja. **Tidak ada kode, database, atau migrasi yang diubah.**

## 1. Jawaban singkat

| Pertanyaan | Jawaban |
|---|---|
| Ada kode mati? | **Ada, tetapi sedikit dan tidak berbahaya.** Sebagian besar berupa cabang yang tidak bisa dicapai karena Zod sudah menolak inputnya lebih dulu, konstanta batas yang tidak pernah dilanggar, dan kolom atau izin untuk fitur yang belum dibangun. |
| Ada kode berulang? | **Ada, dan ini masalah terbesar dari sisi pemeliharaan.** Sembilan pola berulang di banyak fitur. Salinan rumus tanaman aktif dan pembaca berat terjual sudah mulai berbeda perilaku. |
| Ada logika salah? | **Ada.** Satu temuan keamanan tingkat tinggi, satu bug data di kode yang saya tulis sendiri, dan beberapa masalah siklus hidup data. Inti perhitungan (stok, kapasitas meja, tanaman aktif, uang) **terbukti benar**. |

Rincian angka:

- 75 temuan mentah dari lima pemeriksa, sekitar 60 setelah temuan kembar digabung.
- Tingkat: 1 tinggi, sekitar 14 sedang, sisanya rendah.
- 12 temuan paling penting sudah saya buktikan ulang dengan skrip saya sendiri. Semuanya terbukti, tidak ada yang terbantah.

## 2. Cara kerja dan batasnya

Kode dipecah menjadi lima irisan. Setiap irisan dibaca penuh oleh satu pemeriksa segar yang tidak tahu riwayat sesi ini, lalu menulis laporannya sendiri ke file.

| Irisan | Isi | Pemeriksa |
|---|---|---|
| A | `app.ts`, `server.ts`, `serverless.ts`, `config.ts`, seluruh `common/` | Sonnet |
| B | `db/`, 15 migrasi (naik dan turun), `sync/`, `scripts/` | Opus |
| C | `auth/`, `accounts/`, `inventory/` | Sonnet |
| D | `stock/`, `nursery/`, `tables/`, `transfers/`, `damage/` | Opus |
| E | `harvest/`, `sales/`, dan penyisiran duplikasi lintas fitur | Opus |

Selain itu saya menjalankan dua pemeriksaan alat sebelum pemeriksa bekerja:

- `tsc --noUnusedLocals --noUnusedParameters`: bersih, tidak ada variabel atau parameter tak terpakai.
- Pemindai ekspor: menandai 10 nama, tetapi sebagian besar dipakai di file sendiri atau hanya oleh test, jadi bukan kode mati. Yang benar-benar mati ada di bagian 5.

**Batas yang perlu diketahui:**

- Pemeriksa bisa keliru. Karena itu 12 klaim yang paling berdampak saya buktikan ulang (bagian 3). Sisanya **belum** saya buktikan ulang. Temuan dengan status `SUSPECTED` hanya hasil membaca kode.
- Semua bukti memakai database `:memory:` atau file sementara. Perilaku di Turso, di platform serverless, dan di bawah beban nyata **tidak diuji**.
- Tidak ada pembacaan kode mobile. Dampak ke aplikasi hanya diperkirakan.
- Laporan mentah tiap irisan ada di folder ini (`slice-A.md` sampai `slice-E.md`, berbahasa Inggris). Laporan ini merangkum dan menggabungkannya.

## 3. Temuan yang sudah saya buktikan sendiri

| ID | Temuan | Hasil bukti |
|---|---|---|
| **A1** (tinggi) | Request dengan target absolut (`GET http://x/api/v1/...`) melewati kuota IP dan pemeriksaan HTTPS | Soket mentah, 125 request: target biasa 120 kali `401` lalu 5 kali `429`; target absolut 125 kali `401` dan nol baris kuota. Production: `426` vs `401` |
| **B1** (sedang) | `db:rollback` pada database bernomor lama membatalkan migrasi yang salah | Diminta membatalkan `0012_operation_key_lower`, yang dibatalkan malah `0011_harvest_weights`. Kolom `detail_panen.berat_minor` hilang |
| B3 | Indeks `lower(operation_key)` tidak terpakai pada pencarian resi | `EXPLAIN` hanya memakai `id_user=?`, lalu mengurutkan semua resi pengguna itu. Tanpa `OR`, indeks dipakai penuh |
| C3 | PATCH dengan nilai yang sama menaikkan versi | Versi 1 menjadi 2. Perangkat lain dengan `expected_version` lama kena `409 VERSION_CONFLICT` |
| C5 | PATCH username yang sama mencabut semua sesi akun itu | Token pegawai menjadi `401` setelah petani mengirim username yang sama |
| D1 | Penyemaian `selesai` terkunci permanen | Semai 50, pindah 50, lalu ubah `jumlah_benih` atau `keterangan` dibalas `409 SOWING_COMPLETED` |
| D2 | `jumlah_benih` diturunkan ke jumlah terpindah membuat sowing `aktif` tanpa sisa | `sisa_benih: 0`, `siap_pindah: true`, pemindahan berikutnya `409 SEEDLING_INSUFFICIENT` |
| D5 | Meja yang tepat penuh dibalas "sedang tidak dapat digunakan" | Kurang lubang: `TABLE_CAPACITY_EXCEEDED`. Tepat penuh: `TABLE_NOT_AVAILABLE` |
| E3 | Mengubah bobot panen tidak mengumumkan penjualannya | `berat_layak` pada penjualan berubah 9.00 menjadi 5.00, versi tetap 1, feed hanya memuat `panen` |
| E4 | Edit penjualan mengganti `id_detail_penjualan` | ID detail 1 menjadi 2 walau nilainya sama |
| E13 | Query liar ditolak di panen dan penjualan, diterima di inventaris dan akun | `?junk=1`: `400`, `400`, `200`, `200` |
| A13 | Konfigurasi `ajv`, cabang `error.validation`, dan tujuh izin AI tidak dipakai | Tidak ada `schema:` di route mana pun. Tiap izin AI muncul sekali, di definisinya |

**B1 adalah bug di kode yang saya tulis sendiri** pada pekerjaan sebelumnya, yaitu penanganan penomoran ulang di `src/db/migrate.ts`. Fungsinya berjalan untuk arah `up` dan `down`. Pada `down` ia menghapus catatan migrasi lama terlebih dulu, sehingga migrasi berikutnya yang terbalik. Hanya terjadi pada database yang pernah memakai penomoran lama, dan hanya bila perintah rollback dijalankan. Perbaikannya kecil: jalankan hanya untuk arah `up`.

## 4. Logika salah

Urutan di bawah berdasarkan dampak. Kolom status menunjukkan apakah sudah saya buktikan sendiri (S), dibuktikan oleh pemeriksa dengan skrip (P), atau hanya dibaca (B).

### 4.1 Keamanan dan keandalan

| ID | Temuan | Dampak | Status |
|---|---|---|---|
| A1 | Target absolut melewati kuota dan HTTPS | Kuota 120/menit tidak berlaku bagi klien yang mengirim bentuk itu. Login tetap dibatasi sendiri. Proxy tepi biasanya menulis ulang target, jadi paparan nyata bergantung platform | S |
| A3 | Rotasi alamat IPv6 menghindari kuota login dan kuota IP | Satu blok /64 memberi 2^64 kunci. Rem yang tersisa hanya biaya scrypt sekitar 150 ms | P |
| B1 | Rollback salah sasaran (kode saya) | Kehilangan kolom bobot panen dan identitas sinkronisasi panen. Sekali jalan, hanya di database bernomor lama | S |
| B2 | Seeder menulis anak ke data nyata | Pada database yang sudah punya `inventaris` 1–5, `meja_tanam` 1, atau `penyemaian` 1, seeder tetap menyisipkan stok awal dan pemindahan 200 tanaman lewat SQL langsung. Setelah `auth:bootstrap`, seeder gagal `UNIQUE constraint failed: users.id_user`. Hanya berdampak di lingkungan pengembangan | P |
| A5 / C8 | Refresh tanpa masa tenggang | Respons refresh hilang di jaringan buruk memaksa login ulang. Ini keputusan desain yang sudah kita bahas, bukan bug baru | P |
| C7 | Logout butuh token akses yang masih hidup | Logout setelah token kedaluwarsa gagal `401`, dan refresh token tetap berlaku sampai 7 hari | P |
| A17 | Pembersihan saat start bisa menggagalkan boot | `server.ts` memakai varian yang melempar error | B |
| A8 / D13 / E11 | Hanya penulisan stok yang memetakan `SQLITE_BUSY` ke `503` | Penulisan lain membalas `500` untuk kegagalan sementara yang sama | B |

### 4.2 Siklus hidup data

| ID | Temuan | Status |
|---|---|---|
| D1 | Penyemaian `selesai` tidak bisa dikoreksi sama sekali. Salah hitung benih berarti sisa bibit asli tidak bisa dipindahkan | S |
| D2 | Dua jalur menuju "tidak ada sisa" menghasilkan status berbeda. Hanya pemindahan yang menandai `selesai` | S |
| D3 | `siap_pindah` benar untuk sowing `selesai` dan yang tanpa sisa, padahal pemindahannya pasti ditolak | P |
| D8 | Status `selesai` berubah otomatis tanpa menaikkan versi sowing | P |
| D4 | Tidak ada jalur koreksi: stok semai tidak bisa dibalik (`REVERSAL_NOT_ALLOWED` menjanjikan jalur yang tidak ada), kerusakan tidak bisa dihapus atau dikurangi ke nol, pemindahan tidak bisa diubah selain `keterangan` | P |
| C1 | Barang, jenis, dan obat yang dinonaktifkan tidak bisa diaktifkan lagi, dan stok yang tersisa terjebak | P |
| C11 | Jenis atau obat nonaktif tetap dirujuk barang aktif | P |
| B4 / E2 | Baris lama sebelum fitur sinkronisasi (penjualan, meja, pemindahan, kerusakan, penyemaian) tidak punya identitas. Tidak muncul di feed dan tidak bisa diedit. Berlaku bila ada baris lama; database pengembangan saat ini tidak punya penjualan | P |
| C3 / A7 | PATCH tanpa perubahan menaikkan versi dan menimbulkan konflik palsu | S |
| C2 | Perubahan huruf besar-kecil pada `satuan` diam-diam dibuang walau tanpa riwayat stok | P |
| C5 | Username yang sama mencabut semua sesi | S |

### 4.3 Konsistensi feed dan respons

| ID | Temuan | Status |
|---|---|---|
| E3 / B5 | Perubahan yang mengubah respons record lain tidak diumumkan: ganti nama jenis atau obat (mengubah `inventaris`), ganti `kode_meja` (mengubah pemindahan dan detail panen), ubah bobot panen (mengubah `berat_layak` penjualan) | S |
| D7 | PATCH `keterangan` kerusakan mengumumkan perubahan batch dan meja yang angkanya tidak bergerak | P |
| E4 | Edit penjualan menghapus lalu menyisipkan detail, sehingga ID detail berganti | S |
| E13 | Aturan "query liar ditolak" hanya berlaku di sebagian fitur | S |
| D15 / E12 | "Tanggal di masa depan" memakai tiga kode error berbeda (`SOWING_DATE_IN_FUTURE`, `INVALID_TRANSFER_DATE`, `VALIDATION_ERROR`) | B |
| E16 | `id_detail_panen` yang tidak ada di body dibalas `404`, bertentangan dengan aturan `422` untuk rujukan di body | P |
| E6 | Bobot layak bernilai NULL: `500` di panen, `409` di penjualan | P |
| E5 | Satu baris penjualan lama yang rusak menggagalkan seluruh halaman daftar | P |
| D12 | Penyemaian tidak wajib memakai benih: bahan pupuk saja diterima | P |
| E10 | `total_harga` bisa melebihi 2^53 (klien Dart atau JS kehilangan sen), dan penjualan positif bisa bernilai 0.00 | P |
| C4 | Pencarian pegawai memperlakukan `%` dan `_` sebagai wildcard | P |
| C6 | Username peka huruf besar dan tidak dinormalkan, aturan berbeda di bootstrap, pegawai, dan login | P |
| B15 | Tanggal stok seed memakai tanggal WIB tetapi ditampilkan sebagai UTC, bisa 12 jam di depan | P |

### 4.4 Skala dan pertumbuhan

| ID | Temuan | Status |
|---|---|---|
| A2 / B3 | Setiap penulisan memindai semua resi pengguna. Terukur 342 ms per panggilan pada 200.000 resi, dan 22 ms pada 20.000 | S (rencana kueri), P (waktu) |
| A6 / B10 | `sync_operations` dan `sync_changes` tidak pernah dipangkas. Satu halaman feed memakan 171 ms pada 100.000 baris. Sinyal reset hanya `cursor > MAX`, sehingga setelah `0015` turun lalu naik atau setelah restore cadangan, kursor lama bisa dipakai ulang tanpa terdeteksi | P |
| B9 | Setiap pembacaan penjualan menghitung ulang agregat seluruh `detail_panen` | P |
| A11 | `/health/ready` publik, tanpa kuota, tiga kueri per panggilan | B |

## 5. Kode berulang

| Pola | Salinan | Sudah berbeda perilaku? | Pembantu terkecil |
|---|---|---|---|
| Rumus tanaman aktif (dipindah − rusak − dipanen) | 5 (`tables`, `transfers`, `harvest`, 2 di `damage`) ditambah migrasi `0012` | Belum | Satu fragmen `batchActive` |
| Pembaca berat terjual untuk data lama | 4 (`harvest/service`, `sales/service`, `sales/store` dua fungsi) | **Ya.** Satu baris lama terbaca normal di GET tetapi menolak setiap penulisan baru, dan menolak edit catatan panen yang tidak terkait | `readSoldMinor` tunggal |
| `*/write.ts` | 8 | **Ya.** Pemetaan error, pesan header, kapan `clock()` dibaca, penanganan `expectedVersion` | `domainWrite(config)` |
| `expected_version` | 2 implementasi (inti dan panen/penjualan) | **Ya.** Wajib vs opsional, dan `HARVEST_/SALE_VERSION_CONFLICT` vs `VERSION_CONFLICT` | Lewatkan lewat `executeDomainMutation` |
| Parser desimal skala 100 | 3 (`quantities`, `weights`, `money`), 2 pemformat identik | **Ya.** Kelas error, tipe input, dan `5.5` vs `5.50` | `parseScaled` dan satu pemformat |
| Skema tanggal kalender | 5 | Belum | `calendarDateSchema` |
| Cek "tidak di masa depan" | 5 | **Ya.** Tiga kode error | `assertNotFuture` |
| Meta halaman, pengelompokan detail, pembuka transaksi baca, join identitas sinkronisasi, `nullableId` | 11, 3, 10, 8, 3 | Hanya baca satu GET tanpa snapshot di `stock` dan `nursery` | `pageMeta`, `groupRows`, `withRead`, `syncIdentityJoin` |
| Tiga resource inventaris | 3 handler | **Ya.** Cara menulis kolom, aturan keunikan nama, dan cek induk aktif | Satu pabrik daftar dan deaktivasi |
| Peran yang diizinkan | 3 tempat (`sessions.ts`, `refresh.ts`, `permissions.ts`) | Belum | Bangun daftar `IN (...)` dari `rolePermissions` |

Beberapa pola ini sudah tercatat di rework sebelumnya (`write.ts`, tanggal WIB). Yang baru di sini adalah bukti bahwa tiga di antaranya sudah menyimpang dalam perilaku.

## 6. Kode mati

| ID | Temuan | Status |
|---|---|---|
| A13 | Opsi `ajv`, cabang `error.validation`, daftar `redact` pino, `catch` di `requestPath`, default `clock` di `authorization.ts`, dan `(?![\s\S])` yang berlebihan | S (sebagian) |
| A13 / D10 | Tujuh izin AI dan perawatan (`deteksi`, `rekomendasi`, `perawatan`, `cuaca`) tidak diperiksa route mana pun, tetapi tetap dikirim ke setiap petani | S |
| A12 / D9 / E9 | Cek `minor > MAX` di tiga parser tidak bisa gagal karena regex sudah membatasi di angka yang sama. `MAX_SALE_WEIGHT_MINOR` tidak diimpor di mana pun | P |
| D10 | `origin && jenis_stok !== 'keluar'`, `original.id_perawatan`, `'keterangan' in input` yang selalu benar, `!assignments.length` yang tidak terjangkau, dan `status_penyemaian: 'aktif'` yang selalu tidak berarti | P |
| E7 / E8 | Pengecekan ulang detail di `updateSale` tidak terjangkau; hasil `validateLine` dibuang dan bobot di-parse dua kali | P |
| B7 | `verify-turso-features.mjs` tidak bisa lulus di skema mana pun sejak migrasi `0006` | P |
| B8 | Indeks `idx_sync_operations_change` pada alias rowid tidak pernah dipilih | P |
| B11 / B12 | Stok seed 1 tanpa identitas publik; kolom `created_at` di dua tabel sinkronisasi, `stok.id_perawatan`, dan tabel `penanganan_cuaca` tidak dibaca kode | P |
| A14 | Jalur kompatibilitas data lama di `executeOperation` tanpa tanggal berakhir. Bisa dihapus jika `SELECT count(*) WHERE operation_key <> lower(operation_key)` bernilai 0 di database nyata | B |
| C12 | Kolom `inventaris.stok_minimum` hanya ditulis. Dua kolom tidak bisa berbeda karena pemicu | P |

Izin AI dan `penanganan_cuaca` sebaiknya dibiarkan: itu persiapan fitur yang sengaja ditunda.

## 7. Yang diperiksa dan terbukti baik

- **Inti perhitungan benar.** Fuzz 400 langkah acak pada pemindahan, kerusakan, panen, kapasitas meja, dan `jumlah_benih` tidak menemukan pelanggaran: tidak ada meja melebihi kapasitas, tidak ada batch negatif, dan status `tersedia/penuh` tersimpan selalu sama dengan turunannya.
- **Semua pemeriksaan aturan berjalan di dalam transaksi tulis.** Delapan penjualan serentak ditambah edit panen berakhir konsisten (terjual 180 ≤ layak 200).
- **Autentikasi kuat.** Login tidak membocorkan keberadaan akun (waktu respons tidak terpisahkan), sesi terikat ke kredensial, dan setiap perubahan password, username, dan status mencabut sesi. Refresh sekali pakai dan aman terhadap balapan.
- **Keputusan sesi 7/30 hari berjalan tepat**, sampai detik batas 30 hari.
- **Idempotensi benar.** Retry mengembalikan resi yang sama, kunci sama dengan isi berbeda menjadi `409`, dan resi ikut batal bila efek dibatalkan.
- **Migrasi.** Setiap `down` membalik `up` (selisih skema hanya spasi), CHECK database sama atau lebih longgar daripada skema Zod, dan `migrate` atomik.
- **Feed.** Paging benar, termasuk saat record berubah di antara halaman; tipe yang tidak terdaftar tersembunyi dari semua pengguna.
- **Permukaan error.** Sepuluh jenis permintaan rusak semuanya menghasilkan amplop JSON tanpa SQL, jejak tumpukan, atau gema input.
- **Batas ukuran body** 16 KB tidak menolak payload sah terbesar (sekitar 12,5 KB).

## 8. Urutan perbaikan yang saya sarankan

**Segera (kecil, risiko rendah):**

1. **B1:** jalankan penanganan penomoran ulang hanya untuk arah `up`. Ini bug kode saya.
2. **A1:** tentukan "ini API" dari route yang cocok, bukan dari string URL, untuk kuota dan HTTPS sekaligus.
3. **A2 / B3:** cari `operation_key=?` lebih dulu, baru `lower()`; tambah indeks `lower(client_id)`.
4. **C3 / A7:** lewati kenaikan versi bila efek tidak mengubah apa pun.
5. **A17:** pakai `sweepExpiredAuthRecords` saat start.
6. **C5:** hanya cabut sesi bila username benar-benar berubah.
7. **E13:** satu `emptyQuerySchema` di semua route.

**Berikutnya (butuh migrasi atau perubahan kontrak):**

8. **D1 / D2 / D3 / D8:** turunkan status `selesai` dari `sisa_benih = 0` alih-alih menyimpannya.
9. **E3 / B5 / D7:** umumkan record turunan dengan benar.
10. **B4 / E2 / B11:** migrasi pengisi identitas untuk baris lama dan stok seed.
11. **B2:** seeder menolak jalan bila tabel seed sudah berisi baris yang bukan miliknya.
12. **E1 / B14 / E6:** satu pembaca berat terjual dan satu perlakuan untuk NULL.
13. **A4:** satukan `expected_version` panen dan penjualan ke inti.

**Perlu keputusanmu karena mengubah perilaku produk:**

- **D4:** perlu jalur koreksi untuk semai, kerusakan, dan pemindahan? Saat ini kesalahan input tidak bisa dibetulkan lewat API.
- **C1:** perlu endpoint aktifkan ulang untuk inventaris, jenis, dan obat? Dan apakah menonaktifkan barang bersaldo harus ditolak?
- **D12:** apakah penyemaian harus selalu memakai benih?
- **E10:** batas total penjualan agar klien Dart tidak kehilangan sen.
- **C6:** aturan username tunggal dan apakah tanpa pembeda huruf besar-kecil.
- **A5 / C7:** masa tenggang refresh dan logout dengan refresh token. Keputusan sesi sebelumnya menolak deteksi pemakaian ulang; masa tenggang 60 detik adalah hal berbeda dan perlu persetujuanmu.

**Ditunda:** B6 dan B7 (skrip Turso), karena Turso belum diuji.
**Refactor duplikasi (bagian 5):** lakukan setelah butir 1–13, agar perbaikan tidak bercampur dengan perubahan struktur.

## 9. Lampiran

| File | Isi |
|---|---|
| `slice-A.md` sampai `slice-E.md` | Laporan mentah tiap pemeriksa (Inggris), lengkap dengan jejak, input gagal, dan saran perbaikan |
| `bukti/verify-a.mjs`, `verify-b.mjs`, `verify-c.mjs`, `verify-d.mjs`, `verify-e.mjs` | Skrip pembuktian saya. Jalankan dari `apps/backend` dengan `node --import tsx <skrip>`. Semua memakai database `:memory:` |

Skrip bukti milik para pemeriksa tidak disimpan di repo; kutipan keluarannya ada di laporan mentah.
