import type { Client, Row } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { formatWeight } from '../../common/weights.js';
import type { ListHarvestQuery } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const headerSelect = `SELECT CAST(p.id_panen AS TEXT) AS id_panen, CAST(p.id_user AS TEXT) AS id_user,
  p.tanggal_panen, p.keterangan, l.public_id, CAST(v.version AS TEXT) AS version
  FROM panen p
  LEFT JOIN sync_resource_links l ON l.resource_type='panen' AND l.domain_id=CAST(p.id_panen AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;

function selectDetails(idCount: number) {
  return `SELECT CAST(d.id_panen AS TEXT) AS id_panen, CAST(d.id_detail_panen AS TEXT) AS id_detail_panen,
    CAST(d.id_pemindahan AS TEXT) AS id_pemindahan, CAST(t.id_meja AS TEXT) AS id_meja, m.kode_meja,
    s.tanggal_semai, t.tanggal_pemindahan, d.jumlah_tanaman,
    CAST(d.berat_minor AS TEXT) AS layak, CAST(d.berat_reject_minor AS TEXT) AS reject
    FROM detail_panen d
    JOIN pemindahan t ON t.id_pemindahan=d.id_pemindahan
    JOIN meja_tanam m ON m.id_meja=t.id_meja
    JOIN penyemaian s ON s.id_penyemaian=t.id_penyemaian
    WHERE d.id_panen IN (${Array(idCount).fill('?').join(',')})
    ORDER BY d.id_detail_panen`;
}

function harvestResponse(header: Row, detailRows: Row[]) {
  let totalLayak = 0n;
  let totalReject = 0n;
  let rejectKnown = true;
  const details = detailRows.map((row) => {
    const layak = BigInt(String(row.layak));
    const reject = row.reject == null ? null : BigInt(String(row.reject));
    totalLayak += layak;
    if (reject === null) rejectKnown = false; else totalReject += reject;
    return {
      id_detail_panen: String(row.id_detail_panen),
      id_pemindahan: String(row.id_pemindahan),
      id_meja: String(row.id_meja),
      kode_meja: String(row.kode_meja),
      tanggal_semai: String(row.tanggal_semai),
      tanggal_pemindahan: String(row.tanggal_pemindahan),
      jumlah_tanaman: Number(row.jumlah_tanaman),
      berat_layak: formatWeight(layak),
      berat_reject: reject === null ? null : formatWeight(reject),
      berat_total: reject === null ? null : formatWeight(layak + reject),
    };
  });
  return {
    id_panen: String(header.id_panen),
    id_user: String(header.id_user),
    tanggal_panen: String(header.tanggal_panen),
    keterangan: header.keterangan == null ? null : String(header.keterangan),
    public_id: header.public_id == null ? null : String(header.public_id),
    version: header.version == null ? null : String(header.version),
    details,
    berat_layak: formatWeight(totalLayak),
    berat_reject: rejectKnown ? formatWeight(totalReject) : null,
    berat_total: rejectKnown ? formatWeight(totalLayak + totalReject) : null,
  };
}

export async function getHarvest(db: Executor, id: string) {
  const header = (await db.execute({ sql: `${headerSelect} WHERE p.id_panen=?`, args: [id] })).rows[0];
  if (!header) throw new ApiError(404, 'HARVEST_NOT_FOUND', 'Data panen tidak ditemukan.');
  const details = (await db.execute({ sql: selectDetails(1), args: [id] })).rows;
  return harvestResponse(header, details);
}

export async function listHarvests(db: Executor, query: ListHarvestQuery) {
  const total = Number((await db.execute('SELECT COUNT(*) AS total FROM panen')).rows[0].total);
  const headers = (await db.execute({
    sql: `${headerSelect} ORDER BY p.tanggal_panen DESC, p.id_panen DESC LIMIT ? OFFSET ?`,
    args: [query.limit, (query.page - 1) * query.limit],
  })).rows;
  const details = new Map<string, Row[]>();
  if (headers.length) {
    const ids = headers.map((header) => String(header.id_panen));
    for (const row of (await db.execute({ sql: selectDetails(ids.length), args: ids })).rows) {
      const id = String(row.id_panen);
      details.set(id, [...(details.get(id) ?? []), row]);
    }
  }
  return {
    data: headers.map((header) => harvestResponse(header, details.get(String(header.id_panen)) ?? [])),
    meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) },
  };
}
