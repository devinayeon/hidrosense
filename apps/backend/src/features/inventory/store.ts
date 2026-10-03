import type { Row } from '@libsql/client';
import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { fromMinor } from '../../common/quantities.js';

type Executor = Pick<Client, 'execute'>;

export function syncColumns(resourceType: string, idColumn: string) {
  return `(SELECT l.public_id FROM sync_resource_links l WHERE l.resource_type='${resourceType}'
    AND l.domain_id=CAST(${idColumn} AS TEXT)) AS public_id,
    (SELECT CAST(v.version AS TEXT) FROM sync_resource_links l JOIN sync_resource_versions v
    ON v.resource_type=l.resource_type AND v.public_id=l.public_id
    WHERE l.resource_type='${resourceType}' AND l.domain_id=CAST(${idColumn} AS TEXT)) AS version`;
}

function syncResponse(row: Row) {
  return { public_id: row.public_id == null ? null : String(row.public_id),
    version: row.version == null ? null : String(row.version) };
}

export function jenisResponse(row: Row) {
  return {
    ...syncResponse(row),
    id_jenis_inventaris: String(row.id_jenis_inventaris),
    nama_jenis: String(row.nama_jenis),
    status_aktif: Number(row.status_aktif),
  };
}

export async function getJenis(db: Executor, id: string) {
  const row = (await db.execute({
    sql: `SELECT CAST(id_jenis_inventaris AS TEXT) AS id_jenis_inventaris,nama_jenis,status_aktif,${syncColumns('jenis-inventaris', 'jenis_inventaris.id_jenis_inventaris')} FROM jenis_inventaris WHERE id_jenis_inventaris=?`,
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

export function obatResponse(row: Row) {
  return {
    ...syncResponse(row),
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
    sql: `SELECT CAST(id_obat AS TEXT) AS id_obat,nama_obat,jenis_obat,dosis,aturan_penggunaan,deskripsi,status_aktif,${syncColumns('obat', 'obat.id_obat')} FROM obat WHERE id_obat=?`,
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'OBAT_NOT_FOUND', 'Obat tidak ditemukan.');
  return obatResponse(row);
}

const inventarisColumns = `CAST(i.id_inventaris AS TEXT) AS id_inventaris,
  CAST(i.id_jenis_inventaris AS TEXT) AS id_jenis_inventaris,CAST(i.id_obat AS TEXT) AS id_obat,
  i.nama_barang,i.satuan,CAST(i.stok_minimum_minor AS TEXT) AS stok_minimum,i.status_aktif,
  j.nama_jenis,o.nama_obat,${syncColumns('inventaris', 'i.id_inventaris')}`;

export function inventarisResponse(row: Row) {
  return {
    ...syncResponse(row),
    id_inventaris: String(row.id_inventaris),
    id_jenis_inventaris: String(row.id_jenis_inventaris),
    id_obat: row.id_obat === null ? null : String(row.id_obat),
    nama_barang: String(row.nama_barang),
    satuan: String(row.satuan),
    stok_minimum: row.stok_minimum === null ? null : fromMinor(String(row.stok_minimum)),
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
    sql: 'SELECT 1 FROM jenis_inventaris WHERE id_jenis_inventaris=? AND status_aktif=1', args: [id],
  })).rows[0];
  if (!row) throw new ApiError(422, 'JENIS_NOT_FOUND', 'Jenis inventaris tidak ditemukan atau tidak aktif.');
}

export async function assertObatExists(db: Executor, id: string) {
  const row = (await db.execute({
    sql: 'SELECT 1 FROM obat WHERE id_obat=? AND status_aktif=1', args: [id],
  })).rows[0];
  if (!row) throw new ApiError(422, 'OBAT_NOT_FOUND', 'Obat tidak ditemukan atau tidak aktif.');
}

export { inventarisColumns };
