/**
 * Mesin rotasi obat: fungsi murni, tanpa akses database.
 *
 * Yang dirotasi adalah cara kerja obat (mode of action, skema IRAC), bukan nama produk. Dua produk
 * berbeda dengan MoA sama (mis. imidakloprid dan asetamiprid) tidak menghindari resistensi.
 *
 * Aturan tim (2026-11-28): satu siklus = 30 hari (satu generasi hama); dalam satu siklus cara kerja
 * yang sama paling banyak 2 kali semprot pada satu meja, sesudah itu wajib diganti.
 *
 * Aturan (pola forward chaining: fakta → aturan → kesimpulan):
 *   R1 ringan → cara paling ringan dulu (mekanis, lalu hayati, nabati)            ROT-PHT
 *   R2 sedang → hayati atau nabati dulu; bila tidak ada, kimia                    ROT-PHT / ROT-MOA
 *   R3 berat  → kimia; di antara yang lolos, MoA paling jarang dipakai siklus ini ROT-MOA
 *   R4 obat yang baru ditolak karena tidak tersedia atau harga tidak disarankan lagi
 *   R5 tidak ada pilihan yang lolos → opsi lain yang aman, tanpa melanggar R6     ROT-FALLBACK
 *   R6 keluarga MoA yang sudah 2 kali dalam 30 hari diblokir (resistensi silang ikut dihitung)
 *   R7 kimia hanya bila masa tunggu panennya muat dalam sisa hari menuju panen
 *   R8 rencana rotasi = kombinasi keluarga berbeda tanpa pasangan resistensi silang
 *   R9 hama lain dari foto yang sama sudah disarankan obat yang juga mencakup hama ini → obat itu
 *      didahulukan (dalam tingkat PHT yang sama), supaya satu semprotan menangani keduanya
 */
import { keluarga, keluargaMoa, silangDengan, susunRencana } from './combination.js';

/** Panjang satu siklus (hari). */
export const SIKLUS_HARI = 30;
/** Batas semprot per keluarga MoA dalam satu siklus. */
export const MAKS_APLIKASI_PER_SIKLUS = 2;
/** Banyaknya cara kerja berbeda dalam satu rencana. */
export const UKURAN_RENCANA = 3;

export type Jenis = 'mekanis' | 'hayati' | 'nabati' | 'kimia';
export type Tingkat = 'ringan' | 'sedang' | 'berat';

export interface Obat {
  id: string;
  bahan_aktif: string;
  jenis: Jenis;
  /** Kode kelompok MoA. Null untuk cara mekanis dan sebagian agen hayati. */
  kode_moa: string | null;
  /** Masa tunggu panen; null atau tidak ada berarti belum diketahui. */
  phi_hari?: number | null;
}

export interface Aplikasi {
  id_obat: string;
  kode_moa: string | null;
  /** YYYY-MM-DD */
  tanggal: string;
}

export interface RotationInput {
  tingkat: Tingkat;
  /** Obat yang berlaku untuk hama ini. */
  katalog: readonly Obat[];
  /** Tindakan nyata pada meja ini, urutan bebas. */
  riwayat: readonly Aplikasi[];
  /** Id obat yang baru ditolak di meja mana pun karena tidak tersedia atau harga (R4): ketersediaan dan harga berlaku untuk seluruh kebun. */
  dikecualikan?: readonly string[];
  /** Kode hama, untuk aturan resistensi silang. */
  hama?: string;
  /** YYYY-MM-DD. Tanpa ini seluruh riwayat dianggap satu siklus. */
  hariIni?: string;
  /** Sisa hari menuju panen terdekat di meja; null bila meja tidak punya tanaman aktif. */
  sisaHariPanen?: number | null;
  /** Id obat yang sudah disarankan untuk hama lain pada foto yang sama (R9). */
  pendamping?: readonly string[];
}

// `type`, bukan `interface`: hasilnya disimpan sebagai JSON oleh lapisan sinkron.
export type LangkahRotasi = {
  urutan: number;
  id_katalog: string;
  bahan_aktif: string;
  jenis: Jenis;
  kode_moa: string | null;
  /** Sisa semprot keluarga MoA ini dalam siklus; null untuk cara tanpa MoA (tidak dibatasi). */
  sisa_jatah: number | null;
};

export interface RotationResult {
  obat: Obat;
  rule_id: 'ROT-PHT' | 'ROT-MOA' | 'ROT-FALLBACK';
  alasan: string;
  /** Keluarga MoA yang jatah siklusnya habis. */
  moa_dihindari: string[];
  rencana: { jumlah_kombinasi: number; langkah: LangkahRotasi[] };
}

/** Urutan PHT: cara paling ringan lebih dulu. */
const tier: Record<Jenis, number> = { mekanis: 0, hayati: 1, nabati: 2, kimia: 3 };

const hariSejak = (hariIni: string, tanggal: string) =>
  (Date.parse(`${hariIni}T00:00:00Z`) - Date.parse(`${tanggal}T00:00:00Z`)) / 86_400_000;

/** Semprot per keluarga MoA; pasangan resistensi silang berbagi tekanan seleksi. */
function hitung(daftar: readonly Aplikasi[], hama: string | undefined) {
  const total = new Map<string, number>();
  for (const a of daftar) {
    if (a.kode_moa === null) continue;
    const kel = keluargaMoa(a.kode_moa);
    for (const k of [kel, ...silangDengan(hama, kel)]) total.set(k, (total.get(k) ?? 0) + 1);
  }
  return total;
}

/**
 * Benar bila satu semprotan lagi pada `tanggal` membuat suatu rentang 30 hari berisi lebih dari
 * 2 semprot keluarga MoA yang sama. Dipakai saat saran diterima: riwayat bisa berubah sejak dibuat.
 */
export function melampauiJatah(
  riwayat: readonly Aplikasi[],
  kodeMoa: string | null,
  hama: string,
  tanggal: string,
): boolean {
  if (kodeMoa === null) return false;
  const kel = keluargaMoa(kodeMoa);
  const terkait = new Set([kel, ...silangDengan(hama, kel)]);
  const semua = [
    ...riwayat.filter((a) => a.kode_moa !== null && terkait.has(keluargaMoa(a.kode_moa))).map((a) => a.tanggal),
    tanggal,
  ];
  const dalamSiklus = (t: string, awal: string) => hariSejak(t, awal) >= 0 && hariSejak(t, awal) < SIKLUS_HARI;
  return semua.some((awal) =>
    dalamSiklus(tanggal, awal) && semua.filter((t) => dalamSiklus(t, awal)).length > MAKS_APLIKASI_PER_SIKLUS);
}

export function recommendRotation(input: RotationInput): RotationResult | null {
  const { hariIni, hama } = input;
  const total = hitung(input.riwayat, hama);
  const siklus = hitung(
    input.riwayat.filter((a) => !hariIni || hariSejak(hariIni, a.tanggal) < SIKLUS_HARI),
    hama,
  );
  const habis = new Set([...siklus].filter(([, n]) => n >= MAKS_APLIKASI_PER_SIKLUS).map(([kel]) => kel));

  const sisa = input.sisaHariPanen ?? null;
  const amanPanen = (o: Obat) =>
    o.jenis !== 'kimia' || sisa === null || (o.phi_hari != null && o.phi_hari <= sisa);
  const excluded = new Set(input.dikecualikan ?? []);
  const notBlocked = input.katalog.filter((o) => amanPanen(o) && !habis.has(keluarga(o)));
  const allowed = notBlocked.filter((o) => !excluded.has(o.id));
  const dipakai = (peta: Map<string, number>, o: Obat) => peta.get(keluarga(o)) ?? 0;
  const bersama = new Set(input.pendamping ?? []);
  const terpisah = (o: Obat) => (bersama.has(o.id) ? 0 : 1);
  const rank = (a: Obat, b: Obat) =>
    tier[a.jenis] - tier[b.jenis]
    || terpisah(a) - terpisah(b)
    || dipakai(siklus, a) - dipakai(siklus, b)
    || dipakai(total, a) - dipakai(total, b)
    || a.bahan_aktif.localeCompare(b.bahan_aktif)
    || a.id.localeCompare(b.id);

  const avoided = [...habis].sort();
  const keadaan = avoided.length > 0
    ? `Kelompok MoA ${avoided.join(', ')} sudah ${MAKS_APLIKASI_PER_SIKLUS}x dalam ${SIKLUS_HARI} hari: wajib diganti.`
    : siklus.size > 0
      ? `Batas ${MAKS_APLIKASI_PER_SIKLUS}x per ${SIKLUS_HARI} hari: dipilih cara kerja yang paling jarang dipakai.`
      : `Belum ada semprotan ber-MoA pada meja ini dalam ${SIKLUS_HARI} hari terakhir.`;
  const notes = [
    keadaan,
    ...(excluded.size > 0 ? ['Obat yang baru ditolak karena tidak tersedia atau harga tidak disarankan lagi.'] : []),
    ...(sisa !== null && input.katalog.some((o) => !amanPanen(o))
      ? [`Panen ${sisa} hari lagi: kimia bermasa tunggu lebih panjang tidak disarankan.`] : []),
  ].join(' ');

  const langkah = (obat: Obat, i: number): LangkahRotasi => ({
    urutan: i + 1,
    id_katalog: obat.id,
    bahan_aktif: obat.bahan_aktif,
    jenis: obat.jenis,
    kode_moa: obat.kode_moa,
    sisa_jatah: obat.kode_moa === null ? null : MAKS_APLIKASI_PER_SIKLUS - dipakai(siklus, obat),
  });
  const pick = (kandidat: readonly Obat[], rule_id: RotationResult['rule_id'], lead: string): RotationResult | null => {
    const wakil = new Map<string, Obat>();
    for (const o of [...kandidat].sort(rank)) if (!wakil.has(keluarga(o))) wakil.set(keluarga(o), o);
    const { jumlah_kombinasi, pilihan } = susunRencana([...wakil.values()], hama, UKURAN_RENCANA);
    if (pilihan.length === 0) return null;
    return {
      obat: pilihan[0],
      rule_id,
      alasan: `${lead} ${notes}`.slice(0, 500),
      moa_dihindari: avoided,
      rencana: { jumlah_kombinasi, langkah: pilihan.map(langkah) },
    };
  };

  const ofJenis = (...jenis: Jenis[]) => allowed.filter((o) => jenis.includes(o.jenis));

  const primary = input.tingkat === 'ringan'
    ? pick(ofJenis('mekanis', 'hayati', 'nabati'), 'ROT-PHT', 'Serangan ringan: pilih cara paling ringan dahulu (PHT).')
    : input.tingkat === 'sedang'
      ? pick(ofJenis('hayati', 'nabati'), 'ROT-PHT', 'Serangan sedang: utamakan agen hayati atau nabati (PHT).')
        ?? pick(ofJenis('kimia'), 'ROT-MOA', 'Serangan sedang tanpa opsi hayati: pilih kimia secara bergantian.')
      : pick(ofJenis('kimia'), 'ROT-MOA', 'Serangan berat: ganti-ganti cara kerja untuk menekan resistensi.');
  if (primary) return primary;

  // R5: jangan pernah melampaui jatah siklus. Pakai opsi lolos mana pun, lalu abaikan pengecualian R4.
  return pick(allowed.length > 0 ? allowed : notBlocked, 'ROT-FALLBACK', 'Tidak ada pilihan utama yang lolos aturan.');
}
