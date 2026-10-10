import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { formatWeight } from '../../db/harvest-weights.js';
import type { ListHarvestQuery } from './contracts.js';
type Executor = Pick<Client, 'execute'>;
export async function getHarvest(db: Executor, id: string) {
  const row = (await db.execute({ sql: `SELECT CAST(p.id_panen AS TEXT) AS id_panen, CAST(p.id_user AS TEXT) AS id_user,p.tanggal_panen,p.keterangan,l.public_id,CAST(v.version AS TEXT) AS version FROM panen p LEFT JOIN sync_resource_links l ON l.resource_type='panen' AND l.domain_id=CAST(p.id_panen AS TEXT) LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id WHERE p.id_panen=?`, args: [id] })).rows[0];
  if (!row) throw new ApiError(404, 'HARVEST_NOT_FOUND', 'Data panen tidak ditemukan.');
  const rows = (await db.execute({ sql: `SELECT CAST(d.id_detail_panen AS TEXT) AS id_detail_panen,CAST(d.id_pemindahan AS TEXT) AS id_pemindahan,CAST(t.id_meja AS TEXT) AS id_meja,m.kode_meja,s.tanggal_semai,t.tanggal_pemindahan,d.jumlah_tanaman,CAST(d.berat_minor AS TEXT) AS layak,CAST(d.berat_reject_minor AS TEXT) AS reject FROM detail_panen d JOIN pemindahan t ON t.id_pemindahan=d.id_pemindahan JOIN meja_tanam m ON m.id_meja=t.id_meja JOIN penyemaian s ON s.id_penyemaian=t.id_penyemaian WHERE d.id_panen=? ORDER BY d.id_detail_panen`, args: [id] })).rows;
  let layak = 0n, reject = 0n;
  let known = true;
  const details = rows.map(d => {
    const l = BigInt(String(d.layak)); const r = d.reject == null ? null : BigInt(String(d.reject));
    layak += l; if (r === null) known = false; else reject += r;
    return { id_detail_panen: String(d.id_detail_panen), id_pemindahan: String(d.id_pemindahan), id_meja: String(d.id_meja), kode_meja: String(d.kode_meja), tanggal_semai: String(d.tanggal_semai), tanggal_pemindahan: String(d.tanggal_pemindahan), jumlah_tanaman: Number(d.jumlah_tanaman), berat_layak: formatWeight(l), berat_reject: r === null ? null : formatWeight(r), berat_total: r === null ? null : formatWeight(l + r) };
  });
  return { id_panen: String(row.id_panen), id_user: String(row.id_user), tanggal_panen: String(row.tanggal_panen), keterangan: row.keterangan == null ? null : String(row.keterangan), public_id: row.public_id == null ? null : String(row.public_id), version: row.version == null ? null : String(row.version), details, berat_layak: formatWeight(layak), berat_reject: known ? formatWeight(reject) : null, berat_total: known ? formatWeight(layak + reject) : null };
}
export async function listHarvests(db: Executor, query: ListHarvestQuery) {
  const total = Number((await db.execute('SELECT COUNT(*) AS total FROM panen')).rows[0].total);
  const ids = (await db.execute({ sql: 'SELECT CAST(id_panen AS TEXT) AS id FROM panen ORDER BY tanggal_panen DESC,id_panen DESC LIMIT ? OFFSET ?', args: [query.limit, (query.page - 1) * query.limit] })).rows;
  const data = []; for (const row of ids) data.push(await getHarvest(db, String(row.id)));
  return { data, meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) } };
}
