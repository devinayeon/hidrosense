# Hasil — Perbaikan Perawatan (Deteksi & Riwayat Stok)

Tanggal: 27 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/perawatan-perbaikan-plan.md` · Tasks:
`mcdocs/perawatan-perbaikan-tasks.md`

Perubahan **front-end saja** (`apps/mobile/`). Backend tidak disentuh.

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Riwayat deteksi: foto tanpa hama jangan "Tanpa keyakinan" | `V2PindaiItem.labelKeyakinan` mengembalikan **"Tidak terdeteksi"** saat tidak ada hama. "Tanpa keyakinan" hanya muncul bila hama terdeteksi tetapi server tidak menyimpan skor. |
| 2 | Detail deteksi tanpa hama: hilangkan tombol riwayat rotasi | Tombol "Lihat riwayat rotasi obat" hanya dirender bila `onOpenRotasi != null` **dan** `item.adaHama`. Meta kartu berubah menjadi "Tidak terdeteksi" (bukan "Keyakinan Tidak terdeteksi"). |
| 3 | Potongan stok dari rekomendasi yang diterima tidak masuk riwayat | Kartu "Riwayat" kini membaca transaksi **terbaru lebih dulu**. Potongan stok perawatan yang baru diterima langsung tampil di tiga baris pertama. |

## Akar masalah "potongan stok tidak masuk riwayat"

Backend **sudah benar**: `acceptRecommendation` memanggil `recordMovement`,
yang menulis baris `stok` bertipe `keluar` dengan `id_perawatan`. Tes backend
`test/rotation-stock.test.js` membuktikannya (`SELECT COUNT(*) ... FROM stok
WHERE id_perawatan IS NOT NULL AND jenis_stok = 'keluar'` = 1).

Masalahnya di cara klien membaca:

1. `GET /api/v1/stok` mengurutkan **terlama dulu** (`ORDER BY s.id_stok`).
2. `inventoryHistoryProvider` meminta `limit=20` halaman 1 — yaitu 20 transaksi
   terlama.
3. `riwayatTampil()` mengambil **tiga baris pertama** untuk kartu "Riwayat".

Akibatnya transaksi baru (potongan perawatan) berada di ujung daftar dan tidak
pernah masuk tiga baris yang ditampilkan. Diuji dengan fixture nyata: masuk 100,
keluar 5, keluar 6, lalu terima rekomendasi potong 7 → API mengembalikan urutan
`1:masuk | 2:keluar | 3:keluar | 4:keluar`, dan kartu hanya menampilkan tiga
yang lama.

### Perbaikan (front-end)

`InventoryRepository.fetchLatestStockHistory()`:

1. Membaca `meta.total` lewat satu permintaan `limit=1`.
2. Mengambil halaman terakhir; bila halaman terakhir belum penuh, halaman
   sebelumnya ikut diambil supaya tiga catatan terbaru tetap utuh walau berada
   di batas halaman.
3. Membalik urutan halaman (terlama → terbaru) menjadi **terbaru → terlama**,
   lalu mengambil `limit` teratas.

Tidak ada perubahan kontrak backend. Usulan agar cukup satu permintaan
(`ORDER BY s.id_stok DESC`) dicatat sebagai butuh izin karena mengubah isi
halaman 1 `GET /stok`.

## Rincian perubahan berkas

- `apps/mobile/lib/views/v2/components/v2_rawat_data.dart`
  - Konstanta `v2PindaiTanpaHama`.
  - `V2PindaiItem.adaHama` dan `labelKeyakinan` baru.
- `apps/mobile/lib/views/v2/connected/v2_rawat_connected.dart`
  - Pemetaan pindaian tanpa hama memakai `v2PindaiTanpaHama`.
- `apps/mobile/lib/views/v2/pages/v2_pindai_detail_page.dart`
  - Meta kartu: "Tidak terdeteksi" / "Tanpa keyakinan" / "Keyakinan 87%".
  - Tombol riwayat rotasi hanya untuk foto berhama.
- `apps/mobile/lib/data/repositories/inventory_repository.dart`
  - `fetchLatestStockHistory()` + pembaca `meta.total`.
- `apps/mobile/lib/views/v2/connected/v2_inventaris_connected.dart`
  - `inventoryHistoryProvider` memakai `fetchLatestStockHistory()`.
- Uji baru: `apps/mobile/test/v2_perawatan_perbaikan_test.dart` (8 kasus).

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test test/v2_perawatan_perbaikan_test.dart` | 8/8 lulus |
| `flutter test --concurrency=1` | **930/930 lulus** (922 sebelumnya + 8 kasus baru) |
| `node --import tsx --test test/rotation-stock.test.js` (investigasi) | Lulus; memastikan baris `stok` perawatan memang ditulis |

## Uji ulang di HP (belum dijalankan)

Lihat baris `MC-FIX-75a`–`MC-FIX-75d` di `qa/manual_checklist.md`. Semua masih
berstatus `FIXED di kode, belum diuji ulang di HP`.