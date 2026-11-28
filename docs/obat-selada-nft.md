# Obat hama selada hidroponik NFT dan rotasinya

Disusun 28 November 2026. Dataset: [`data/obat-selada.csv`](data/obat-selada.csv), diturunkan dari
migrasi database (`apps/backend/migrations/0019`, `0020`, `0025`) dan dijaga oleh
`apps/backend/test/catalog-dataset.test.js`.

> Semua baris `terverifikasi = 0`. Belum ada pakar atau penyuluh yang memeriksa data ini. Aplikasi
> memberi saran, bukan resep. Ikuti label produk dan aturan pendaftaran pestisida yang berlaku.

## 1. Temuan utama

1. **Tidak ada satu pun pestisida terdaftar untuk selada di Indonesia.** Database pestisida terdaftar
   Kementan, diambil 28 November 2026: 8.085 produk unik ditambah 30 baris perluasan izin, **0 entri
   selada**. Tidak ada juga entri "sayuran" atau "hidroponik" sebagai komoditas.
2. Untuk kutu daun atau kutu kebul ada **359 produk** berizin aktif, seluruhnya pada komoditas lain
   (terbanyak cabai, tomat, jeruk, kentang, bawang merah). Itu bukan izin pakai untuk selada.
3. Angka masa tunggu panen (PHI) untuk selada hanya ditemukan pada **label Amerika Serikat**
   (UC IPM). Registri Kementan yang diambil tidak memuat PHI.
4. Tidak ditemukan data efikasi atau dosis yang diuji pada **selada hidroponik NFT**. Karena itu
   aplikasi tidak menampilkan dosis.

### Merek dagang di Indonesia

[`data/produk-indonesia-kutu.csv`](data/produk-indonesia-kutu.csv): 517 baris, 359 produk berizin
dengan sasaran kutu daun atau kutu kebul: merek, nomor pendaftaran, bahan aktif, komoditas, hama,
dosis terdaftar, dan masa berlaku. Dosis di berkas ini berlaku untuk komoditas yang tertulis,
**bukan untuk selada**.

Cara memperbarui: ambil ulang data dari database Kementan (butuh login), lalu jalankan
[`data/registri/susun_dataset.py`](data/registri/susun_dataset.py). Berkas mentah hasil pengambilan
tidak disimpan di repo. Periksa ketentuan akun sebelum membagikan data ini ke luar tim.

## 2. Sumber dan cara pengumpulan

| Sumber | Dipakai untuk | Cara dibaca |
|---|---|---|
| [Database pestisida terdaftar Kementan](https://ap-simpel.pertanian.go.id/pestisida?kategori_formula=pestisida_terdaftar) | Status registrasi, merek, komoditas, hama | Login pemilik akun, seluruh daftar dan perluasan izin, 28 Nov 2026 |
| [UC IPM Lettuce Pest Management Guidelines, 04/17](https://ipm.ucanr.edu/pdf/pmg/pmglettuce.pdf) | Bahan, kelompok MoA, PHI selada, batas 2x per musim | Dokumen penuh (bagian kutu daun, kutu kebul) |
| [UF/IFAS ENY989 (kutu kebul)](https://ask.ifas.ufl.edu/publication/IN1171) | Resistensi silang 9B dengan kelompok 4 | Cuplikan pencarian |
| [Label Efficon 120 SL (BASF Indonesia)](https://petani-sejahtera.basf.co.id/insektisida/efficon) | Bahan kelompok 36 | Halaman produk |
| [Lentera Bio UNESA](https://ejournal.unesa.ac.id/index.php/lenterabio/article/view/28434/26014) | Cendawan entomopatogen pada *Aphis gossypii* (cabai) | Cuplikan pencarian |
| [Perbanyakan *Menochilus sexmaculatus*](https://media.neliti.com/media/publications/85300-ID-teknik-perbanyakan-masal-predator-menoch.pdf) | Predator kutu daun | Cuplikan pencarian |
| [Hama selada hidroponik, Palembang](https://ojs.um-palembang.ac.id/jgsa/article/download/2261/803/14286) | *Aphis* sp. ditemukan pada selada hidroponik | Cuplikan pencarian |

Catatan mutu data registri: server melaporkan 8.090 entri, sedangkan ID uniknya 8.085 (lima baris
ganda, tetap sama setelah diambil ulang dengan urutan berbeda). Ejaan bahan aktif tidak seragam
(misalnya `imidaclorpid`, `thiametoxam`, `lamdasihalotrin`); skrip penyusun mencocokkan variannya dan
berhenti bila varian yang diketahui tidak cocok. 294 produk tidak mencantumkan komoditas.

Langkah sebelum dipakai nyata: minta pemeriksaan penyuluh (POPT), karena tidak ada produk berizin
untuk selada.

## 3. Bahan untuk kutu daun dan kutu kebul

K = kutu kebul, D = kutu daun. PHI dalam hari.

| Bahan | Jenis | MoA | Hama | PHI | Produk berizin di Indonesia (28 Nov 2026) | Disarankan |
|---|---|---|---|---|---|---|
| Buang daun terserang | mekanis | - | D, K | - | bukan pestisida | ya |
| Perangkap lengket kuning | mekanis | - | D, K | - | bukan pestisida | ya |
| *Aphidius colemani* | hayati | - | D | - | bukan pestisida | ya |
| *Menochilus sexmaculatus* | hayati | - | D | - | bukan pestisida | ya |
| *Encarsia formosa*, *Eretmocerus eremicus* | hayati | - | K | - | bukan pestisida | ya |
| *Amblyseius swirskii* | hayati | - | K | - | bukan pestisida | ya |
| *Beauveria bassiana* | hayati | UNF | D, K | - | komoditas lain: D 3, K 1 | ya |
| *Lecanicillium lecanii* | hayati | UNF | D, K | - | komoditas lain: D 1, K 1 | ya |
| Sabun insektisida | nabati | UNM | D, K | 0 | tidak ditemukan | ya |
| Azadirachtin (neem) | nabati | UN | D, K | 0 | komoditas lain: D 2, K 1 | ya |
| Flonikamid | kimia | 29 | D, K | 0 | komoditas lain: D 8, K 3 | ya |
| Flupiradifuron | kimia | 4D | D, K | 1 | komoditas lain: D 1, K 1 | ya |
| Spirotetramat | kimia | 23 | D, K | 3 | komoditas lain: D 5, K 3 | ya |
| Spiromesifen | kimia | 23 | K | 7 | tidak ditemukan | ya |
| Imidakloprid | kimia | 4A | D, K | 7 | komoditas lain: D 38, K 7 | ya |
| Asetamiprid | kimia | 4A | D, K | 7 | komoditas lain: D 10, K 5 | ya |
| Tiametoksam | kimia | 4A | D, K | 7 | komoditas lain: D 13, K 4 | ya |
| Dinotefuran | kimia | 4A | K | 7 | komoditas lain: D 3, K 3 | ya |
| Pimetrozin | kimia | 9B | D, K | 7 | komoditas lain: D 3, K 2 | ya |
| Lambda-sihalotrin | kimia | 3A | D | - | komoditas lain: D 16, K 2 | tidak, tanpa PHI selada |
| Diafentiuron | kimia | 12A | D, K | - | komoditas lain: D 2, K 6 | tidak, tanpa PHI selada |
| Buprofezin | kimia | 16 | K | - | komoditas lain: D 1, K 2 | tidak, tanpa PHI selada |
| Dimpropiridaz | kimia | 36 | D, K | - | komoditas lain: D 1, K 1 | tidak, tanpa PHI selada |
| Siantraniliprol | kimia | 28 | D, K | - | komoditas lain: D 4, K 6 | tidak, tanpa PHI selada |

Organofosfat dan karbamat (kelompok 1A, 1B) sengaja tidak dimasukkan: tidak ada alasan menyarankannya
untuk sayuran daun berumur pendek.

**Khusus NFT:** semprot daun saja. Jangan biarkan cairan semprot masuk ke larutan nutrisi, dan jangan
memakai cara aplikasi tanah (kocor) yang ada pada sebagian label.

### Bukti efikasi yang ditemukan

Tidak ditemukan data efikasi terhadap kutu daun atau kutu kebul pada selada hidroponik NFT. Yang
paling dekat:

- [Prince dan Chandler (2020), *Insects* 11(1):55](https://pmc.ncbi.nlm.nih.gov/articles/PMC7022964/):
  uji laboratorium dan **lapangan terbuka** di Inggris, bukan hidroponik. *Beauveria bassiana* GHA
  mematikan 71,0% kutu daun selada (*Nasonovia ribisnigri*) pada hari ke-9 di laboratorium; produk
  jamur lain 27,0% sampai 41,8%. Di lapangan, tidak ada perlakuan yang menghabiskan populasi. Kutu
  kebul tidak diuji.
- [Sahu dkk. (2025), *J. Entomological Research* 49(1)](https://indianjournals.com/article/jer-49-1-024):
  tinjauan hama selada hidroponik (kutu daun, kutu kebul, thrips). Hanya abstrak yang terbaca, tanpa
  angka.

Satu studi selada hidroponik tentang hidrogen peroksida dan agen hayati ada di ResearchGate tetapi
menolak akses otomatis. Layak dibuka manual.

Artinya: agen hayati di katalog adalah pilihan yang masuk akal untuk serangan ringan dan sedang,
bukan jaminan hasil. Pindai ulang beberapa hari sesudah perlakuan.

## 4. Berapa kali semprot sebelum hama kebal?

Tidak ditemukan angka pasti per bahan: itu bergantung pada populasi setempat, dosis, dan cakupan
semprot. Yang dipakai adalah **batas aman**:

- Aturan tim: **1 siklus = 30 hari** (satu generasi hama, kisaran 15–30 hari), dan dalam satu siklus
  cara kerja yang sama **paling banyak 2 kali semprot** per meja. Sesudah itu wajib diganti.
- UC IPM selada memberi batas serupa: kelompok MoA yang sama tidak lebih dari dua kali per musim.

Penerapan di mesin (`apps/backend/src/features/rotation/engine.ts`):

- Dihitung per **keluarga MoA**, bukan per merek. Imidakloprid lalu asetamiprid sudah 2 kali untuk
  keluarga 4. Subkelompok 4A dan 4D digabung.
- Kutu kebul: kelompok 9B dan keluarga 4 berbagi jatah (resistensi silang).
- Berlaku juga untuk bahan nabati dan hayati berkode (UN, UNF, UNM). Cara tanpa kode (mekanis,
  predator, parasitoid) tidak dibatasi.
- Hanya rekomendasi yang **diterima** yang memakai jatah.
- Hitungan per meja. Satu semprotan dihitung untuk semua hama di meja itu.

## 5. Matematika kombinasi

Dari `n` keluarga cara kerja yang lolos aturan dipilih rencana berisi `k = 3` keluarga:

```
C(n, k) = n! / (k! × (n − k)!)
```

Kombinasi dipakai untuk **memilih himpunan** (urutan tidak penting). Himpunan yang berisi pasangan
resistensi silang dibuang. Urutan di dalam himpunan (permutasi, `3! = 6` kemungkinan) tidak diacak:
mengikuti peringkat jenis (mekanis, hayati, nabati, kimia), lalu yang paling jarang dipakai dalam
30 hari, lalu sepanjang riwayat. Langkah pertama menjadi saran yang bisa diterima atau ditolak.

Kapasitas satu siklus = `2 × jumlah keluarga yang tersedia`. Hasil simulasi dari katalog nyata,
serangan berat, meja tanpa riwayat:

| Hama | Keluarga kimia | C(n, 3) sah | Rencana pertama | Semprot kimia maksimal per 30 hari |
|---|---|---|---|---|
| Kutu daun | 4, 9B, 23, 29 | 4 | Asetamiprid (4A) → Flonikamid (29) → Pimetrozin (9B) | 8 |
| Kutu kebul | 4+9B, 23, 29 | 2 | Asetamiprid (4A) → Flonikamid (29) → Spiromesifen (23) | 6 |
| Thrips | 4, 5, 6, 23 | 4 | Abamektin (6) → Imidakloprid (4A) → Spinosad (5) | 8 |

Dekat panen, bahan yang PHI-nya lebih panjang dari sisa hari panen keluar dari hitungan.

Angka "maksimal" adalah batas atas aturan rotasi, **bukan anjuran** menyemprot sebanyak itu. Label
produk sering membatasi lebih ketat.

## 6. Alur aplikasi dan pipa data

```
Registri Kementan ──susun_dataset.py──> produk-indonesia-kutu.csv, ringkasan → status_registrasi (0025)
                  └─susun_merek.py────> merek_obat, merek_bahan (0026)

Foto → model YOLOv11n di HP (kelas: whitefly, aphids; ambang keyakinan 0,5)
     → jumlah per hama → POST /pindaian (deteksi_hama)
     → POST /rekomendasi-obat per hama
         · hama harus ada di foto itu (DETECTION_PEST_MISMATCH)
         · tingkat_model dihitung server dari jumlah dan ambang tabel hama; tingkat pilihan petani
           tetap dipakai, perbedaannya tercatat di alasan
         · mesin R1–R9: PHT, 2x per 30 hari per keluarga MoA, masa tunggu panen, kombinasi C(n, 3),
           obat bersama untuk hama lain di foto yang sama
     → Terima: bahan stok dicek terhadap MoA saran (tautan katalog atau nama merek terdaftar;
               MATERIAL_MISMATCH), lalu perawatan + potong stok
       Tolak : alasan opsional
     → riwayat rotasi = perawatan per meja; saran beberapa hama dari foto sama dengan obat sama
       dihitung satu semprotan
```

Penjaga konsistensi (tes backend `rotation-ai-link.test.js`, `catalog-dataset.test.js`): ambang tingkat
server = aplikasi, indeks kelas = `labels.txt`, normalisasi merek Python = server untuk semua merek,
catatan registrasi = ringkasan registri, katalog = `obat-selada.csv`.

### Audit data lama

Perilaku sebelum migrasi 0026 bisa meninggalkan data yang salah. Jalankan **hanya baca** pada salinan
database sebelum memutuskan perbaikan:

```sql
-- Saran yang mengutip foto padahal hama itu tidak terdeteksi di foto tersebut.
SELECT r.id_rekomendasi, r.kode_hama, r.id_hasil_deteksi, r.status_rekomendasi
FROM rekomendasi_perawatan r
WHERE r.id_hasil_deteksi IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM deteksi_hama d WHERE d.id_hasil_deteksi = r.id_hasil_deteksi AND d.kode_hama = r.kode_hama);

-- Perawatan yang memotong stok barang tertaut obat katalog ber-MoA lain (perkiraan: beda kode MoA).
SELECT p.id_perawatan, r.kode_moa AS moa_saran, k.bahan_aktif AS bahan_stok, k.kode_moa AS moa_stok
FROM perawatan p
JOIN rekomendasi_perawatan r ON r.id_rekomendasi = p.id_rekomendasi
JOIN stok s ON s.id_perawatan = p.id_perawatan
JOIN detail_stok d ON d.id_stok = s.id_stok
JOIN inventaris i ON i.id_inventaris = d.id_inventaris
JOIN obat_katalog k ON k.id_katalog = i.id_katalog
WHERE COALESCE(k.kode_moa, '') <> COALESCE(r.kode_moa, '');
```

Barang bernama merek tanpa tautan katalog tidak tertangkap kueri kedua; periksa lewat aturan di
`apps/backend/src/features/rotation/material.ts`.

## 7. Hubungan dengan jurnal rujukan

Khotimah dkk. (2024), *Implementasi Sistem Pakar Forward Chaining pada Deteksi Penyakit Tanaman
Selada*, Jurnal Minfo Polgan 13(1), DOI 10.33395/jmp.v13i1.13613.

- Yang diadaptasi: pola **forward chaining** (fakta → aturan IF–THEN → kesimpulan). Fakta di sini:
  hama, tingkat serangan, riwayat semprot meja, sisa hari panen, penolakan terakhir.
- Yang **tidak** ada di jurnal: data obat, rotasi, resistensi, dan kombinasi. Jurnal itu membahas
  diagnosis 7 penyakit dari 18 gejala. Bagian rotasi berasal dari sumber di bagian 2 dan aturan tim.
