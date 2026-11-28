import type { Client, Row } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { GROWTH_DAYS_ON_TABLE } from '../../common/growth-rules.js';
import { fromMinor } from '../../common/quantities.js';
import { batchActive } from '../transfers/store.js';
import type { Aplikasi, Jenis, Obat, RotationResult } from './engine.js';
import type { ListRecommendationQuery } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const columns = `
  CAST(r.id_rekomendasi AS TEXT) AS id_rekomendasi,
  CAST(r.id_meja AS TEXT) AS id_meja,
  m.kode_meja,
  CAST(r.id_hasil_deteksi AS TEXT) AS id_hasil_deteksi,
  r.kode_hama AS hama, r.tingkat, r.tingkat_model,
  CAST(r.id_katalog AS TEXT) AS id_katalog,
  k.bahan_aktif, k.jenis, k.sumber, k.catatan AS catatan_obat, k.phi_hari, k.phi_sumber, k.terverifikasi,
  r.kode_moa, g.nama AS nama_moa,
  k.status_registrasi, k.catatan_registrasi,
  (SELECT group_concat(lower(h2.nama), ' dan ') FROM rekomendasi_perawatan r2 JOIN hama h2 ON h2.kode_hama = r2.kode_hama
    WHERE r.id_hasil_deteksi IS NOT NULL AND r2.id_hasil_deteksi = r.id_hasil_deteksi AND r2.id_katalog = r.id_katalog
      AND r2.id_rekomendasi <> r.id_rekomendasi AND r2.status_rekomendasi <> 'ditolak') AS hama_bersama,
  (SELECT lower(nama) FROM hama WHERE kode_hama = r.kode_hama) AS hama_nama,
  r.rule_id, r.alasan, r.rencana, r.status_rekomendasi AS status, r.alasan_diisi,
  r.alasan_penolakan, r.catatan_penolakan,
  r.tanggal_rekomendasi, r.tanggal_keputusan,
  p.tanggal_perawatan AS tanggal_aplikasi, p.catatan AS catatan_perawatan,
  CAST(p.id_perawatan AS TEXT) AS id_perawatan
`;
const from = `rekomendasi_perawatan r
  JOIN meja_tanam m ON m.id_meja = r.id_meja
  JOIN obat_katalog k ON k.id_katalog = r.id_katalog
  LEFT JOIN moa_groups g ON g.kode_moa = r.kode_moa
  LEFT JOIN perawatan p ON p.id_rekomendasi = r.id_rekomendasi`;

const text = (v: unknown) => (v == null ? null : String(v));

export type MaterialUsed = {
  id_inventaris: string;
  nama_barang: string;
  jumlah: string;
  satuan: string;
};

/** Bahan stok per perawatan, satu kueri untuk semua perawatan di halaman ini. */
async function loadMaterials(db: Executor, careIds: string[]) {
  const byCare = new Map<string, MaterialUsed[]>();
  if (careIds.length === 0) return byCare;
  const rows = (await db.execute({
    sql: `SELECT CAST(s.id_perawatan AS TEXT) AS id_perawatan, CAST(d.id_inventaris AS TEXT) AS id_inventaris,
        i.nama_barang, CAST(d.jumlah_minor AS TEXT) AS jumlah_minor, d.satuan
      FROM stok s JOIN detail_stok d ON d.id_stok = s.id_stok JOIN inventaris i ON i.id_inventaris = d.id_inventaris
      WHERE s.id_perawatan IN (${careIds.map(() => '?').join(',')}) AND s.sealed = 1
      ORDER BY s.id_perawatan, d.id_detail_stok`,
    args: careIds,
  })).rows;
  for (const r of rows) {
    const list = byCare.get(String(r.id_perawatan)) ?? [];
    list.push({
      id_inventaris: String(r.id_inventaris),
      nama_barang: String(r.nama_barang),
      jumlah: fromMinor(String(r.jumlah_minor)),
      satuan: String(r.satuan),
    });
    byCare.set(String(r.id_perawatan), list);
  }
  return byCare;
}

async function withMaterials(db: Executor, rows: Row[]) {
  const careIds = rows.map((r) => r.id_perawatan).filter((v) => v != null).map(String);
  const materials = await loadMaterials(db, careIds);
  return rows.map((row) => ({
    ...recommendationRow(row),
    bahan_terpakai: row.id_perawatan == null ? [] : materials.get(String(row.id_perawatan)) ?? [],
  }));
}

function recommendationRow(row: Row) {
  return {
    id_rekomendasi: String(row.id_rekomendasi),
    id_meja: String(row.id_meja),
    kode_meja: String(row.kode_meja),
    id_hasil_deteksi: text(row.id_hasil_deteksi),
    hama: String(row.hama),
    tingkat: String(row.tingkat),
    tingkat_model: text(row.tingkat_model),
    status: String(row.status),
    obat: {
      id_katalog: String(row.id_katalog),
      bahan_aktif: String(row.bahan_aktif),
      jenis: String(row.jenis),
      kode_moa: text(row.kode_moa),
      nama_moa: text(row.nama_moa),
      catatan: text(row.catatan_obat),
      phi_hari: row.phi_hari == null ? null : Number(row.phi_hari),
      phi_sumber: text(row.phi_sumber),
      sumber: String(row.sumber),
      terverifikasi: Number(row.terverifikasi) === 1,
      status_registrasi: String(row.status_registrasi),
      catatan_registrasi: text(row.catatan_registrasi),
    },
    rencana: row.rencana == null ? null : JSON.parse(String(row.rencana)) as RotationResult['rencana'],
    rule_id: String(row.rule_id),
    alasan: row.hama_bersama == null
      ? String(row.alasan)
      : `${row.alasan} Satu semprotan untuk ${row.hama_nama} dan ${row.hama_bersama} pada foto ini.`,
    alasan_penolakan: Number(row.alasan_diisi) === 1 ? text(row.alasan_penolakan) : null,
    catatan_penolakan: Number(row.alasan_diisi) === 1 ? text(row.catatan_penolakan) : null,
    tanggal_aplikasi: text(row.tanggal_aplikasi),
    catatan_perawatan: text(row.catatan_perawatan),
    tanggal_rekomendasi: String(row.tanggal_rekomendasi),
    tanggal_keputusan: text(row.tanggal_keputusan),
  };
}

export type RecommendationRow = ReturnType<typeof recommendationRow> & { bahan_terpakai: MaterialUsed[] };

export async function getRecommendation(db: Executor, id: string): Promise<RecommendationRow> {
  const row = (await db.execute({ sql: `SELECT ${columns} FROM ${from} WHERE r.id_rekomendasi = ?`, args: [id] })).rows[0];
  if (!row) throw new ApiError(404, 'RECOMMENDATION_NOT_FOUND', 'Rekomendasi obat tidak ditemukan.');
  return (await withMaterials(db, [row]))[0];
}

export async function listRecommendations(db: Executor, query: ListRecommendationQuery) {
  const where = `(? IS NULL OR r.status_rekomendasi = ?) AND (? IS NULL OR r.id_meja = ?) AND (? IS NULL OR r.kode_hama = ?)`;
  const args = [
    query.status ?? null, query.status ?? null,
    query.id_meja ?? null, query.id_meja ?? null,
    query.hama ?? null, query.hama ?? null,
  ];
  const total = Number((await db.execute({ sql: `SELECT COUNT(*) AS total FROM ${from} WHERE ${where}`, args })).rows[0].total);
  const rows = (await db.execute({
    sql: `SELECT ${columns} FROM ${from} WHERE ${where}
      ORDER BY r.tanggal_rekomendasi DESC, r.id_rekomendasi DESC LIMIT ? OFFSET ?`,
    args: [...args, query.limit, (query.page - 1) * query.limit],
  })).rows;
  return {
    data: await withMaterials(db, rows),
    meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) },
  };
}

/** Obat yang boleh disarankan untuk satu hama, dalam bentuk yang dimengerti mesin rotasi. */
export async function loadCatalog(db: Executor, hama: string): Promise<Obat[]> {
  const rows = (await db.execute({
    sql: `SELECT CAST(k.id_katalog AS TEXT) AS id, k.bahan_aktif, k.jenis, k.kode_moa, k.phi_hari
      FROM obat_katalog k JOIN katalog_hama h ON h.id_katalog = k.id_katalog
      WHERE h.kode_hama = ? AND k.boleh_direkomendasikan = 1`,
    args: [hama],
  })).rows;
  return rows.map((r) => ({
    id: String(r.id),
    bahan_aktif: String(r.bahan_aktif),
    jenis: String(r.jenis) as Jenis,
    kode_moa: text(r.kode_moa),
    phi_hari: r.phi_hari == null ? null : Number(r.phi_hari),
  }));
}

/**
 * Sisa hari menuju panen paling awal di meja (batch tertua yang masih punya tanaman aktif).
 * Lewat jadwal dihitung 0. Null bila meja kosong.
 */
export async function daysToHarvest(db: Executor, idMeja: string, today: string): Promise<number | null> {
  const row = (await db.execute({
    sql: `SELECT MIN(p.tanggal_pemindahan) AS pindah FROM pemindahan p
      WHERE p.id_meja = ? AND (${batchActive}) > 0`,
    args: [idMeja],
  })).rows[0];
  if (row?.pindah == null) return null;
  const sejakPindah = (Date.parse(`${today}T00:00:00Z`) - Date.parse(`${row.pindah}T00:00:00Z`)) / 86_400_000;
  return Math.max(0, GROWTH_DAYS_ON_TABLE - sejakPindah);
}

/**
 * Tindakan nyata (perawatan) pada meja ini. Semua hama dihitung: satu semprotan mengenai semuanya.
 * Saran untuk beberapa hama dari foto yang sama dengan obat yang sama adalah satu semprotan,
 * jadi dihitung sekali (tanggal paling awal).
 */
export async function loadHistory(db: Executor, idMeja: string): Promise<Aplikasi[]> {
  const rows = (await db.execute({
    sql: `SELECT CAST(r.id_katalog AS TEXT) AS id_obat, MIN(r.kode_moa) AS kode_moa, MIN(p.tanggal_perawatan) AS tanggal
      FROM perawatan p JOIN rekomendasi_perawatan r ON r.id_rekomendasi = p.id_rekomendasi
      WHERE r.id_meja = ?
      GROUP BY CASE WHEN r.id_hasil_deteksi IS NULL THEN 'p' || p.id_perawatan
        ELSE 'f' || r.id_hasil_deteksi || '-' || r.id_katalog END`,
    args: [idMeja],
  })).rows;
  return rows.map((r) => ({
    id_obat: String(r.id_obat),
    kode_moa: text(r.kode_moa),
    tanggal: String(r.tanggal),
  }));
}

export async function findPending(db: Executor, idMeja: string, hama: string): Promise<string | null> {
  const row = (await db.execute({
    sql: `SELECT CAST(id_rekomendasi AS TEXT) AS id FROM rekomendasi_perawatan
      WHERE id_meja = ? AND kode_hama = ? AND status_rekomendasi = 'menunggu'`,
    args: [idMeja, hama],
  })).rows[0];
  return row ? String(row.id) : null;
}

/**
 * Obat yang ditolak karena tidak tersedia atau harga sejak [sinceIso], di meja mana pun:
 * ketersediaan dan harga berlaku untuk seluruh kebun, bukan per meja.
 */
export async function loadUnavailableRejections(db: Executor, sinceIso: string): Promise<string[]> {
  const rows = (await db.execute({
    sql: `SELECT DISTINCT CAST(id_katalog AS TEXT) AS id FROM rekomendasi_perawatan
      WHERE status_rekomendasi = 'ditolak' AND alasan_penolakan IN ('tidak_tersedia', 'harga')
        AND tanggal_keputusan >= ?`,
    args: [sinceIso],
  })).rows;
  return rows.map((r) => String(r.id));
}
