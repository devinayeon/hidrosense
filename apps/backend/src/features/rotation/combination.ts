/**
 * Matematika kombinasi untuk rencana rotasi. Dari n keluarga cara kerja yang lolos aturan dipilih
 * k keluarga sekaligus: C(n, k) = n! / (k! (n-k)!). Urutan di dalam satu kombinasi (permutasi)
 * mengikuti peringkat, jadi langkah pertama selalu pilihan terbaik.
 */

/** Semua kombinasi k dari `items`, dalam urutan leksikografis posisi. */
export function kombinasi<T>(items: readonly T[], k: number): T[][] {
  if (k === 0) return [[]];
  const result: T[][] = [];
  for (let i = 0; i <= items.length - k; i += 1) {
    for (const rest of kombinasi(items.slice(i + 1), k - 1)) result.push([items[i], ...rest]);
  }
  return result;
}

/** Subkelompok IRAC kelompok 4 (4A, 4D) diperlakukan satu keluarga. */
export const keluargaMoa = (kode: string) => (/^4[A-Z]$/.test(kode) ? '4' : kode);

/** Keluarga rotasi satu obat. Cara tanpa MoA berdiri sendiri. */
export const keluarga = (obat: { id: string; kode_moa: string | null }) =>
  obat.kode_moa === null ? `id:${obat.id}` : keluargaMoa(obat.kode_moa);

/**
 * Pasangan yang dilaporkan resistensi silang per hama. Kutu kebul: 9B dengan kelompok 4
 * (UF/IFAS ENY989, https://ask.ifas.ufl.edu/publication/IN1171).
 */
const SILANG: Record<string, readonly (readonly [string, string])[]> = {
  whitefly: [['4', '9B']],
};

export function silangDengan(hama: string | undefined, kel: string): string[] {
  return (SILANG[hama ?? ''] ?? []).flatMap(([a, b]) => (a === kel ? [b] : b === kel ? [a] : []));
}

export interface RencanaKombinasi<T> {
  /** Banyaknya kombinasi sah berukuran sama dengan rencana terpilih. */
  jumlah_kombinasi: number;
  pilihan: T[];
}

/**
 * `peringkat` sudah terurut dari terbaik dan berisi satu wakil per keluarga. Rencana wajib memuat
 * wakil pertama; di antara kombinasi sah dipilih yang peringkatnya paling awal. Bila ukuran `maks`
 * tidak bisa dipenuhi tanpa pasangan resistensi silang, ukurannya diturunkan.
 */
export function susunRencana<T extends { id: string; kode_moa: string | null }>(
  peringkat: readonly T[],
  hama: string | undefined,
  maks: number,
): RencanaKombinasi<T> {
  const sah = (set: readonly T[]) => {
    const kel = new Set(set.map(keluarga));
    return set.every((o) => silangDengan(hama, keluarga(o)).every((k) => !kel.has(k)));
  };
  for (let k = Math.min(maks, peringkat.length); k > 0; k -= 1) {
    const semua = kombinasi(peringkat, k).filter(sah);
    const pilihan = semua.find((set) => set[0] === peringkat[0]);
    if (pilihan) return { jumlah_kombinasi: semua.length, pilihan };
  }
  return { jumlah_kombinasi: 0, pilihan: [] };
}
