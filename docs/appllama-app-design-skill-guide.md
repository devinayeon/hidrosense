# Panduan Penggunaan Skill `appllama-app-design-skill`

Skill v1.3.0 (MIT, author Appllama), terpasang di
`.agents/skills/appllama-app-design-skill/` (symlink ke `.claude/skills/`).

Tidak ada skrip, tidak ada CLI, tidak ada data CSV. Ini **skill dokumentasi murni**
— isinya aturan, hukum desain, dan checklist yang dibaca agent saat task cocok.
Jujur saja: satu-satunya cara memakainya adalah dengan menyuruh agent
mengikutinya.

---

## ⚠️ Baca ini dulu: mismatch stack

| | |
|---|---|
| Asumsi stack skill ini | **Expo + Expo Router, React Native, TypeScript**, Reanimated, FlashList, `expo-image` |
| Mobile app HidroSense | **Flutter** (`apps/mobile/pubspec.yaml`, Dart) |

Hampir semua implementasi konkret di skill ini (Reanimated, `router.push`,
`usePreventRemove`, `borderCurve`, `Color.ios.label`, FlashList) **tidak bisa
dipakai apa adanya** di project ini. Yang bisa dipakai adalah lapisan
*design law*-nya, yang stack-agnostic:

- ✅_nav semantics_ (push vs replace, modal vs sheet, one-way door, back behavior)
- ✅ Anti-slop laws (satu accent, satu grey family, shape lock, no emoji sbg ikon)
- ✅ Motion laws (frequency gate, spring untuk gesture, <300ms ease-out)
- ✅ State architecture (server/client/ephemeral dipisah, optimistic by default)
- ✅ Definisi "done" per layar & simulator loop
- ❌ Semua snippet kode RN, nama API Expo, dan rekomendasi package

**Kalau agent diam-diam menulis `router.push()` atau `react-native-reanimated`
di project Flutter, itu salah** — skill ini menyebut "override only if the
project already differs", dan project ini berbeda. Katakan eksplisit di prompt:
"kita di Flutter, jangan pakai API React Native."

Skill ini paling berguna kalau project ini nanti punya app React Native/Expo,
atau kalau agent butuh standar mutu yang lebih tinggi untuk review UI.

---

## 1. Cara memicu skill

Skill ke-trigger dari kalimat seperti:

- "Buat halaman X" / "design the onboarding" / "bikin flow login"
- "Poles UI ini" / "make it feel native"
- "Screen ini kok jelek" / "review tampilan halaman sensor"
- "Wiring navigasi ke detail screen"

Untuk memaksa, sebut namanya: **"pakai appllama-app-design-skill untuk ..."**.

---

## 2. Alur kerja yang diwajibkan skill

### Langkah 0 — Riset dulu, baru desain

Skill ini membuka dengan *Prime Directive*: jangan desain dari imajinasi.

1. Kalau **Appllama MCP** terhubung, tarik layar asli untuk kategori + tipe
   screen yang sedang dibuat, pelajari 20–30 layar.
2. Ambil **polanya, bukan pixelnya**: skeleton layout, hierarki informasi,
   pilihan kontrol, ritme spasi, posisi CTA utama.
3. Baru desain screen sendiri: skeleton yang sudah terbukti, suara produk sendiri.

> Tanpa MCP: bilang ke agent untuk skip dan jelaskan alasannya, jangan
> berpura-pura sudah riset.

### Langkah 1 — Jawab, apa itu screen ini secara navigasi

Tiga pertanyaan wajib sebelum ngajar UI:

1. **Apa tujuannya ke sini?** → push (pakai `replace` kalau tidak bisa kembali)
2. **Back ngapain?** → chevron, iOS edge swipe, Android hardware back
3. **One-way door?** → kalau yes (login, onboarding selesai, pembelian, sesi selesai),
   back **tidak boleh** bisa masuk lagi ke state lama

### Langkah 2 — Terapkan design laws

 urutan prioritas: anti-slop → native fidelity → navigasi → motion → state → performa.

### Langkah 3 — Loop simulator (non-negotiable)

```
implement → jalankan di simulator → screenshot lalu BACA screenshot-nya
          → full-motion pass (screen record) → perbaiki → ulangi
```

`"Looks fine"` BUKAN alasan berhenti. Stop at "cannot find a flaw at
100% zoom".

---

## 3. Isi tiap file di skill ini

| File | Isi | Kapan dibaca |
|---|---|---|
| `SKILL.md` | 12 native fidelity laws, 6 navigation laws, 9 anti-slop laws, motion laws, state architecture, checklist "done" | Selalu, ini inti |
| `references/native-controls.md` | Tabel pemilihan kontrol native iOS/Android + package RN | Kalau sedang memilih kontrol (⚠️ mostly RN) |
| `references/motion.md` | Dua keluarga motion (responsive/spring vs narrative/timing), pola Reanimated | Kalau sedang bikin animasi |
| `references/performance.md` | Loop ukur → perbaiki → ukur ulang, target angka (45→60fps, TTI 3.2→1.8s) | Kalau ada jank / TTI lambat |
| `references/image-assets.md` | Pipeline generate aset ilustrasi: pilih 1 style family, generate resolusi tinggi, downscale, jangan upscale | Kalau butuh ilustrasi/empty-state art |
| `references/simulator-loop.md` | Checklist verifikasi akhir + device matrix | Sebelum declare layar selesai |

Total hanya ~358 baris. Murah dibaca utuh ketika memang dipakai.

---

## 4. Konsep kunci yang paling sering disalahpahami

### Motion — "frequency gate" dulu, baru mikir animasi

| Seberapa sering | Contoh | Aturan |
|---|---|---|
| 100+×/hari | ganti tab, keyboard, scroll, back | **default platform, jangan tambah apa-apa** |
| puluhan ×/hari | press, pilih baris | nyaris tak terasa, **< 150 ms** |
| sesekali | sheet, modal, toast | motion standar |
| jarang, pertama kali | momen cantik | boleh delight |

Kalau ragu, gerakan terkuat adalah **menghapus animasinya**.

### Gesture = spring, sisanya = timing

- Kalau ada jari yang terlibat (swipe, drag sheet) → **spring**, seed dari velocity,
  target dari projected momentum supaya flick benar-benar commit, rubber-band
  melewati batas.
- Selain itu → `withTiming`, **ease-out kuat**, di bawah 300 ms, dan
  **exit lebih cepat dari entrance**.
- Satu kosakata motion per app, contoh `{ duration: 400, dampingRatio: 1 }` untuk settle.

### Anti-slop — ini default ban, bukan preferensi

Yang dilarang *kecuali* ada alasan brand yang bisa dijelaskan:

1. Gradien ungu/indigo CTA dengan glow, glassmorphism di semua kartu, mesh-gradient hero, confetti, sparkles di heading
2. Lebih dari satu warna accent di seluruh app
3. Grey hangat dan-grey dingin bercampur
4. Radius corner campuran tanpa aturan tertulis
5. Emoji sebagai ikon chrome
6. "Get started" + "Start now" + "Begin" untuk satu intent yang sama
7. Serif nyelip di headline sans (atau sebaliknya)
8. Cuma happy path — loading/empty/error harus dirancang, skeleton harus punya bentuk yang sama dengan layout final

Pre-flight-nya mekanis: hitung jumlah accent hue (harus 1), jumlah radius,
emoji di chrome (harus 0), gradien tanpa alasan brand (harus 0), label duplikat
(harus 0). Gagal hitung = harus diperbaiki, bukan "&ldquo;ya mohon&rdquo;".

### State architecture

- Server state → kueri dengan cache (bukan `useEffect` + `fetch`)
- Client state → store atomik kecil
- Ephemeral UI state → lokal di komponen
- Optimistic by default: tap terasa instan, rekonsiliasi di background, rollback
  yang jelas kalau gagal

---

## 5. Checklist "done" per layar

Adaptasi untuk Flutter:

- [ ] Sudah mempelajari 10+ screen referensi nyata untuk tipe screen ini, dan bisa menyebut polanya
- [ ] Navigasi terjawab: push / modal / sheet / replace, back apa yang dilakukan di iOS & Android, one-way door tidak bisa dimasuki lagi
- [ ] Light + dark mode terverifikasi di simulator
- [ ] Safe area / notch / home indicator aman
- [ ] State panjang-konten, kosong, loading, error — semuanya dirancang
- [ ] Motion: seluruh flow di-screen-record dan di-scrub — entrance, press, transisi, modal, keyboard; 60 fps di **release build** (bukan debug/Expo Go)
- [ ] Dynamic Type XL tidak merusak layout; teks yang perlu dicopy bisa diseleksi
- [ ] Semua tap target ≥ 44pt; kontras lolos di kedua tema
- [ ] Aset: satu style family, tajam di @3x, tidak ada halo composite
- [ ] List surface tervirtualisasi; tidak ada jank input; tidak ada badai re-render

---

## 6. Contoh prompt siap pakai

**Flutter, review layar:**
> Pakai appllama-app-design-skill untuk review UI halaman daftar sensor di
> `apps/mobile`. PENTING: kita di Flutter, bukan React Native — pakai
> navigation laws & anti-slop laws-nya, jangan tulis API RN/Expo.
> Fokus: back behavior, empty/loading/error state, dan kontras dark mode.

**Flutter, layar baru:**
> Pakai appllama-app-design-skill. Bangun halaman detail sensor di Flutter.
> Ini One-way door atau push? Jawab dulu, lalu kerjakan navigasi semantics-nya
> dan anti-slop check-nya. Jangan pakai Reanimated.

**Standar mutu (tanpa kode):**
> Pakai appllama-app-design-skill untuk menilai apakah UI `apps/mobile`
> terasa native. Laporkan yang gagal terhadap definition of done-nya.

---

## Sumber

- Detail & versi: https://skills.sh/Appllama/appllama-skills
- Update: `npx skills add https://github.com/Appllama/appllama-skills --skill appllama-app-design-skill --yes`
- Pasangan: Appllama MCP (untuk riset screen referensi)
