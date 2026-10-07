# Modul 02: Pedoman Interaksi & Pengalaman Pengguna (UX & Interaction Guidelines)

Dokumen ini memuat standar interaksi, heuristik kegunaan (*usability heuristics*), fisika animasi, ergonomi sentuhan, dan umpan balik sistem untuk aplikasi **HidroSense Mobile** mengacu pada standar **Apple Human Interface Guidelines (HIG)** dan prinsip gerakan *Emil Kowalski*.

---

## 1. Ergonomi Layar Sentuh & Target Sentuh Minimum (Touch Targets)

Pekerjaan di kebun hidroponik sering dilakukan dengan satu tangan (tangan lain memegang baki bibit, TDS meter, atau botol nutrisi). Oleh karena itu, target sentuh harus mematuhi aturan ketat HIG:

### Aturan Target Sentuh:
1. **Ukuran Fisik Minimum $44 \times 44\text{ pt}$:**
   - Seluruh elemen yang dapat diklik (ikon back, tombol filter, dropdown, checkbox, tombol aksi) wajib memiliki bounding box interaktif minimal $44 \times 44\text{ pt}$, meskipun ikon visualnya hanya berukuran $20\text{ pt}$ atau $24\text{ pt}$.
   - Gunakan properti `IconButton(visualDensity: VisualDensity.standard)` atau bungkus widget kecil dalam `Padding` transparan untuk memperluas area ketukan.
2. **Jarak Antar Target Sentuh:**
   - Jarak minimum antar dua elemen sentuh yang berdampingan adalah `8.0pt` untuk mencegah ketidaksengajaan klik (*fat-finger prevention*).
3. **Zona Ibu Jari (The Thumb Zone):**
   - Elemen aksi kritis (tombol "Simpan", "Pindah Bibit", "Catat Stok", "Selesai Panen") harus ditempatkan pada sepertiga bawah layar (*Natural Thumb Zone*), bukan di sudut atas yang sulit dijangkau.

---

## 2. Fisika Animasi & Umpan Balik Taktil (Motion Physics)

Animasi di HidroSense bukan hiasan, melainkan alat untuk memberi kepastian status dan orientasi spasial (*spatial continuity*).

### A. Umpan Balik Tekanan Mikro (*Zero-Lag Press Feedback*)
Setiap kartu dan tombol interaktif harus merespons sentuhan dalam $<16\text{ ms}$ (frame pertama):

```dart
// Pola Respons Ketukan Apple HIG
AnimatedScale(
  scale: _isPressed ? 0.975 : 1.0,
  duration: const Duration(milliseconds: 110),
  curve: Curves.easeOutCubic,
  child: child,
)
```
- **Durasi Tekan:** `110ms` dengan kurva `Curves.easeOutCubic`.
- **Durasi Lepas:** `140ms` dengan kurva `Curves.easeOutBack` (sedikit membal alami).

### B. Transisi Antar Layar (*Screen Transitions*)
- Gunakan transisi dorong standar iOS (`CupertinoPageRoute` / slide horizontal dari kanan ke kiri dengan gesekan inersia).
- Layar detail memiliki gestur geser dari tepi kiri untuk kembali (*edge swipe to pop*).

### C. Modal Bottom Sheet (Aksi Tambah & Edit Cepat)
- Muncul dari bawah dengan kurva pegas (*spring curve* `Duration(milliseconds: 320)`).
- Dilengkapi pegangan visual (*Grabber Handle*): strip rounded pill ukuran $36 \times 5\text{ pt}$ di bagian atas sheet.
- Dapat ditutup dengan gestur seret ke bawah (*drag-to-dismiss*).
- Latar belakang utama digelapkan dengan barrier halus (`Color.fromRGBO(0, 0, 0, 0.35)`).

### D. Interpolasi Meter Progres (Progress Meters)
- Pengisian kapasitas lubang meja NFT dan usia semaian (HSS) tidak boleh melompat seketika.
- Gunakan `TweenAnimationBuilder<double>` dengan durasi `450ms` dan kurva `Curves.easeOutCubic` agar animasi terasa mengalir (*smooth fluid filling*).

---

## 3. Umpan Balik Haptik (Haptic Feedback)

Gunakan modul `HapticFeedback` untuk memberikan kepastian fisik saat pengguna berinteraksi di lapangan:

| Aksi Pengguna | Jenis Haptic | Fungsi & Sensasi |
|---|---|---|
| Pindah tab navigasi bawah | `HapticFeedback.selectionClick()` | Detik klik ringan saat beralih menu |
| Menekan tombol aksi utama | `HapticFeedback.lightImpact()` | Kepastian bahwa tombol berhasil ditekan |
| Nilai stepper kuantitas bertambah/berkurang | `HapticFeedback.selectionClick()` | Perubahan unit per digit |
| Pengisian formulir berhasil disimpan | `HapticFeedback.mediumImpact()` | Rasa selesai dan tervalidasi |
| Penghapusan data / pembatalan | `HapticFeedback.heavyImpact()` | Peringatan tindakan destruktif |
| Error validasi formulir | `HapticFeedback.vibrate()` | Peringatan instan kolom belum lengkap |

---

## 4. Heuristik Formulir & Input Data (Form UX)

Formulir operasional di HidroSense (seperti catat stok, semai benih, pindah meja) harus dirancang agar cepat diisi tanpa kebingungan:

### Aturan UX Formulir:
1. **Label Selalu Tampak (Pinned / Floating Labels):**
   - Jangan gunakan placeholder sebagai pengganti label. Begitu pengguna mengetik, placeholder hilang dan pengguna lupa nama kolom. Label harus selalu berada di atas input field.
2. **Papan Ketik Sesuai Tipe Data (Keyboard Adaptation):**
   - Kolom angka (jumlah benih, gram nutrisi, suhu, dosis obat): wajib memunculkan `TextInputType.numberWithOptions(decimal: true)`.
   - Tombol "Selesai" atau "Next" pada keyboard otomatis memindahkan fokus ke kolom berikutnya (*auto-focus navigation*).
3. **Validasi Sejajar Seketika (Inline Validation):**
   - Tampilkan pesan error tepat di bawah kolom yang bersangkutan dengan warna merah (`AppColors.dangerRed`) dan ikon peringatan kecil.
   - Jangan gunakan dialog popup untuk menyampaikan kolom kosong.
4. **Unit Satuan Terkunci (Suffix Badge):**
   - Kolom input kuantitas wajib memiliki badge satuan yang jelas di ujung kanan input (misal: `gram`, `liter`, `lubang`, `hari`) agar staf tidak salah tafsir satuan.
5. **Pencegahan Double Submit (Idempotency UX):**
   - Tombol simpan otomatis berubah menjadi indikator loading dan dinonaktifkan (`disabled`) seketika saat ditekan pertama kali untuk mencegah duplikasi data transaksi stok.

---

## 5. Penanganan State Layar (Empty, Loading, & Error States)

Setiap layar di HidroSense wajib memiliki 4 status visual lengkap:

### A. Loading State (Skeleton Shimmer)
- Hindari circular progress bar di tengah layar kosong yang membuat layar terasa lambat.
- Gunakan **Skeleton Shimmer** yang meniru bentuk kartu asli (kartu inventaris, baris semaian, meja NFT). Pengguna merasa data lebih cepat muncul ketika ada kerangka tata letak.

### B. Empty State (Layar Kosong Edukatif)
- Jika inventaris kosong atau belum ada semaian aktif:
  - Tampilkan ikon tematik berukuran $64 \times 64\text{ pt}$ dengan latar belakang lingkaran tint lembut.
  - Judul tegas: *"Belum Ada Semaian Aktif"*.
  - Subjudul penjelasan: *"Mulai semai benih selada atau pakcoy untuk memulai siklus tanam."*
  - **Satu Tombol Aksi Nyata (Clear CTA):** Tombol `+ Mulai Semai` langsung membuka formulir terkait.

### C. Error State (Pesan Solutif & Tombol Coba Lagi)
- Jangan pernah menampilkan error mentah (misal: *SocketException errno 111*).
- Tampilkan pesan yang ramah dan solutif:
  - Judul: *"Koneksi Layanan Terputus"*.
  - Deskripsi: *"Pastikan perangkat tersambung ke jaringan kebun atau server lokal aktif."*
  - Tombol: *"Coba Lagi"* (`RowButton` warna Navy) untuk melakukan fetch ulang tanpa harus menutup aplikasi.
