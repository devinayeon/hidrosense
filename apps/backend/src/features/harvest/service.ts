import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { formatWeight, parseWeight } from '../../db/harvest-weights.js';
import { getHarvest } from './store.js';
import type { CreateHarvestInput, UpdateHarvestInput } from './contracts.js';
export async function createHarvest(tx: Transaction, input: CreateHarvestInput, actor: string, now: number) {
  if (input.tanggal_panen > new Date(now + 7 * 3600000).toISOString().slice(0, 10)) throw new ApiError(400, 'VALIDATION_ERROR', 'Tanggal panen tidak boleh di masa depan.');
  for (const d of input.details) {
    const row = (await tx.execute({ sql: `SELECT tanggal_pemindahan,jumlah_tanaman-(SELECT COALESCE(SUM(jumlah_tanaman),0) FROM kerusakan_tanaman WHERE id_pemindahan=p.id_pemindahan)-(SELECT COALESCE(SUM(jumlah_tanaman),0) FROM detail_panen WHERE id_pemindahan=p.id_pemindahan) AS remaining FROM pemindahan p WHERE id_pemindahan=?`, args: [d.id_pemindahan] })).rows[0];
    if (!row) throw new ApiError(404, 'TRANSFER_NOT_FOUND', 'Data pemindahan tidak ditemukan.');
    if (input.tanggal_panen < String(row.tanggal_pemindahan)) throw new ApiError(400, 'INVALID_HARVEST_DATE', 'Tanggal panen mendahului pemindahan.');
    if (d.jumlah_tanaman > Number(row.remaining)) throw new ApiError(409, 'HARVEST_EXCEEDS_ACTIVE_PLANTS', 'Jumlah panen melebihi tanaman aktif.');
  }
  const id = String((await tx.execute({ sql: 'INSERT INTO panen(id_user,tanggal_panen,keterangan) VALUES (?,?,?) RETURNING CAST(id_panen AS TEXT) AS id', args: [actor, input.tanggal_panen, input.keterangan] })).rows[0].id);
  for (const d of input.details) {
    const reject = parseWeight(d.berat_reject), layak = parseWeight(d.berat_total) - reject;
    await tx.execute({ sql: 'INSERT INTO detail_panen(id_panen,id_pemindahan,jumlah_tanaman,berat,berat_minor,berat_reject_minor) VALUES (?,?,?,?,?,?)', args: [id, d.id_pemindahan, d.jumlah_tanaman, formatWeight(layak), layak, reject] });
  }
  return getHarvest(tx, id);
}
export async function updateHarvest(tx: Transaction, id: string, input: UpdateHarvestInput) {
  const existing = await getHarvest(tx, id);
  if (existing.version !== input.expected_version) throw new ApiError(409, 'HARVEST_VERSION_CONFLICT', 'Versi panen telah berubah.');
  const details = new Map(existing.details.map(d => [d.id_detail_panen, parseWeight(d.berat_layak)]));
  for (const d of input.details ?? []) {
    if (!details.has(d.id_detail_panen)) throw new ApiError(404, 'HARVEST_DETAIL_NOT_FOUND', 'Detail panen tidak ditemukan.');
    details.set(d.id_detail_panen, parseWeight(d.berat_total) - parseWeight(d.berat_reject));
  }
  const soldRows = (await tx.execute({ sql: 'SELECT CAST(jumlah_kg AS TEXT) AS weight, CAST(CAST(jumlah_kg AS TEXT) AS NUMERIC)=jumlah_kg AS roundtrip FROM detail_penjualan WHERE id_panen=?', args: [id] })).rows;
  let sold = 0n; for (const row of soldRows) {
    try { if (Number(row.roundtrip) !== 1) throw new Error('Ambiguous float'); sold += parseWeight(String(row.weight)); }
    catch { throw new ApiError(409, 'HARVEST_SOLD_WEIGHT_INVALID', 'Berat penjualan lama tidak valid.'); }
  }
  if ([...details.values()].reduce((a, b) => a + b, 0n) < sold) throw new ApiError(409, 'HARVEST_WEIGHT_BELOW_SOLD', 'Berat layak kurang dari berat terjual.');
  for (const d of input.details ?? []) {
    const reject = parseWeight(d.berat_reject), layak = parseWeight(d.berat_total) - reject;
    await tx.execute({ sql: 'UPDATE detail_panen SET berat=?,berat_minor=?,berat_reject_minor=? WHERE id_detail_panen=? AND id_panen=?', args: [formatWeight(layak), layak, reject, d.id_detail_panen, id] });
  }
  if (input.keterangan !== undefined) await tx.execute({ sql: 'UPDATE panen SET keterangan=? WHERE id_panen=?', args: [input.keterangan, id] });
  return getHarvest(tx, id);
}
