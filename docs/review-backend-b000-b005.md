# Audit fitur backend B000–B005

Tanggal: 2 Oktober 2026. Status audit awal: selesai dengan temuan belum diperbaiki. Remediasi lanjutan F1–F6 tersedia pada bagian terakhir; uraian temuan dan bukti awal dipertahankan sebagai catatan historis.

Audit mencakup kode workspace pada commit dasar `dfb61268f3e88334c8f6731df94f3c337847e105`, termasuk perubahan belum di-commit dari audit sebelumnya: penyatuan schema inventaris, penggunaan `RETURNING` untuk versi resource, dan tes validasi PATCH. Perubahan tersebut dipertahankan. Kesimpulan sebelumnya bahwa tidak ada overengineering besar bukan jaminan bahwa seluruh kasus batas telah bebas bug.

## Metode dan cakupan

Tiga sub-agent mengaudit kelompok fitur secara independen. Koordinator menjalankan suite regresi sekali dan mengulang reproduksi utama dengan database in-memory. Sub-agent verifier berbeda kemudian menilai ulang bukti, kontrak, prioritas, dan potensi false positive. Audit tidak menerapkan perbaikan runtime atau migrasi, tidak membuka database pengguna, serta tidak menyentuh mobile/BMKG.

| Tahap | Fitur yang diperiksa | Hasil |
| --- | --- | --- |
| B000 | Koneksi/FK/WAL, 19 tabel dan relasi DBML, migrasi 0001–0005 up/down, checksum/history, backup/restore, CLI | Tidak ditemukan defect konkret dalam cakupan lokal |
| B001 | Konfigurasi/startup/shutdown, health/readiness, error/header, HTTPS/proxy, CORS, throttle, validasi/body limit/logging | F3 dan F4 |
| B002 | Bootstrap, login, profil sesi, refresh, logout, hash password/token, role dan pencabutan sesi | F5; perbaikan race username dan jalur autentikasi ID string tetap ada |
| B003 | Create/list/detail/update/deactivate pegawai, get/update profil petani, transaksi dan revokasi sesi | Tidak ditemukan defect tambahan; ID akun besar diuji pada alur create sampai deactivate |
| B004 | Reservasi UUID, isolasi actor, canonical hash, replay/conflict, legacy receipt, mapping, revision, transaksi | F2 dan F6 |
| B005 | Create/list/detail/PATCH/deactivate jenis, obat, inventaris; referensi aktif, histori, desimal, UUID/versi, receipt atomik | F1 dan F2 |

Sumber persyaratan: `rencana-backend.md`, breakdown B001–B005, `backend-api.md`, `backend-accounts-api.md`, `backend-inventory-api.md`, laporan review sebelumnya, README backend, serta DBML. Semua handler dalam kelompok tersebut, shared consumers, migrasi relevan, dan tes terkait diperiksa. Graphify dipakai untuk navigasi hubungan; SQL diperiksa langsung karena ekstraksi SQL graph sebelumnya terbatas dependency.

## Temuan yang diverifikasi

### F1 — P2: ID inventaris signed64 gagal dibaca

Lokasi: `apps/backend/src/features/inventory/store.ts:33`, `:64`, `:74`, serta SELECT daftar pada `jenis-inventaris.ts:31` dan `obat.ts:33`.

Kontrak menerima ID string sampai `9223372036854775807`. Namun SELECT mengembalikan ID domain/referensi sebagai integer SQLite. Driver libSQL memakai mode number dan melempar `RangeError` sebelum `String(row.id)` berjalan untuk nilai di atas `9007199254740991`.

Bukti: record jenis/obat dengan ID `9007199254740993` menghasilkan HTTP 500 pada detail dan daftar; PATCH jenis dan create inventaris yang merujuk jenis besar juga gagal. Setelah `sqlite_sequence.seq=9007199254740992`, create ketiga resource menghasilkan 500. Domain row dan receipt baru tetap rollback dengan benar.

Dampak: record valid dari impor/legacy tidak dapat dipakai, satu record besar membuat halaman daftar gagal, dan create gagal pada sequence besar. ID kecil biasa tetap bekerja.

Perbaikan yang disarankan: CAST semua ID domain/referensi yang diproyeksikan menjadi TEXT, termasuk `inventarisColumns` dan SELECT daftar langsung. Hindari mengganti mode integer driver secara global tanpa meninjau consumer angka lain. Tes regresi perlu memuat ID sendiri, ID referensi, dan sequence besar.

### F2 — P2: kapitalisasi UUID klien memecah identitas stabil

Lokasi: `apps/backend/src/common/validation.ts:6`, `common/sync.ts:56`, `features/inventory/write.ts:17`.

Validasi menerima UUID upper/lower/mixed case tetapi penyimpanan dan hashing memakai teks asli. `client_id` yang hanya berbeda kapitalisasi mendapatkan mapping publik berbeda, padahal kontrak B004/B005 menjanjikan identitas UUID stabil. Representasi tersebut adalah bentuk teks UUID yang sama menurut [RFC 9562 bagian 4](https://www.rfc-editor.org/rfc/rfc9562.html#section-4).

Bukti: create obat dengan `X-Client-Id` lowercase, lalu create dengan uppercase dari UUID yang sama dan key operasi baru, menghasilkan dua respons 201 dan dua record/public UUID berbeda. Reservasi B004 dengan dua casing juga menghasilkan public UUID berbeda. Pengujian tetap terisolasi per actor.

Dampak: perubahan format UUID oleh serializer klien memutus reservasi-ke-create dan memungkinkan duplikasi terhadap UUID klien yang sudah terikat.

Perbaikan yang disarankan: tetapkan bentuk kanonik UUID sebelum lookup/hash untuk header maupun body. Pertahankan kompatibilitas receipt/mapping lama, dan evaluasi collision casing sebelum mengubah data tersimpan. Mengubah shared schema saja tidak cukup: validasi header saat ini hanya memeriksa keberhasilan parse lalu memakai teks header asli.

Batas klaim: perilaku `Idempotency-Key` upper/lower juga menghasilkan operasi berbeda, tetapi key tersebut dapat ditafsirkan sebagai teks opaque yang harus dipakai ulang persis. Itu tidak dihitung sebagai defect terpisah. Temuan F2 berfokus pada identitas `client_id` yang dijanjikan stabil.

### F3 — P2: preflight CORS melewati perlindungan HTTP universal

Lokasi: `apps/backend/src/app.ts:43`. Plugin CORS dipasang sebelum hook aplikasi pada baris 50.

Jika `CORS_ORIGINS` dikonfigurasi, hook CORS dapat menyelesaikan OPTIONS sebelum hook request ID/cache, HTTPS production, dan rate limit `/api/`. Kontrak `backend-api.md` tidak menyatakan pengecualian preflight.

Bukti: 121 OPTIONS ke `/api/v1/auth/login` dari origin yang diizinkan melalui HTTP production semuanya menghasilkan 204; jumlah bucket throttle tetap 0. Respons tidak memiliki `X-Request-Id` atau `Cache-Control`. GET HTTP biasa menghasilkan 426. Preflight tidak lengkap menghasilkan 400 `text/plain` dengan `Invalid Preflight Request`.

Dampak: kebijakan/header/error yang dijanjikan tidak berlaku pada preflight. Tidak ada autentikasi yang dilompati atau operasi bisnis yang dijalankan.

Perbaikan yang disarankan: jalankan hook universal sebelum CORS dapat mengakhiri request dan sesuaikan error preflight dengan envelope, atau dokumentasikan pengecualian yang memang dipilih secara eksplisit. Uji origin aktif, HTTPS, throttle, header, dan preflight tidak lengkap.

### F4 — P2: URL malformed melewati envelope error

Lokasi: `apps/backend/src/app.ts:26`; boundary normal `common/errors.ts` tidak menangkap respons router awal. Tes `test/http.test.js:41` belum memeriksa envelope/header kasus ini.

Bukti: GET `/%zz` menghasilkan 400 dengan body native Fastify `{"error":"Bad Request","code":"FST_ERR_BAD_URL",...}`. `error` berupa string, bukan object kontrak. `X-Request-Id` dan `Cache-Control` tidak tersedia.

Dampak: parser error klien dan korelasi request gagal pada kasus input ini. Tidak ada bukti credential disclosure.

Perbaikan yang disarankan: tangani boundary `frameworkErrors`/bad URL sebelum lifecycle biasa dan tambahkan assertion envelope/header pada tes yang ada.

### F5 — P3: bootstrap dengan akun ID besar memberi diagnostik salah

Lokasi: `apps/backend/src/features/auth/bootstrap.ts:19` dan `:21`.

Query pemeriksaan keberadaan memilih integer `id_user`, walaupun yang diperlukan hanya keberadaan row. Akun existing ber-ID `9007199254740992` memicu RangeError, bukan `ALREADY_BOOTSTRAPPED` atau `USERNAME_EXISTS` dengan status domain 409.

Bukti: dua database terpisah berisi petani existing atau pegawai dengan username yang sama dan tanpa petani. Keduanya menghasilkan `Received integer which cannot be safely represented as a JavaScript number`. Akun tetap utuh.

Dampak hanya diagnostik CLI pada operasi yang semestinya memang ditolak. Ini bukan endpoint HTTP 500, pembukaan akses, atau kerusakan akun. Perbaikan yang disarankan: gunakan `SELECT 1` untuk kedua probe dan uji bootstrap ulang/konflik akun besar.

### F6 — P3: kontrak request reservasi B004 belum lengkap

Lokasi: `docs/backend-b004.md:12`, `docs/backend-api.md:16`; schema aktual `features/sync/operations.ts:9`.

Pencarian dokumentasi tidak menemukan schema body lengkap, contoh request valid, envelope response reservasi, atau error per endpoint. Body membutuhkan `operation_key`, `operation_type`, `payload: {}`, `resource_type`, dan `client_id`; batas pola/max80 dan strict field rejection juga belum dijelaskan.

Dampak: klien tidak dapat membentuk request reservasi hanya dari dokumentasi publik. Definition of Done per slice mengharuskan request/response/error dan contoh; ini bukan penundaan sah ke B017.

Perbaikan yang disarankan: tambahkan kontrak HTTP setara atau OpenAPI untuk reservasi, termasuk perbedaan body `operation_key` terhadap header idempotensi B005, status 201/200/400/401/409, dan fakta bahwa reservasi tidak menaikkan versi.

## Integrasi find-skills

Perintah `npx skills use "https://github.com/vercel-labs/skills" --skill "find-skills"` dijalankan saat mulai dan diulang untuk setiap enam temuan. Output lengkap dibaca dari file sementara. Skill ini tidak menyediakan supporting-files atau referensi relatif pada output tersebut.

`find-skills` adalah workflow penemuan skill, bukan alat yang membuktikan correctness kode. Temuan diterima berdasarkan reproduksi, pembacaan source/kontrak, dan verifikasi sub-agent terpisah. Leaderboard diperiksa sebelum pencarian. Relevansi, jumlah instalasi, sumber, dan stars diperiksa sebelum memilih kandidat berikut; angka merupakan snapshot direktori pada saat audit, bukan jaminan kualitas.

| Temuan | Pencarian dan kandidat pendamping | Hasil evaluasi |
| --- | --- | --- |
| F1 | `sqlite`, `libsql`, `sqlite --owner martinholovsky`, `typescript --owner wshobson` | SQLite Database Expert ditemukan, tetapi repository hanya 47 stars dan statistik halaman/CLI tidak konsisten; tidak direkomendasikan sebagai otoritas verifikasi. Bukti utama tetap perilaku driver terpasang dan probe |
| F2 | `idempotency --owner wshobson` | Tidak ditemukan skill khusus. Kandidat umum nodejs-backend-patterns dan javascript-testing-patterns mendukung desain boundary dan tes kontrak; semantik UUID diperiksa terhadap RFC |
| F3 | `nodejs --owner wshobson` | nodejs-backend-patterns relevan untuk urutan middleware, guard, dan error boundary |
| F4 | `testing --owner wshobson` | javascript-testing-patterns relevan untuk assertion body/header integrasi, bukan hanya status |
| F5 | `database --owner wshobson` | nodejs-backend-patterns relevan untuk query/error boundary; tidak perlu ORM atau migrasi baru untuk probe keberadaan |
| F6 | `documentation --owner wshobson` | openapi-spec-generation relevan untuk schema/example/error; penerapan OpenAPI tidak diwajibkan karena kontrak HTTP setara sudah diizinkan proyek |

Kandidat yang lolos filter relevansi dasar, bukan klaim bahwa isi skill sudah dijalankan dalam audit ini:

- [nodejs-backend-patterns](https://skills.sh/wshobson/agents/nodejs-backend-patterns): sekitar 46.6K instalasi; contoh Fastify/middleware/database/error. Perintah instalasi: `npx skills add https://github.com/wshobson/agents --skill nodejs-backend-patterns`.
- [javascript-testing-patterns](https://skills.sh/wshobson/agents/javascript-testing-patterns): sekitar 19.6K instalasi; tes integrasi API/database. Perintah instalasi: `npx skills add https://github.com/wshobson/agents --skill javascript-testing-patterns`.
- [openapi-spec-generation](https://skills.sh/wshobson/agents/openapi-spec-generation): sekitar 15.6K instalasi; kontrak request/response/error. Perintah instalasi: `npx skills add https://github.com/wshobson/agents --skill openapi-spec-generation`.

Ketiganya berasal dari komunitas `wshobson/agents`, bukan vendor resmi Fastify/Turso; direktori melaporkan sekitar 40.1K stars repository. Tidak ada instalasi global tambahan atau penggantian framework/dependency dilakukan.

## Bukti tes dan batas kesimpulan

`npm run check` dijalankan sekali pada `apps/backend`: 71/71 tes lulus, typecheck lulus, file terbesar `test/inventory.test.js` 288/400 baris pada workspace audit ini. Tes tersebut belum mencakup temuan baru; kelulusan bukan bukti bahwa F1–F6 tidak ada. Build baru tidak dijalankan karena audit ini tidak mengubah kode runtime.

Koordinator mengulang probe ID, bootstrap, preflight, bad URL, dan casing UUID menggunakan database in-memory. Auditor juga menguji ID akun `9007199254740993` pada create/login/detail/update/deactivate, exact version di atas safe integer, snapshot replay, revokasi actor, desimal maksimum, dan referensi lama nonaktif.

Artefak sementara tersedia di `%TEMP%`: `hidro-audit-check.log`, `hidro-audit-b000-b001.md`, `hidro-audit-b002-b003.md`, `hidro-audit-b004-b005.md`, `hidro-audit-bootstrap-probe.mjs`, `hidro-audit-account-probe.mjs`, `hidro-b001-preflight.mjs`, `hidro-b001-boundary.mjs`, `hidro-b004-b005-repro.mjs`, `hidro-b004-b005-sequence-repro.mjs`, dan `hidro-b004-b005-contract-repro.mjs`. Probe dijalankan dari backend memakai `node --import tsx <path-script>`. File sementara dapat dibersihkan sistem; laporan ini menyimpan kondisi dan hasil reproduksi utama.

Version exhaustion pada `9223372036854775807` menghasilkan promosi SQLite ke REAL dalam probe, tetapi membutuhkan state ekstrem buatan dan tidak memiliki jalur workload realistis yang dibuktikan. Itu tidak dihitung sebagai temuan prioritas perbaikan. Penghapusan index revision lama dan restrukturisasi tambahan juga tidak memiliki manfaat terbukti dalam audit ini.

Turso remote, database deployment, reverse proxy nyata, perilaku klien eksternal, load dan timing side channel belum diverifikasi. Pull/push B017, ledger B006+, mobile, ML, dan BMKG bukan kekurangan implementasi B000–B005. Guard panen pegawai dan penolakan penjualan tetap mengikuti keputusan pengguna.

Urutan tindak lanjut yang disarankan: F1 dan F2 terlebih dahulu, F3/F4 kemudian, F5/F6 sebagai perbaikan kecil. Masing-masing perlu bukti regresi pada boundary yang disebut; tidak diperlukan refactor arsitektur besar.

## Remediasi lanjutan F1–F6

Perbaikan dilakukan sesuai urutan yang diminta pengguna: fase data/identitas, fase HTTP, lalu diagnostik/dokumentasi. Perubahan belum di-commit dari audit sebelumnya dipertahankan. Tidak ada migrasi baru, penggantian mode integer driver, dependency runtime baru, perubahan mobile/BMKG, atau akses database deployment/Turso.

| Temuan | Perbaikan | Regresi |
| --- | --- | --- |
| F1 | CAST seluruh ID domain/referensi inventaris menjadi TEXT; ORDER BY tetap memakai kolom integer tabel, bukan alias string | `inventory-id-boundaries.test.js`: detail/list/PATCH, ID referensi, create sequence besar, lifecycle dan urutan numerik |
| F2 | Canonical lowercase UUID klien pada body/header dan boundary sync; baca mapping lama tanpa membedakan casing; kenali hash receipt casing lama; collision berbeda public UUID ditolak 409 `CLIENT_ID_CONFLICT` | `sync-uuid-boundaries.test.js`: reservasi-ke-create, replay, duplicate rejection, legacy reservation/domain hash, konflik payload dan rollback collision |
| F3 | CORS hanya menyiapkan header dengan `preflightContinue`; hook universal menjalankan HTTPS/throttle/validasi sebelum mengakhiri OPTIONS. Error policy tetap mempunyai header CORS untuk origin yang diizinkan | `http-boundaries.test.js`: HTTPS, request ke-121, error preflight, header universal dan header CORS/Retry-After actual request |
| F4 | Handler error bersama dipakai pada `frameworkErrors` Fastify; request ID/no-store juga dipasang pada error router awal | Assertion tambahan pada `http.test.js` untuk error object, header/request ID, dan tidak adanya path/code router mentah |
| F5 | Kedua query keberadaan bootstrap memakai `SELECT 1` | `bootstrap-boundaries.test.js`: existing farmer dan konflik pegawai ber-ID signed64; akun tidak berubah |
| F6 | Schema, contoh request/response, error, auth, body operation key, casing, dan non-incrementing version dijelaskan dalam kontrak reservasi B004; dokumen utama/inventaris menautkannya | `sync-contract.test.js`: contoh dokumentasi aktual, envelope/replay, tidak adanya mutasi/versi, required/extra/invalid fields |

Tidak dilakukan rewrite mapping/receipt lama. Bila mapping lama sudah memiliki collision casing dengan public UUID berbeda, request berhenti sebelum mutasi; penyelesaian histori memerlukan keputusan data terpisah. Operation key tetap teks exact sesuai kontrak yang diperjelas, sedangkan UUID klien adalah identitas kanonik.

Review independen memeriksa F1–F6 dan menemukan satu regresi sementara pada respons throttle yang kehilangan header CORS. Regresi tersebut diperbaiki dengan membiarkan plugin menyiapkan header tanpa mengakhiri preflight; tes actual request 429 ditambahkan. Re-review scoped menyetujui perbaikan tanpa temuan tambahan.

Skill `find-skills` dijalankan kembali dan output lengkap dibaca. `nodejs-backend-patterns` lokal, serta output skill `javascript-testing-patterns` dan `openapi-spec-generation`, dipakai sebagai pedoman yang disesuaikan dengan Fastify, node:test, libSQL, dan kontrak HTTP Markdown proyek. Tidak ditambahkan Jest/Vitest, ORM, framework, atau generator API.

Verifikasi akhir remediasi: `npm run check` menghasilkan 85/85 tes lulus, typecheck dan batas baris lulus; `npm run build` serta `git diff --check -- apps/backend docs` lulus. File terbesar tetap `test/inventory.test.js` 288/400 baris. Log suite final tersimpan sementara di `%TEMP%/hidro-remediation-final-check.log`. F1–F6 ditangani dan review independen beserta re-review scoped lulus. Database deployment/Turso belum diperiksa atau dimigrasi; perubahan belum di-commit.
