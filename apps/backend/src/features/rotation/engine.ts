/**
 * Mesin rotasi obat: fungsi murni, tanpa akses database.
 *
 * Yang dirotasi adalah kelompok mode of action (MoA, skema IRAC), bukan nama produk. Dua produk
 * berbeda dengan MoA sama (mis. imidakloprid dan asetamiprid, sama-sama 4A) tidak menghindari
 * resistensi, jadi keduanya dianggap pilihan yang sama.
 *
 * Aturan (pola forward chaining: fakta → aturan → kesimpulan):
 *   R1 ringan → cara paling ringan dulu (mekanis, lalu hayati, nabati)            ROT-PHT
 *   R2 sedang → hayati atau nabati dulu; bila tidak ada, kimia dengan MoA berbeda  ROT-PHT / ROT-MOA
 *   R3 berat  → kimia dengan MoA yang tidak dipakai pada 2 aplikasi ber-MoA terakhir ROT-MOA
 *   R4 obat yang baru ditolak karena tidak tersedia atau harga tidak disarankan lagi
 *   R5 tidak ada pilihan yang lolos → opsi lain yang aman, tanpa mengulang MoA terblokir ROT-FALLBACK
 */
export const ROTATION_WINDOW = 2;

export type Jenis = 'mekanis' | 'hayati' | 'nabati' | 'kimia';
export type Tingkat = 'ringan' | 'sedang' | 'berat';

export interface Obat {
  id: string;
  bahan_aktif: string;
  jenis: Jenis;
  /** Kode kelompok MoA. Null untuk cara mekanis dan sebagian agen hayati. */
  kode_moa: string | null;
}

export interface Aplikasi {
  id_obat: string;
  kode_moa: string | null;
  /** YYYY-MM-DD */
  tanggal: string;
  /** Urutan kejadian (id_perawatan). Membedakan aplikasi pada tanggal yang sama. */
  seq?: number;
}

export interface RotationInput {
  tingkat: Tingkat;
  /** Obat yang berlaku untuk hama ini. */
  katalog: readonly Obat[];
  /** Tindakan nyata pada meja ini, urutan bebas. */
  riwayat: readonly Aplikasi[];
  /** Id obat yang baru ditolak di meja mana pun karena tidak tersedia atau harga (R4): ketersediaan dan harga berlaku untuk seluruh kebun. */
  dikecualikan?: readonly string[];
}

export interface RotationResult {
  obat: Obat;
  rule_id: 'ROT-PHT' | 'ROT-MOA' | 'ROT-FALLBACK';
  alasan: string;
  moa_dihindari: string[];
}

/** Urutan PHT: cara paling ringan lebih dulu. */
const tier: Record<Jenis, number> = { mekanis: 0, hayati: 1, nabati: 2, kimia: 3 };

const byNewest = (a: Aplikasi, b: Aplikasi) =>
  b.tanggal.localeCompare(a.tanggal)
  || (b.seq ?? 0) - (a.seq ?? 0)
  || b.id_obat.localeCompare(a.id_obat);

export function recommendRotation(input: RotationInput): RotationResult | null {
  // Jendela dihitung pada aplikasi ber-MoA: memasang perangkap tidak mengurangi tekanan seleksi
  // dari semprotan sebelumnya, jadi tidak boleh "menggeser" MoA terakhir keluar dari jendela.
  const withMoa = [...input.riwayat].filter((a) => a.kode_moa !== null).sort(byNewest);
  const blocked = new Set(withMoa.slice(0, ROTATION_WINDOW).map((a) => a.kode_moa as string));
  const usage = new Map<string, number>();
  for (const a of withMoa) usage.set(a.kode_moa as string, (usage.get(a.kode_moa as string) ?? 0) + 1);

  const excluded = new Set(input.dikecualikan ?? []);
  const notBlocked = input.katalog.filter((o) => o.kode_moa === null || !blocked.has(o.kode_moa));
  const allowed = notBlocked.filter((o) => !excluded.has(o.id));
  const rank = (a: Obat, b: Obat) =>
    tier[a.jenis] - tier[b.jenis]
    || (usage.get(a.kode_moa ?? '') ?? 0) - (usage.get(b.kode_moa ?? '') ?? 0)
    || a.bahan_aktif.localeCompare(b.bahan_aktif)
    || a.id.localeCompare(b.id);
  const best = (list: readonly Obat[]) => [...list].sort(rank)[0];

  const avoided = [...blocked].sort();
  const notes = [
    avoided.length > 0
      ? `Kelompok MoA ${avoided.join(', ')} dihindari karena dipakai pada aplikasi terakhir.`
      : 'Belum ada riwayat MoA pada meja ini.',
    ...(excluded.size > 0 ? ['Obat yang baru ditolak karena tidak tersedia atau harga tidak disarankan lagi.'] : []),
  ].join(' ');
  const pick = (obat: Obat | undefined, rule_id: RotationResult['rule_id'], lead: string) =>
    obat ? { obat, rule_id, alasan: `${lead} ${notes}`, moa_dihindari: avoided } : null;

  const ofJenis = (list: readonly Obat[], ...jenis: Jenis[]) => list.filter((o) => jenis.includes(o.jenis));

  const primary = input.tingkat === 'ringan'
    ? pick(best(ofJenis(allowed, 'mekanis', 'hayati', 'nabati')), 'ROT-PHT', 'Serangan ringan: pilih cara paling ringan dahulu (PHT).')
    : input.tingkat === 'sedang'
      ? pick(best(ofJenis(allowed, 'hayati', 'nabati')), 'ROT-PHT', 'Serangan sedang: utamakan agen hayati atau nabati (PHT).')
        ?? pick(best(ofJenis(allowed, 'kimia')), 'ROT-MOA', 'Serangan sedang tanpa opsi hayati: pilih kelompok MoA yang berbeda.')
      : pick(best(ofJenis(allowed, 'kimia')), 'ROT-MOA', 'Serangan berat: pilih kelompok MoA yang berbeda untuk menekan resistensi.');
  if (primary) return primary;

  // R5: jangan pernah mengulang MoA terblokir. Pakai opsi lolos mana pun, lalu abaikan pengecualian R4.
  const fallback = best(allowed) ?? best(notBlocked);
  return pick(fallback, 'ROT-FALLBACK', 'Tidak ada pilihan utama yang lolos aturan.');
}
