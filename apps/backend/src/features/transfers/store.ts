import type { Client, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import type { CreateTransferInput, ListTransferQuery, UpdateTransferInput } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const dayMs = 24 * 60 * 60 * 1000;
const HARVEST_STANDARD_DAYS = 45;
const jakartaDate = (now: number) => new Date(now + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
const nullableId = (value: Row[string]) => (value == null ? null : String(value));

const batchActive = `p.jumlah_tanaman
  - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan=p.id_pemindahan), 0)
  - COALESCE((SELECT SUM(d.jumlah_tanaman) FROM detail_panen d WHERE d.id_pemindahan=p.id_pemindahan), 0)`;

const linkJoin = `LEFT JOIN sync_resource_links l ON l.resource_type='pemindahan' AND l.domain_id=CAST(p.id_pemindahan AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;

const columns = `
  CAST(p.id_pemindahan AS TEXT) AS id_pemindahan,
  l.public_id,
  CAST(v.version AS TEXT) AS version,
  CAST(p.id_penyemaian AS TEXT) AS id_penyemaian,
  CAST(p.id_meja AS TEXT) AS id_meja,
  m.kode_meja,
  m.status_meja,
  m.jumlah_lubang,
  s.tanggal_semai,
  p.tanggal_pemindahan,
  p.jumlah_tanaman,
  p.keterangan,
  (${batchActive}) AS tanaman_aktif
`;

function transferRow(row: Row, today: string) {
  const semaiDate = String(row.tanggal_semai);
  const pindahDate = String(row.tanggal_pemindahan);
  const semaiMs = Date.parse(`${semaiDate}T00:00:00Z`);
  const pindahMs = Date.parse(`${pindahDate}T00:00:00Z`);
  const todayMs = Date.parse(`${today}T00:00:00Z`);

  const umurSemaiHari = Math.floor((pindahMs - semaiMs) / dayMs);
  const estimasiPanen = new Date(semaiMs + HARVEST_STANDARD_DAYS * dayMs).toISOString().slice(0, 10);
  const hss = Math.floor((todayMs - semaiMs) / dayMs);
  const hst = Math.floor((todayMs - pindahMs) / dayMs);
  const sisaHariPanen = Math.max(0, Math.floor((Date.parse(`${estimasiPanen}T00:00:00Z`) - todayMs) / dayMs));
  const active = Number(row.tanaman_aktif);

  return {
    id_pemindahan: String(row.id_pemindahan),
    public_id: nullableId(row.public_id),
    version: nullableId(row.version),
    id_penyemaian: String(row.id_penyemaian),
    id_meja: String(row.id_meja),
    kode_meja: String(row.kode_meja),
    tanggal_semai: semaiDate,
    tanggal_pemindahan: pindahDate,
    jumlah_tanaman: Number(row.jumlah_tanaman),
    keterangan: row.keterangan == null ? null : String(row.keterangan),
    umur_semai_hari: umurSemaiHari,
    estimasi_panen: estimasiPanen,
    hss,
    hst,
    sisa_hari_panen: sisaHariPanen,
    tanaman_aktif: active,
  };
}

export async function getTransfer(db: Executor, id: string, now: number) {
  const row = (await db.execute({
    sql: `SELECT ${columns} FROM pemindahan p
      JOIN penyemaian s ON s.id_penyemaian = p.id_penyemaian
      JOIN meja_tanam m ON m.id_meja = p.id_meja
      ${linkJoin}
      WHERE p.id_pemindahan = ?`,
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'TRANSFER_NOT_FOUND', 'Data pemindahan tidak ditemukan.');
  return transferRow(row, jakartaDate(now));
}

export async function listTransfers(db: Executor, query: ListTransferQuery, now: number) {
  const today = jakartaDate(now);
  const filterMeja = query.id_meja ?? null;
  const filterSemai = query.id_penyemaian ?? null;
  const whereSql = `
    (? IS NULL OR p.id_meja = ?)
    AND (? IS NULL OR p.id_penyemaian = ?)
  `;
  const args = [filterMeja, filterMeja, filterSemai, filterSemai];

  const count = (await db.execute({
    sql: `SELECT COUNT(*) AS total FROM pemindahan p WHERE ${whereSql}`,
    args,
  })).rows[0];
  const total = Number(count.total);

  const rows = (await db.execute({
    sql: `SELECT ${columns} FROM pemindahan p
      JOIN penyemaian s ON s.id_penyemaian = p.id_penyemaian
      JOIN meja_tanam m ON m.id_meja = p.id_meja
      ${linkJoin}
      WHERE ${whereSql}
      ORDER BY p.tanggal_pemindahan DESC, p.id_pemindahan DESC
      LIMIT ? OFFSET ?`,
    args: [...args, query.limit, (query.page - 1) * query.limit],
  })).rows;

  return {
    data: rows.map((r) => transferRow(r, today)),
    meta: {
      page: query.page,
      limit: query.limit,
      total,
      total_pages: Math.ceil(total / query.limit),
    },
  };
}

export async function countMovedSeedlings(tx: Transaction, idPenyemaian: string): Promise<number> {
  const row = (await tx.execute({
    sql: 'SELECT COALESCE(SUM(jumlah_tanaman), 0) AS total FROM pemindahan WHERE id_penyemaian = ?',
    args: [idPenyemaian],
  })).rows[0];
  return Number(row.total);
}

export async function countTableActive(tx: Transaction, idMeja: string): Promise<number> {
  const row = (await tx.execute({
    sql: `SELECT COALESCE(SUM(${batchActive}), 0) AS total FROM pemindahan p WHERE p.id_meja = ?`,
    args: [idMeja],
  })).rows[0];
  return Number(row.total);
}

export async function insertTransfer(tx: Transaction, input: CreateTransferInput, now: number) {
  const inserted = (await tx.execute({
    sql: `INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman, keterangan)
      VALUES (?, ?, ?, ?, ?) RETURNING CAST(id_pemindahan AS TEXT) AS id_pemindahan`,
    args: [input.id_penyemaian, input.id_meja, input.tanggal_pemindahan, input.jumlah_tanaman, input.keterangan ?? null],
  })).rows[0];
  return getTransfer(tx, String(inserted.id_pemindahan), now);
}

export async function patchTransfer(tx: Transaction, id: string, input: UpdateTransferInput, now: number) {
  await getTransfer(tx, id, now);
  if ('keterangan' in input) {
    await tx.execute({
      sql: 'UPDATE pemindahan SET keterangan = ? WHERE id_pemindahan = ?',
      args: [input.keterangan ?? null, id],
    });
  }
  return getTransfer(tx, id, now);
}
