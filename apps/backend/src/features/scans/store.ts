import type { Client, Row } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import type { ListScanQuery } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const columns = `
  CAST(h.id_hasil_deteksi AS TEXT) AS id_hasil_deteksi,
  CAST(h.id_pemindahan AS TEXT) AS id_pemindahan,
  CAST(p.id_meja AS TEXT) AS id_meja,
  h.gambar, h.cloudinary_public_id, h.versi_model, h.tanggal_deteksi
`;
const from = 'hasil_deteksi h JOIN pemindahan p ON p.id_pemindahan = h.id_pemindahan';

/** Satu kueri untuk semua hitungan halaman ini, bukan satu kueri per foto. */
async function withDetections(db: Executor, rows: Row[]) {
  const ids = rows.map((row) => String(row.id_hasil_deteksi));
  const byScan = new Map<string, { hama: string; jumlah: number; confidence_maks: number | null }[]>();
  if (ids.length > 0) {
    const detections = (await db.execute({
      sql: `SELECT CAST(d.id_hasil_deteksi AS TEXT) AS id, d.kode_hama AS hama, d.jumlah, d.confidence_maks
        FROM deteksi_hama d JOIN hama a ON a.kode_hama = d.kode_hama
        WHERE d.id_hasil_deteksi IN (${ids.map(() => '?').join(',')})
        ORDER BY d.id_hasil_deteksi, a.indeks_model`,
      args: ids,
    })).rows;
    for (const d of detections) {
      const list = byScan.get(String(d.id)) ?? [];
      list.push({
        hama: String(d.hama),
        jumlah: Number(d.jumlah),
        confidence_maks: d.confidence_maks == null ? null : Number(d.confidence_maks),
      });
      byScan.set(String(d.id), list);
    }
  }
  return rows.map((row) => ({
    id_hasil_deteksi: String(row.id_hasil_deteksi),
    id_pemindahan: String(row.id_pemindahan),
    id_meja: String(row.id_meja),
    gambar: String(row.gambar),
    cloudinary_public_id: row.cloudinary_public_id == null ? null : String(row.cloudinary_public_id),
    versi_model: String(row.versi_model),
    tanggal_deteksi: String(row.tanggal_deteksi),
    deteksi: byScan.get(String(row.id_hasil_deteksi)) ?? [],
  }));
}

export async function getScan(db: Executor, id: string) {
  const rows = (await db.execute({ sql: `SELECT ${columns} FROM ${from} WHERE h.id_hasil_deteksi = ?`, args: [id] })).rows;
  if (!rows[0]) throw new ApiError(404, 'DETECTION_NOT_FOUND', 'Hasil deteksi tidak ditemukan.');
  return (await withDetections(db, rows))[0];
}

export async function listScans(db: Executor, query: ListScanQuery) {
  const filter = query.id_pemindahan ?? null;
  const where = '(? IS NULL OR h.id_pemindahan = ?)';
  const total = Number((await db.execute({
    sql: `SELECT COUNT(*) AS total FROM hasil_deteksi h WHERE ${where}`,
    args: [filter, filter],
  })).rows[0].total);
  const rows = (await db.execute({
    sql: `SELECT ${columns} FROM ${from} WHERE ${where}
      ORDER BY h.tanggal_deteksi DESC, h.id_hasil_deteksi DESC LIMIT ? OFFSET ?`,
    args: [filter, filter, query.limit, (query.page - 1) * query.limit],
  })).rows;
  return {
    data: await withDetections(db, rows),
    meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) },
  };
}

export async function insertScan(
  db: Executor,
  row: { id_pemindahan: string; id_user: string; gambar: string; cloudinary_public_id: string | null; versi_model: string; tanggal_deteksi: string },
  detections: readonly { hama: string; jumlah: number; confidence_maks: number | null }[],
) {
  const inserted = (await db.execute({
    sql: `INSERT INTO hasil_deteksi (id_pemindahan, id_user, gambar, cloudinary_public_id, versi_model, tanggal_deteksi)
      VALUES (?, ?, ?, ?, ?, ?) RETURNING CAST(id_hasil_deteksi AS TEXT) AS id`,
    args: [row.id_pemindahan, row.id_user, row.gambar, row.cloudinary_public_id, row.versi_model, row.tanggal_deteksi],
  })).rows[0];
  const id = String(inserted.id);
  for (const d of detections) {
    await db.execute({
      sql: 'INSERT INTO deteksi_hama (id_hasil_deteksi, kode_hama, jumlah, confidence_maks) VALUES (?, ?, ?, ?)',
      args: [id, d.hama, d.jumlah, d.confidence_maks],
    });
  }
  return id;
}
