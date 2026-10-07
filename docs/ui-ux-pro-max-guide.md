# Panduan Penggunaan Skill `ui-ux-pro-max`

Skill terpasang di `.agents/skills/ui-ux-pro-max/` (symlink ke `.claude/skills/ui-ux-pro-max`).
Berisi database desain lokal yang bisa dicari + skrip Python untuk querying.

Stack proyek ini: **Flutter** (`apps/mobile`) + backend. Jadi stack yang relevan
untuk query implementasi adalah `--stack flutter`.

---

## 1. Cara memicu skill

Skill dipanggil otomatis oleh agent dari deskripsi task-nya. Trigger dengan kalimat
yang jelas, contoh:

- "Rancang halaman monitoring air di app mobile"
- "Review UI halaman login, fokus pada kontras dan aksesibilitas"
- "Pilih palet warna dan font untuk dashboard"
- "Komponen ini jank / CLS tinggi, bantu perbaiki"

Kalau ingin eksplisit, sebut namanya: **"pakai ui-ux-pro-max untuk ..."**.

---

## 2. Menjalankan search tool

Jalankan dari root project. **Selalu pakai path lengkap** ke skrip (cwd bebas):

```powershell
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "<query>" --domain <domain>
```

> Catatan: path di `SKILL.md` memakai `${CLAUDE_PLUGIN_ROOT}` (untuk Claude Code plugin).
> Di project ini pakai path relatif `.agents\skills\ui-ux-pro-max\scripts\search.py`.

Prasyarat: Python 3 (sudah ada, v3.14). Tidak butuh dependency eksternal.

---

## 3. Alur kerja

### Langkah 1 — Tentukan konteks

Sebut dalam prompt:

| Yang perlu jelas | Contoh |
|---|---|
| Tipe produk | dashboard operasi, form laporan, monitoringIoT |
| Platform | Android + iOS (Flutter) |
| Kata kunci gaya | gelap, teknis, padat, glassmorphism |
| Api yang dipakai | get data, submit form, navigasi |

Kalau tidak menyebut gaya, agent akan menebak — jadi sebutin.

### Langkah 2 — Design system (untuk halaman/project baru)

```powershell
python .\.agents\skills\ui-ux-pro-max\scripts\search.py `
  "water quality monitoring dashboard technical dark" `
  --design-system -p "HidroSense" --density 8
```

Output: pattern landing, style, token warna, pasangan font, efek, dan daftar
anti-pattern yang harus dihindari.

**Dial opsional** (untuk '--design-system'):

| Flag | 1-3 | 4-7 | 8-10 |
|---|---|---|---|
| `--variance` | minimal, terpusat | modern seimbang | bold, asimetris |
| `--motion` | micro-interaksi halus | scroll/stagger | koreografi kompleks |
| `--density` | lapang (24-96px) | standar (16-64px) | padat/dashboard (8-32px) |

HidroSense = dashboard monitoring → `--density 8` wajar.

**Menyimpan hasil** (opsional, agar konsisten lintas sesi):

```powershell
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "<query>" `
  --design-system --persist -p "HidroSense" --output-dir .
```

Membuat `design-system/hidrosense/MASTER.md` + folder `pages/`.
`--page "<nama>"` menambah override per halaman.
Script **tidak menimpa** MASTER yang sudah ada kecuali diberi `--force` —
jadi baca dulu file lama sebelum memutuskan regenerate.

### Langkah 3 — Query domain spesifik (untuk masalah yang fokus)

```powershell
# Aksesibilitas
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "error summary validation" --domain ux

# Form & feedback
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "inline validation focus" --domain ux

# Grafik
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "real-time time series" --domain chart

# Warna & font
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "technical dark" --domain color
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "data dashboard" --domain typography

# Ikon (SVG, bukan emoji)
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "icon button accessible label" --domain icons
```

Domain tersedia: `product`, `style`, `color`, `typography`, `google-fonts`,
`chart`, `ux`, `landing`, `icons`, `gsap`, `react`, `web`.

Kalau `--domain` dipakai, **tetap sebutkan domain secara eksplisit** — auto-detect
sering salah路由 untuk kata yang ambigu (mis. "font" bisa ke `typography` atau `google-fonts`).

### Langkah 4 — Panduan implementasi stack (Flutter)

```powershell
python .\.agents\skills\ui-ux-pro-max\scripts\search.py "list performance rebuild" --stack flutter
```

Stack lain tersedia tapi tidak relevan di sini: `react`, `nextjs`, `html-tailwind`,
`swiftui`, `jetpack-compose`, `shadcn`, dll.

---

## 4. Cara menulis query yang bagus

- **Satu maksud dominan, 2-5 kata kunci.** `"keyboard focus modal"`, bukan seluruh checklist.
- **Format untuk a11y:** cari *outcome* dulu (`--domain ux`), baru detail
  komponen (`--domain icons`), baru stack (`--stack flutter`).
  Contoh: `"dragging movements" --domain ux` → `"accessibilityLabel" --stack flutter`.
- **Format untuk bug layout teks:** outcome dulu, baru stack.
  Contoh: `"badge chip label wraps" --domain ux` → `"chip overflow" --stack flutter`.
- **0 hasil?** Coba ulang sekali dengan query lebih sempit atau domain eksplisit.
  Kalau tetap kosong, japri bahwa jawabannya berasal dari default bawaan skill,
  bukan dari database. Jangan karang hasil.

---

## 5. Kalau butuh daftar rule lengkap

Baca langsung:

- `references/quick-reference.md` — semua 119 UX guideline + rationale, dikelompokkan per kategori.
- `references/pro-rules.md` — checklist pra-rilis untuk UI native/mobile
  (icon, touch feedback, kontras dark mode, safe area, aksesibilitas).

Prioritas kategori (pakai urutan ini saat review, atas ke bawah):
Accessibility → Touch & Interaction → Performance → Style Selection →
Layout & Responsive → Typography & Color → Animation → Forms & Feedback →
Navigation → Charts.

---

## 6. Checklist sebelum releasing UI mobile

- [ ] Tidak ada emoji sebagai ikon (pakai SVG: Lucide / Heroicons)
- [ ] Target sentuh minimal 44×44px, jarak antar-elemen ≥ 8px
- [ ] Kontras teks light mode ≥ 4.5:1
- [ ] Focus state terlihat untuk navigasi keyboard/screen reader
- [ ] `prefers-reduced-motion` dihormati
- [ ] Layout responsif diuji di 375 / 768 / 1024 / 1440px
- [ ] Safe area dihormati (notch, gesture bar)

---

## Contoh prompt siap pakai

**Halaman baru:**
> Pakai ui-ux-pro-max. Buat halaman daftar sensor untuk app Flutter HidroSense:
> dark, teknis, padat data. Generate design system dengan `--density 8`, lalu
> query stack flutter untuk performa list.

**Review a11y:**
> Pakai ui-ux-pro-max untuk review UI halaman login di `apps/mobile`. Fokus
> kontras, label ikon, dan target sentuh. Search `--domain ux` untuk
> accessibility, lalu `--stack flutter` untuk implementasi.

**Review chart:**
> Pakai ui-ux-pro-max. Grafik tren pH air kami bikin 45 orang tidak bisa baca
> warnanya. Cari panduan chart yang aksesibel.

---

## Sumber

- Detail & versi: https://skills.sh/nextlevelbuilder/ui-ux-pro-max-skill
- Update: `npx skills add https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max --yes`
