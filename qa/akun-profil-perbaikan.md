# Hasil — Perbaikan Ubah Profil (Petani & Pegawai)

Tanggal: 27 November 2026 · Branch: `wild-fe`
Catatan: `mcdocs/akun-profil-perbaikan.md`

Perubahan **front-end saja** (`apps/mobile/`). Backend tidak disentuh.

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Ubah profil belum ada pop-up konfirmasi | Sebelum mengirim `PATCH /profil`, muncul dialog **"Simpan perubahan profil?"**. Bila username/password ikut berubah, dialog menjelaskan bahwa pengguna akan diminta masuk lagi. |
| 2 | Ubah profil belum ada loading | Tombol **Simpan** di dialog menampilkan spinner selama permintaan berjalan; dialog tidak bisa ditutup lewat barrier, tombol Batal/back mati. Form baru menutup setelah server menjawab. |
| 3 | Berlaku untuk petani dan pegawai | Kedua peran memakai `V2ProfileFormPage` yang sama (dibuka dari "Akun saya"), jadi perbaikan berlaku untuk keduanya. |

## Perilaku setelah perbaikan

1. Tekan **Simpan** di form → validasi lokal berjalan.
2. Bila isian valid, dialog konfirmasi muncul; **server belum dipanggil**.
3. Tekan **Simpan** di dialog → tombol menampilkan spinner, form tetap terbuka.
4. Berhasil → form menutup dan detail profil menampilkan toast "Perubahan
   tersimpan". Bila username/password berubah → dialog "Kredensial diperbarui",
   lalu kembali ke layar masuk.
5. Gagal → dialog menutup, form tetap terbuka dengan isian utuh, dan galat
   tampil pada isian terkait atau SnackBar.

## Berkas berubah

- `apps/mobile/lib/views/v2/pages/v2_profile_form_page.dart`
  - `_save()` memakai `showV2ActionDialog`; `updateProfile` dijalankan di dalam
    `onConfirm`.
- `apps/mobile/test/v2_profile_test.dart`
  - Dua kasus regresi baru (konfirmasi + spinner, dan Batal tanpa panggilan
    server) memakai repository yang menahan hasil simpan.

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test test/v2_profile_test.dart test/v2_keyboard_footer_test.dart` | 10/10 lulus |
| `flutter test --concurrency=1` | **932/932 lulus** (930 sebelumnya + 2 kasus baru) |

## Uji ulang di HP (belum dijalankan)

Lihat baris `MC-FIX-76a`–`MC-FIX-76b` di `qa/manual_checklist.md`. Status masih
`FIXED di kode, belum diuji ulang di HP`.