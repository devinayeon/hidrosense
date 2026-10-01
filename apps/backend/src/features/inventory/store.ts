import type { Row } from '@libsql/client';
import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';

type Executor = Pick<Client, 'execute'>;

// ── jenis_inventaris ──────────────────────────────────────────────────────────

export function jenisResponse(row: Row) {
  return {
    id_jenis_inventaris: String(row.id_jenis_inventaris),
    nama_jenis: String(row.nama_jenis),
  };
}

export async function getJenis(db: Executor, id: string) {
  const row = (await db.execute({
    sql: 'SELECT id_jenis_inventaris,nama_jenis FROM jenis_inventaris WHERE id_jenis_inventaris=?',
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'JENIS_NOT_FOUND', 'Jenis inventaris tidak ditemukan.');
  return jenisResponse(row);
}

export async function assertJenisNameAvailable(db: Executor, nama_jenis: string, exceptId?: string) {
  const result = await db.execute({
    sql: 'SELECT 1 FROM jenis_inventaris WHERE nama_jenis=? AND (? IS NULL OR id_jenis_inventaris<>?)',
    args: [nama_jenis, exceptId ?? null, exceptId ?? null],
  });
  if (result.rows.length) throw new ApiError(409, 'JENIS_NAME_TAKEN', 'Nama jenis inventaris sudah digunakan.');
}

// ── obat ──────────────────────────────────────────────────────────────────────

export function obatResponse(row: Row) {
  return {
    id_obat: String(row.id_obat),
    nama_obat: String(row.nama_obat),
    jenis_obat: row.jenis_obat === null ? null : String(row.jenis_obat),
    dosis: row.dosis === null ? null : String(row.dosis),
    aturan_penggunaan: row.aturan_penggunaan === null ? null : String(row.aturan_penggunaan),
    deskripsi: row.deskripsi === null ? null : String(row.deskripsi),
    status_aktif: Number(row.status_aktif),
  };
}

export async function getObat(db: Executor, id: string) {
  const row = (await db.execute({
    sql: 'SELECT id_obat,nama_obat,jenis_obat,dosis,aturan_penggunaan,deskripsi,status_aktif FROM obat WHERE id_obat=?',
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'OBAT_NOT_FOUND', 'Obat tidak ditemukan.');
  return obatResponse(row);
}

// ── inventaris ────────────────────────────────────────────────────────────────

const inventarisColumns = `i.id_inventaris,i.id_jenis_inventaris,i.id_obat,
  i.nama_barang,i.satuan,i.stok_minimum,i.status_aktif,
  j.nama_jenis,o.nama_obat`;

export function inventarisResponse(row: Row) {
  return {
    id_inventaris: String(row.id_inventaris),
    id_jenis_inventaris: String(row.id_jenis_inventaris),
    id_obat: row.id_obat === null ? null : String(row.id_obat),
    nama_barang: String(row.nama_barang),
    satuan: String(row.satuan),
    stok_minimum: row.stok_minimum === null ? null : Number(row.stok_minimum),
    status_aktif: Number(row.status_aktif),
    nama_jenis: String(row.nama_jenis),
    nama_obat: row.nama_obat === null ? null : String(row.nama_obat),
  };
}

export async function getInventaris(db: Executor, id: string) {
  const row = (await db.execute({
    sql: `SELECT ${inventarisColumns} FROM inventaris i
      JOIN jenis_inventaris j ON j.id_jenis_inventaris=i.id_jenis_inventaris
      LEFT JOIN obat o ON o.id_obat=i.id_obat
      WHERE i.id_inventaris=?`,
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'INVENTARIS_NOT_FOUND', 'Barang inventaris tidak ditemukan.');
  return inventarisResponse(row);
}

export async function assertJenisExists(db: Executor, id: string) {
  const row = (await db.execute({
    sql: 'SELECT 1 FROM jenis_inventaris WHERE id_jenis_inventaris=?', args: [id],
  })).rows[0];
  if (!row) throw new ApiError(422, 'JENIS_NOT_FOUND', 'Jenis inventaris tidak ditemukan.');
}

export async function assertObatExists(db: Executor, id: string) {
  const row = (await db.execute({
    sql: 'SELECT 1 FROM obat WHERE id_obat=? AND status_aktif=1', args: [id],
  })).rows[0];
  if (!row) throw new ApiError(422, 'OBAT_NOT_FOUND', 'Obat tidak ditemukan atau tidak aktif.');
}

export { inventarisColumns };
