import type { Client, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import type { CreateTableInput, UpdateTableInput, ListTableInput } from './contracts.js';

type Executor = Pick<Client, 'execute'>;
// Aggregate each child separately: joining damage and harvest rows multiplies counts.
const batchActive = `p.jumlah_tanaman
  - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan=p.id_pemindahan),0)
  - COALESCE((SELECT SUM(d.jumlah_tanaman) FROM detail_panen d WHERE d.id_pemindahan=p.id_pemindahan),0)`;
const columns = `CAST(m.id_meja AS TEXT) AS id_meja,m.kode_meja,m.jumlah_lubang,m.status_meja,m.keterangan,
  l.public_id,CAST(v.version AS TEXT) AS version,
  COALESCE((SELECT SUM(${batchActive}) FROM pemindahan p WHERE p.id_meja=m.id_meja),0) AS tanaman_aktif,
  EXISTS(SELECT 1 FROM pemindahan p WHERE p.id_meja=m.id_meja AND (${batchActive})<0) AS invalid_balance`;
const joins = `LEFT JOIN sync_resource_links l ON l.resource_type='meja-tanam' AND l.domain_id=CAST(m.id_meja AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;
function tableRow(row: Row) {
  const capacity = Number(row.jumlah_lubang);
  const active = Number(row.tanaman_aktif);
  if (!Number.isSafeInteger(capacity) || capacity <= 0 || !Number.isSafeInteger(active)
    || active < 0 || active > capacity || Number(row.invalid_balance)) {
    throw new ApiError(409, 'TABLE_BALANCE_INVALID', 'Data kapasitas atau tanaman aktif tidak konsisten.');
  }
  return {
    id_meja: String(row.id_meja), public_id: row.public_id == null ? null : String(row.public_id),
    version: row.version == null ? null : String(row.version), kode_meja: String(row.kode_meja),
    jumlah_lubang: capacity, status_meja: String(row.status_meja),
    keterangan: row.keterangan == null ? null : String(row.keterangan),
    tanaman_aktif: active, kapasitas_tersedia: capacity - active,
  };
}
export async function getTable(db: Executor, id: string) {
  const row = (await db.execute({ sql: `SELECT ${columns} FROM meja_tanam m ${joins} WHERE m.id_meja=?`, args: [id] })).rows[0];
  if (!row) throw new ApiError(404, 'TABLE_NOT_FOUND', 'Meja tanam tidak ditemukan.');
  return tableRow(row);
}
export async function listTables(db: Executor, query: ListTableInput) {
  const filter = query.status_meja ?? null;
  const total = Number((await db.execute({
    sql: 'SELECT COUNT(*) AS total FROM meja_tanam WHERE (? IS NULL OR status_meja=?)', args: [filter, filter],
  })).rows[0].total);
  const rows = (await db.execute({ sql: `SELECT ${columns} FROM meja_tanam m ${joins}
    WHERE (? IS NULL OR m.status_meja=?) ORDER BY m.id_meja LIMIT ? OFFSET ?`,
    args: [filter, filter, query.limit, (query.page - 1) * query.limit] })).rows;
  return { data: rows.map(tableRow), meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) } };
}
export async function assertCodeAvailable(db: Executor, code: string, id: string | null = null) {
  if ((await db.execute({ sql: 'SELECT 1 FROM meja_tanam WHERE kode_meja=? AND (? IS NULL OR id_meja<>?)',
    args: [code, id, id] })).rows.length) {
    throw new ApiError(409, 'TABLE_CODE_CONFLICT', 'Kode meja sudah digunakan.');
  }
}
export async function insertTable(tx: Transaction, input: CreateTableInput) {
  const result = await tx.execute({ sql: `INSERT INTO meja_tanam(kode_meja,jumlah_lubang,status_meja,keterangan)
    VALUES (?,?,?,?) RETURNING CAST(id_meja AS TEXT) AS id_meja`,
    args: [input.kode_meja, input.jumlah_lubang, input.status_meja, input.keterangan] });
  return getTable(tx, String(result.rows[0].id_meja));
}
export async function patchTable(tx: Transaction, id: string, input: UpdateTableInput) {
  const fields = ['kode_meja', 'jumlah_lubang', 'status_meja', 'keterangan'] as const;
  const present = fields.filter((field) => input[field] !== undefined);
  await tx.execute({ sql: `UPDATE meja_tanam SET ${present.map((field) => `${field}=?`).join(',')} WHERE id_meja=?`,
    args: [...present.map((field) => input[field] ?? null), id] });
  return getTable(tx, id);
}
