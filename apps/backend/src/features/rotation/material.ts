import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { keluarga } from './combination.js';

type Executor = Pick<Client, 'execute'>;

/** Formulasi pestisida yang lazim ditulis di belakang nama merek (EC, SL, WP, ...). */
const FORMULASI = new Set([
  'AS', 'CB', 'CS', 'D', 'DP', 'EC', 'EO', 'EW', 'F', 'G', 'GR', 'L', 'ME', 'OD', 'P', 'RB', 'SC',
  'SE', 'SG', 'SL', 'SP', 'WDG', 'WG', 'WP', 'WS', 'WSC', 'ZC',
]);

/** Sama persis dengan `kunci` di docs/data/registri/susun_merek.py. */
export const kunciMerek = (nama: string) =>
  nama.toUpperCase().replace(/[^A-Z0-9/.,%]+/g, ' ').split(' ').filter(Boolean).join(' ');

/** Sama persis dengan `dasar` di docs/data/registri/susun_merek.py: tanpa konsentrasi/formulasi. */
export function kunciDasar(key: string) {
  const tokens = key.split(' ');
  while (tokens.length > 1 && (FORMULASI.has(tokens.at(-1) as string) || /^[\d/.,%]+$/.test(tokens.at(-1) as string))) {
    tokens.pop();
  }
  return tokens.join(' ');
}

interface Bahan {
  nama: string;
  id_katalog: string | null;
  kode_moa: string | null;
}

const text = (v: unknown) => (v == null ? null : String(v));

/** Bahan aktif sebuah barang menurut merek terdaftar; null bila tidak dikenali atau ambigu. */
async function bahanMerek(db: Executor, nama: string): Promise<Bahan[] | null> {
  const key = kunciMerek(nama);
  for (const [column, value] of [['kunci', key], ['kunci_dasar', kunciDasar(key)]] as const) {
    const rows = (await db.execute({
      sql: `SELECT m.id_merek, b.nama_bahan, CAST(b.id_katalog AS TEXT) AS id_katalog, k.kode_moa
        FROM merek_obat m JOIN merek_bahan b ON b.id_merek = m.id_merek
        LEFT JOIN obat_katalog k ON k.id_katalog = b.id_katalog
        WHERE m.${column} = ? ORDER BY m.id_merek, b.nama_bahan`,
      args: [value],
    })).rows;
    if (rows.length === 0) continue;
    const perMerek = new Map<string, Bahan[]>();
    for (const r of rows) {
      const list = perMerek.get(String(r.id_merek)) ?? [];
      list.push({ nama: String(r.nama_bahan), id_katalog: text(r.id_katalog), kode_moa: text(r.kode_moa) });
      perMerek.set(String(r.id_merek), list);
    }
    // Merek senama dengan isi berbeda tidak bisa dipastikan: lebih baik tidak menebak.
    const tanda = new Set([...perMerek.values()].map((list) => list.map((b) => b.id_katalog ?? `?${b.nama}`).sort().join('|')));
    return tanda.size === 1 ? [...perMerek.values()][0] : null;
  }
  return null;
}

async function bahanBarang(db: Executor, idInventaris: string) {
  const row = (await db.execute({
    sql: `SELECT i.nama_barang, CAST(i.id_katalog AS TEXT) AS id_katalog, k.bahan_aktif, k.kode_moa
      FROM inventaris i LEFT JOIN obat_katalog k ON k.id_katalog = i.id_katalog WHERE i.id_inventaris = ?`,
    args: [idInventaris],
  })).rows[0];
  if (!row) return null;
  const nama = String(row.nama_barang);
  if (row.id_katalog != null) {
    return { nama, bahan: [{ nama: String(row.bahan_aktif), id_katalog: String(row.id_katalog), kode_moa: text(row.kode_moa) }] };
  }
  const bahan = (await bahanMerek(db, nama)) ?? (await bahanDariNama(db, nama));
  return bahan ? { nama, bahan } : null;
}

/**
 * Barang yang dinamai dengan bahan aktifnya (mis. "Insektisida Abamectin"). Ejaan diambil dari
 * katalog dan dari registri (merek_bahan), hanya bahan yang tertaut katalog dan cukup panjang
 * supaya kata umum tidak ikut cocok.
 */
async function bahanDariNama(db: Executor, nama: string): Promise<Bahan[] | null> {
  const rows = (await db.execute({
    sql: `SELECT DISTINCT CAST(k.id_katalog AS TEXT) AS id_katalog, k.kode_moa, e.ejaan
      FROM (SELECT lower(bahan_aktif) AS ejaan, id_katalog FROM obat_katalog
            UNION SELECT nama_bahan, id_katalog FROM merek_bahan WHERE id_katalog IS NOT NULL) e
      JOIN obat_katalog k ON k.id_katalog = e.id_katalog
      WHERE length(e.ejaan) >= 6 AND instr(' ' || lower(?) || ' ', e.ejaan) > 0`,
    args: [nama],
  })).rows;
  if (rows.length === 0) return null;
  const perKatalog = new Map<string, Bahan>();
  for (const r of rows) {
    perKatalog.set(String(r.id_katalog), { nama: String(r.ejaan), id_katalog: String(r.id_katalog), kode_moa: text(r.kode_moa) });
  }
  return [...perKatalog.values()];
}

/**
 * Bahan stok yang dipotong harus obat yang disarankan atau satu cara kerja dengannya. Bila tidak,
 * riwayat rotasi akan mencatat MoA yang tidak pernah disemprot. Barang yang tidak dikenali
 * (nutrisi, obat tanpa tautan katalog dan bukan merek terdaftar) tetap boleh.
 */
export async function assertMaterialsMatch(
  db: Executor,
  obat: { id_katalog: string; bahan_aktif: string; kode_moa: string | null },
  lines: readonly { id_inventaris: string }[],
) {
  const target = keluarga({ id: obat.id_katalog, kode_moa: obat.kode_moa });
  for (const line of lines) {
    const info = await bahanBarang(db, line.id_inventaris);
    if (!info) continue;
    const lain = info.bahan.filter((b) => b.id_katalog === null || keluarga({ id: b.id_katalog, kode_moa: b.kode_moa }) !== target);
    if (lain.length === 0) continue;
    const isi = lain.map((b) => (b.kode_moa ? `${b.nama} (MoA ${b.kode_moa})` : b.nama)).join(', ');
    const saran = obat.kode_moa ? `${obat.bahan_aktif}, MoA ${obat.kode_moa}` : obat.bahan_aktif;
    throw new ApiError(422, 'MATERIAL_MISMATCH',
      `${info.nama} berisi ${isi}, bukan obat yang disarankan (${saran}). Pilih bahan yang sesuai atau tolak saran ini.`);
  }
}
