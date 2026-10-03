import type { Client, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { fromMinor, toMinor } from '../../common/quantities.js';
import type { StockLine } from './contracts.js';

type Executor = Pick<Client, 'execute'>;
const nullableId = (value: Row[string]) => value == null ? null : String(value);
const headerColumns = `CAST(s.id_stok AS TEXT) AS id_stok,CAST(s.id_user AS TEXT) AS id_user,
  CAST(s.id_penyemaian AS TEXT) AS id_penyemaian,CAST(s.id_perawatan AS TEXT) AS id_perawatan,
  CAST(s.reversal_of AS TEXT) AS reversal_of,s.tanggal_stok,s.jenis_stok,s.keterangan,l.public_id,
  CAST(v.version AS TEXT) AS version`;
const headerJoins = `LEFT JOIN sync_resource_links l ON l.resource_type='stok' AND l.domain_id=CAST(s.id_stok AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;

function detailResponse(row: Row) {
  return { id_detail_stok: String(row.id_detail_stok), id_inventaris: String(row.id_inventaris),
    jumlah: fromMinor(String(row.jumlah_minor)), satuan: String(row.satuan) };
}

function movementResponse(row: Row, details: ReturnType<typeof detailResponse>[]) {
  const storedTime = String(row.tanggal_stok);
  return {
    id_stok: String(row.id_stok), public_id: nullableId(row.public_id), version: nullableId(row.version),
    id_user: String(row.id_user), id_penyemaian: nullableId(row.id_penyemaian),
    id_perawatan: nullableId(row.id_perawatan),
    tanggal_stok: storedTime.includes('T') ? storedTime : `${storedTime.replace(' ', 'T')}.000Z`,
    jenis_stok: String(row.jenis_stok) as 'masuk' | 'keluar',
    keterangan: row.keterangan == null ? null : String(row.keterangan),
    reversal_of: nullableId(row.reversal_of), details,
  };
}

async function readDetails(db: Executor, ids: string[]) {
  if (!ids.length) return [];
  return (await db.execute({ sql: `SELECT CAST(id_stok AS TEXT) AS id_stok,
    CAST(id_detail_stok AS TEXT) AS id_detail_stok,CAST(id_inventaris AS TEXT) AS id_inventaris,
    CAST(jumlah_minor AS TEXT) AS jumlah_minor,satuan FROM detail_stok d
    WHERE d.id_stok IN (${ids.map(() => '?').join(',')}) ORDER BY d.id_stok,d.id_inventaris`, args: ids })).rows;
}

export async function getMovement(db: Executor, id: string) {
  const row = (await db.execute({ sql: `SELECT ${headerColumns} FROM stok s ${headerJoins}
    WHERE s.id_stok=? AND s.sealed=1`, args: [id] })).rows[0];
  if (!row) throw new ApiError(404, 'STOK_NOT_FOUND', 'Transaksi stok tidak ditemukan.');
  return movementResponse(row, (await readDetails(db, [id])).map(detailResponse));
}

export async function listMovements(db: Executor,
  query: { page: number; limit: number; id_inventaris?: string; jenis_stok?: string }) {
  const args = [query.jenis_stok ?? null, query.jenis_stok ?? null,
    query.id_inventaris ?? null, query.id_inventaris ?? null];
  const filter = `s.sealed=1 AND (? IS NULL OR s.jenis_stok=?) AND (? IS NULL OR EXISTS
    (SELECT 1 FROM detail_stok d WHERE d.id_stok=s.id_stok AND d.id_inventaris=?))`;
  const count = await db.execute({ sql: `SELECT COUNT(*) AS total FROM stok s WHERE ${filter}`, args });
  const headers = (await db.execute({ sql: `SELECT ${headerColumns} FROM stok s ${headerJoins}
    WHERE ${filter} ORDER BY s.id_stok LIMIT ? OFFSET ?`,
    args: [...args, query.limit, (query.page - 1) * query.limit] })).rows;
  const lines = await readDetails(db, headers.map((row) => String(row.id_stok)));
  const total = Number(count.rows[0].total);
  return { data: headers.map((row) => movementResponse(row,
    lines.filter((line) => String(line.id_stok) === String(row.id_stok)).map(detailResponse))),
  meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) } };
}

export async function getBalance(db: Executor, id: string) {
  const row = (await db.execute({ sql: `SELECT i.satuan,
    CAST(COALESCE(b.saldo_minor,0) AS TEXT) AS saldo_minor,CAST(i.stok_minimum_minor AS TEXT) AS minimum
    FROM inventaris i LEFT JOIN stok_saldo b ON b.id_inventaris=i.id_inventaris WHERE i.id_inventaris=?`,
    args: [id] })).rows[0];
  if (!row) throw new ApiError(404, 'INVENTARIS_NOT_FOUND', 'Barang inventaris tidak ditemukan.');
  return { id_inventaris: id, satuan: String(row.satuan), saldo: fromMinor(String(row.saldo_minor)),
    stok_minimum: row.minimum == null ? null : fromMinor(String(row.minimum)),
    di_bawah_minimum: row.minimum != null && BigInt(String(row.saldo_minor)) < BigInt(String(row.minimum)) };
}

async function assertItemsAvailable(tx: Transaction, details: StockLine[], reversal: boolean) {
  const rows = (await tx.execute({ sql: `SELECT CAST(id_inventaris AS TEXT) AS id_inventaris,satuan,status_aktif
    FROM inventaris WHERE id_inventaris IN (${details.map(() => '?').join(',')})`,
    args: details.map((line) => line.id_inventaris) })).rows;
  for (const line of details) {
    const row = rows.find((item) => item.id_inventaris === line.id_inventaris);
    if (!row || (!reversal && Number(row.status_aktif) !== 1)) {
      throw new ApiError(422, 'INVENTARIS_NOT_AVAILABLE', 'Barang stok tidak ditemukan atau tidak aktif.');
    }
    if (row.satuan !== line.satuan) throw new ApiError(422, 'UNIT_MISMATCH', 'Satuan tidak sesuai barang inventaris.');
  }
}

async function isReversed(tx: Transaction, id: string) {
  return (await tx.execute({ sql: 'SELECT 1 FROM stok WHERE reversal_of=?', args: [id] })).rows.length > 0;
}

type Origin = { id_penyemaian: string; id_perawatan?: never } | { id_perawatan: string; id_penyemaian?: never };
export type StockOrigin = Origin;

export async function appendMovement(tx: Transaction, actorId: string, now: number,
  input: { jenis_stok: 'masuk' | 'keluar'; details: StockLine[]; keterangan: string | null },
  reversalOf: string | null = null, origin?: Origin) {
  // Keep persistence prerequisites inside append, before any ledger or balance write.
  if (reversalOf !== null && await isReversed(tx, reversalOf)) {
    throw new ApiError(409, 'STOK_ALREADY_REVERSED', 'Transaksi sudah dibalik.');
  }
  await assertItemsAvailable(tx, input.details, reversalOf !== null);
  const header = await tx.execute({ sql: `INSERT INTO stok
    (id_user,id_penyemaian,id_perawatan,tanggal_stok,jenis_stok,keterangan,reversal_of,sealed)
    VALUES (?,?,?,?,?,?,?,0) RETURNING CAST(id_stok AS TEXT) AS id_stok`,
    args: [actorId, origin?.id_penyemaian ?? null, origin?.id_perawatan ?? null,
      new Date(now).toISOString(), input.jenis_stok, input.keterangan, reversalOf] });
  const id = String(header.rows[0].id_stok);
  for (const line of input.details) {
    const minor = toMinor(line.jumlah);
    const delta = input.jenis_stok === 'masuk' ? minor : -minor;
    await tx.execute({ sql: 'INSERT INTO stok_saldo(id_inventaris,saldo_minor) VALUES (?,0) ON CONFLICT DO NOTHING',
      args: [line.id_inventaris] });
    const update = await tx.execute({ sql: `UPDATE stok_saldo SET saldo_minor=saldo_minor+CAST(? AS INTEGER)
      WHERE id_inventaris=? AND saldo_minor+CAST(? AS INTEGER) BETWEEN 0 AND 999999999999`,
      args: [delta, line.id_inventaris, delta] });
    if (update.rowsAffected !== 1) {
      throw new ApiError(409, delta < 0n ? 'INSUFFICIENT_STOCK' : 'STOCK_LIMIT_EXCEEDED',
        delta < 0n ? 'Saldo stok tidak mencukupi.' : 'Saldo stok melebihi batas.');
    }
    await tx.execute({ sql: `INSERT INTO detail_stok(id_stok,id_inventaris,jumlah,jumlah_minor,satuan)
      VALUES (?,?,?,?,?)`, args: [id, line.id_inventaris, line.jumlah, minor, line.satuan] });
  }
  await tx.execute({ sql: 'UPDATE stok SET sealed=1 WHERE id_stok=?', args: [id] });
  return getMovement(tx, id);
}
