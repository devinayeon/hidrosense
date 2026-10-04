# B008 — Meja tanam

Tanggal: 4 Oktober 2026 (Asia/Jakarta). Scope: backend lokal B008 setelah B007; B009 dan deployment remote terpisah.

## Plan dan kontrak penerimaan

Sumber: `docs/rencana-backend.md` B08, PB-04 dan WBS 1.4.1–1.4.2 pada `docs/A9_PPL IF_WEEK5.docx.md`. Gunakan pola vertical slice Fastify yang sudah dipilih repo, konfigurasi terpusat dan error logger bersama. Pedoman Express/BaseController/Prisma/Sentry tidak mengganti stack proyek.

BFRI: architectural fit 5, testability 5, complexity 2, data risk 2, operational risk 1; hasil 5. Validasi kapasitas dan perubahan dijalankan dalam transaksi write dengan pemeriksaan sesi ulang.

- POST/GET `/api/v1/meja-tanam`; GET/PATCH `/api/v1/meja-tanam/:id`.
- Pegawai read/write (`budidaya:write`); petani read (`budidaya:read`), sesuai matriks System Request yang sudah dipakai backend.
- `kode_meja`: trim, 1–30 karakter, unik case-sensitive mengikuti UNIQUE baseline SQLite. `jumlah_lubang`: integer positif aman JavaScript. Tidak membatasi 12 meja atau 250 lubang.
- `status_meja`: teks manual trim 1–30 karakter, default `tersedia`. Dokumen belum menentukan enum fisik; jangan mengarang enum atau menghitung status dari okupansi.
- `keterangan`: null atau teks trim maksimal 1000 karakter. PATCH hanya mengubah field yang hadir; objek kosong ditolak.
- Tanaman aktif = jumlah dipindahkan dikurangi seluruh kerusakan dan panen per batch; agregasi terpisah mencegah perkalian join. Kapasitas tidak boleh di bawah tanaman aktif. Data historis tidak konsisten ditolak eksplisit, bukan disamarkan menjadi nol.
- ID/version berupa string. `public_id` stabil. Header opsional `Idempotency-Key` mengikuti master B005; bila dikirim wajib UUID. `X-Client-Id` hanya untuk create dan mendukung reservasi B004. Replay tidak menulis ulang; key/payload berbeda menghasilkan 409.
- Tidak perlu migrasi baru: kolom, UNIQUE kode dan indeks FK tersedia pada 0001; identitas/receipt memakai B004/B005. Invariant B008 dijaga transaksi aplikasi. Endpoint pemindahan B009 wajib memeriksa kapasitas dalam transaksi yang sama.

## Todo / task

- [x] T01: Cocokkan sumber, akses, kontrak dan dependensi.
- [x] T02: Implementasikan validasi, pembacaan kapasitas, operasi meja dan registrasi route.
- [x] T03: Uji akses, validasi, keunikan, pagination, PATCH parsial, kapasitas multi-batch, replay/rollback, identitas dan ID besar.
- [x] T04: Jalankan typecheck, check:lines, seluruh tes dan build.
- [x] T05: Review Standards dan Spec; selesaikan temuan relevan; perbarui graph dan dokumen.

## Definisi selesai

Seluruh task dan acceptance di atas terbukti melalui tes lokal; dokumentasi endpoint dan keterbatasan tersedia. Kelulusan lokal bukan bukti deployment atau integrasi mobile.


## Bukti akhir

- `npm run check`: typecheck, batas 400 baris dan seluruh 172 tes lulus (164 baseline + 8 tes B008 awal).
- `npm run build`: lulus.
- Sesudah review, dua tes tambahan membuktikan reservasi B004 dan rollback kegagalan receipt. Run terfokus `node --import tsx --test test/tables.test.js`: 10/10 lulus. Tidak ada perubahan runtime setelah gate penuh.
- Standards: 0 temuan blocking; Spec: 0 temuan blocking. Perilaku fail-closed untuk legacy overcapacity didokumentasikan; perbaikannya memerlukan rekonsiliasi data, bukan PATCH biasa.
- `graphify update .`: graph kode diperbarui. Parser SQL tidak tersedia dan header C++ mobile lama menghasilkan warning; keduanya tidak memblokir graph TypeScript.
- `git diff --check` global menemukan trailing whitespace yang sudah ada pada script Turso dan file mobile, di luar perubahan B008.

Skill remote `review` tidak ditemukan; `code-review` digunakan sebagai pengganti. Prosedur commit-diff diadaptasi menjadi review working tree karena B007/B008 belum di-commit. Baseline HEAD dicatat; hanya tambahan B008 dan registrasinya yang direview. `docs/agents/issue-tracker.md` belum tersedia; `/setup-matt-pocock-skills` dapat dipakai untuk menyiapkan integrasi tracker pada review mendatang. Spesifikasi lokal cukup untuk review ini.

B008 selesai secara lokal. B009 adalah tahap berikutnya. Tidak ada klaim deployment remote atau uji konkurensi pemindahan B009.

## Review lanjutan

[Audit B007–B008](../reviews/b007-b008-2026-10-04.md) menambah dua tes regresi B007 dan satu tes migrasi 0008. Gate penuh sesudah koreksi: 177/177 tes. Status B008 tetap selesai lokal.
