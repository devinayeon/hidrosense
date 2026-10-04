import type { Client, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { fromMinor } from '../../common/quantities.js';

type Executor = Pick<Client, 'execute'>;

const nullableId = (value: Row[string]) => (value == null ? null : String(value));

const dayMs = 24 * 60 * 60 * 1000;
const jakartaDate = (now: number) => new Date(now + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

function sowingRow(row: Row, today: string) {
  const sowingDate = Date.parse(`${String(row.tanggal_semai)}T00:00:00Z`);
  const age = Number.isFinite(sowingDate) ? (Date.parse(`${today}T00:00:00Z`) - sowingDate) / dayMs : null;
  return {
    id_penyemaian: String(row.id_penyemaian),
    public_id: nullableId(row.public_id),
    version: nullableId(row.version),
    id_user: String(row.id_user),
    tanggal_semai: String(row.tanggal_semai),
    jumlah_benih: Number(row.jumlah_benih),
    status_penyemaian: row.status_penyemaian == null ? null : String(row.status_penyemaian),
    keterangan: row.keterangan == null ? null : String(row.keterangan),
    /** Age in calendar days from tanggal_semai to today (Asia/Jakarta: UTC+7). */
    usia_hari: age,
    siap_pindah: age !== null && age >= 15,
  };
}

function stockLineRow(row: Row) {
  return {
    id_stok: String(row.id_stok),
    id_detail_stok: String(row.id_detail_stok),
    id_inventaris: String(row.id_inventaris),
    jumlah: fromMinor(String(row.jumlah_minor)),
    satuan: String(row.satuan),
  };
}

const linkJoin = `LEFT JOIN sync_resource_links l ON l.resource_type='penyemaian' AND l.domain_id=CAST(p.id_penyemaian AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;

const columns = `
  CAST(p.id_penyemaian AS TEXT) AS id_penyemaian,
  l.public_id,
  CAST(v.version AS TEXT) AS version,
  CAST(p.id_user AS TEXT) AS id_user,
  p.tanggal_semai,
  p.jumlah_benih,
  p.status_penyemaian,
  p.keterangan
`;

export async function getSowing(db: Executor, id: string, now: number) {
  const row = (await db.execute({
    sql: `SELECT ${columns} FROM penyemaian p ${linkJoin} WHERE p.id_penyemaian=?`,
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'PENYEMAIAN_NOT_FOUND', 'Data penyemaian tidak ditemukan.');

  // Fetch consumed stock lines via FK stok.id_penyemaian
  const stockRows = (await db.execute({
    sql: `SELECT CAST(s.id_stok AS TEXT) AS id_stok,
      CAST(d.id_detail_stok AS TEXT) AS id_detail_stok,
      CAST(d.id_inventaris AS TEXT) AS id_inventaris,
      CAST(d.jumlah_minor AS TEXT) AS jumlah_minor, d.satuan
      FROM stok s JOIN detail_stok d ON d.id_stok=s.id_stok
      WHERE s.id_penyemaian=? AND s.sealed=1 ORDER BY d.id_inventaris`,
    args: [id],
  })).rows;

  return { ...sowingRow(row, jakartaDate(now)), stok_konsumsi: stockRows.map(stockLineRow) };
}

export async function listSowings(
  db: Executor,
  query: { page: number; limit: number; status_penyemaian?: string; siap_pindah?: string },
  now: number,
) {
  const today = jakartaDate(now);
  const statusFilter = query.status_penyemaian ?? null;
  const siapFilter = query.siap_pindah === '1' ? 1 : null;
  const args = [statusFilter, statusFilter, siapFilter, today];
  const filter = `
    (? IS NULL OR p.status_penyemaian=?)
    AND (? IS NULL OR julianday(p.tanggal_semai) <= julianday(?) - 15)
  `;
  const count = (await db.execute({
    sql: `SELECT COUNT(*) AS total FROM penyemaian p WHERE ${filter}`,
    args,
  })).rows[0];
  const rows = (await db.execute({
    sql: `SELECT ${columns} FROM penyemaian p ${linkJoin}
      WHERE ${filter}
      ORDER BY p.tanggal_semai DESC, p.id_penyemaian DESC
      LIMIT ? OFFSET ?`,
    args: [...args, query.limit, (query.page - 1) * query.limit],
  })).rows;
  const total = Number(count.total);
  return {
    data: rows.map((r) => sowingRow(r, today)),
    meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) },
  };
}

export async function countMoved(tx: Transaction, id: string): Promise<number> {
  const row = (await tx.execute({
    sql: `SELECT COALESCE(SUM(pm.jumlah_tanaman), 0) AS total
      FROM pemindahan pm WHERE pm.id_penyemaian=?`,
    args: [id],
  })).rows[0];
  return Number(row.total);
}
