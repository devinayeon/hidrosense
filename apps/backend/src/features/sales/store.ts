import type { Client, Row } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { formatWeight, parseWeight } from '../../db/harvest-weights.js';
import { formatMoney, parseMoney, saleLineTotal } from '../../db/sales-amounts.js';
import type { ListSalesQuery } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const headerColumns = `
  CAST(s.id_penjualan AS TEXT) AS id_penjualan,
  CAST(s.id_user AS TEXT) AS id_user,
  s.tanggal_penjualan,
  s.pembeli,
  s.status_pembayaran,
  s.keterangan,
  l.public_id,
  CAST(v.version AS TEXT) AS version
`;

const linkJoin = `LEFT JOIN sync_resource_links l ON l.resource_type = 'penjualan' AND l.domain_id = CAST(s.id_penjualan AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type = l.resource_type AND v.public_id = l.public_id`;

function exactWeight(row: Row) {
  try {
    if (row.jumlah_kg_minor != null) return BigInt(String(row.jumlah_kg_minor));
    return parseWeight(String(row.jumlah_kg));
  } catch {
    throw new ApiError(409, 'SALE_LEGACY_AMOUNT_INVALID', 'Nilai penjualan lama tidak dapat dibaca dengan pasti.');
  }
}

function exactPrice(row: Row) {
  try {
    if (row.harga_per_kg_minor != null) return BigInt(String(row.harga_per_kg_minor));
    return parseMoney(String(row.harga_per_kg));
  } catch {
    throw new ApiError(409, 'SALE_LEGACY_AMOUNT_INVALID', 'Nilai penjualan lama tidak dapat dibaca dengan pasti.');
  }
}

export async function getSale(db: Executor, id: string) {
  const row = (await db.execute({
    sql: `SELECT ${headerColumns} FROM penjualan s ${linkJoin} WHERE s.id_penjualan = ?`,
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'SALE_NOT_FOUND', 'Data penjualan tidak ditemukan.');

  const details = (await db.execute({
    sql: `SELECT
        CAST(d.id_detail_penjualan AS TEXT) AS id_detail_penjualan,
        CAST(d.id_panen AS TEXT) AS id_panen,
        h.tanggal_panen,
        CAST(hp.layak AS TEXT) AS berat_layak,
        CAST(d.jumlah_kg_minor AS TEXT) AS jumlah_kg_minor,
        CAST(d.harga_per_kg_minor AS TEXT) AS harga_per_kg_minor,
        CAST(d.jumlah_kg AS TEXT) AS jumlah_kg,
        CAST(d.harga_per_kg AS TEXT) AS harga_per_kg
      FROM detail_penjualan d
      JOIN panen h ON h.id_panen = d.id_panen
      LEFT JOIN (
        SELECT id_panen, SUM(berat_minor) AS layak
        FROM detail_panen
        GROUP BY id_panen
      ) hp ON hp.id_panen = d.id_panen
      WHERE d.id_penjualan = ?
      ORDER BY d.id_detail_penjualan`,
    args: [id],
  })).rows;
  if (!details.length) throw new ApiError(409, 'SALE_DETAILS_MISSING', 'Transaksi penjualan tidak memiliki rincian.');

  return {
    id_penjualan: String(row.id_penjualan),
    id_user: String(row.id_user),
    tanggal_penjualan: String(row.tanggal_penjualan),
    pembeli: String(row.pembeli),
    status_pembayaran: String(row.status_pembayaran),
    keterangan: row.keterangan == null ? null : String(row.keterangan),
    public_id: row.public_id == null ? null : String(row.public_id),
    version: row.version == null ? null : String(row.version),
    details: details.map((detail) => {
      const quantity = exactWeight(detail);
      const price = exactPrice(detail);
      return {
        id_detail_penjualan: String(detail.id_detail_penjualan),
        id_panen: String(detail.id_panen),
        tanggal_panen: String(detail.tanggal_panen),
        berat_layak: detail.berat_layak == null ? null : formatWeight(BigInt(String(detail.berat_layak))),
        jumlah_kg: formatWeight(quantity),
        harga_per_kg: formatMoney(price),
        total_harga: formatMoney(saleLineTotal(quantity, price)),
      };
    }),
  };
}

export async function listSales(db: Executor, query: ListSalesQuery) {
  const total = Number((await db.execute('SELECT COUNT(*) AS total FROM penjualan')).rows[0].total);
  const ids = (await db.execute({
    sql: 'SELECT CAST(id_penjualan AS TEXT) AS id FROM penjualan ORDER BY tanggal_penjualan DESC, id_penjualan DESC LIMIT ? OFFSET ?',
    args: [query.limit, (query.page - 1) * query.limit],
  })).rows;
  const data = [];
  for (const row of ids) data.push(await getSale(db, String(row.id)));
  return { data, meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) } };
}
