# Dokumentasi HidroSense

Indeks catatan proyek. Setiap kali ada pekerjaan besar, tambahkan/ubah
dokumen di folder ini supaya konteks bisa dipulihkan tanpa riwayat percakapan.

## Daftar dokumen

- [`TASKS.md`](./TASKS.md) — task list proyek beserta statusnya.
- [`ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) — arsitektur aplikasi dan backend.
- [`panduan-menjalankan-backend.md`](../../../docs/panduan-menjalankan-backend.md) — cara
  menjalankan backend.
- [`progress-v2-onboarding-auth.md`](./progress-v2-onboarding-auth.md) —
  progress slice desain v2 “01 Onboarding & Auth”: peta file, alur, animasi,
  masalah dan solusinya, verifikasi, serta rencana lanjutan.
- [`progress-v2-login-session.md`](./progress-v2-login-session.md) — progress
  lanjutan: perbaikan logo maskot login v2, integrasi login v2 dengan login
  sungguhan, dan sesi tersimpan yang melewati login dalam masa berlaku.
- [`progress-v2-beranda-notifikasi.md`](./progress-v2-beranda-notifikasi.md) —
  progress slice desain v2 “02 Beranda & Notifikasi”: beranda Petani/Pegawai,
  keadaan memuat/offline/BMKG gagal, notifikasi, detail siklus, penyetelan widget
  shared, dan penyambungan login sungguhan ke beranda v2.
- [`progress-v2-akun.md`](./progress-v2-akun.md) — progress slice desain v2
  “03 Akun”: tab “Lainnya” (Petani) dan “Profil” (Pegawai), alur kelola akun
  pegawai (daftar, tambah, ubah, nonaktifkan, keluar), penyetelan widget shared,
  dan pembedaan akses Petani vs Pegawai.

## Konvensi catatan progress

Untuk tiap slice/fitur baru, buat satu file `progress-<nama>.md` yang berisi:

1. Tujuan dan aturan yang disepakati.
2. Sumber desain/tiket dan spesifikasi ringkas.
3. Peta file yang dibuat/diubah.
4. Keputusan penting dan alasannya.
5. Masalah yang ditemukan + solusinya.
6. Verifikasi yang sudah dilakukan (perintah + hasil).
7. Rencana lanjutan.

Perbarui [`TASKS.md`](./TASKS.md) setiap ada perubahan status.
