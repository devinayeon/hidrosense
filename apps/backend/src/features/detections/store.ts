import type { Client, Row } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { minorToConfidence, type ListDetectionQuery } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const headerSelect = `SELECT CAST(d.id_deteksi AS TEXT) AS id_deteksi, CAST(d.id_pemindahan AS TEXT) AS id_pemindahan,
  CAST(d.id_user AS TEXT) AS id_user, d.tanggal_deteksi, d.status_deteksi, d.model_versi,
  d.ambang_confidence_minor, d.gambar_public_id, d.gambar_url, d.keterangan, l.public_id,
  CAST(v.version AS TEXT) AS version
  FROM deteksi d
  LEFT JOIN sync_resource_links l ON l.resource_type='deteksi' AND l.domain_id=CAST(d.id_deteksi AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;

function selectResults(idCount: number) {
  return `SELECT CAST(id_deteksi AS TEXT) AS id_deteksi, CAST(id_hasil_deteksi AS TEXT) AS id_hasil_deteksi,
    nama_hama, confidence_minor, jumlah_objek
    FROM hasil_deteksi WHERE id_deteksi IN (${Array(idCount).fill('?').join(',')})
    ORDER BY id_hasil_deteksi`;
}

function detectionResponse(row: Row, results: Row[]) {
  const stored = String(row.tanggal_deteksi);
  return {
    id_deteksi: String(row.id_deteksi),
    public_id: row.public_id == null ? null : String(row.public_id),
    version: row.version == null ? null : String(row.version),
    id_pemindahan: String(row.id_pemindahan),
    id_user: row.id_user == null ? null : String(row.id_user),
    // Rows that predate 0015 kept SQLite's own timestamp format.
    tanggal_deteksi: stored.includes('T') ? stored : `${stored.replace(' ', 'T')}.000Z`,
    status_deteksi: String(row.status_deteksi),
    model_versi: String(row.model_versi),
    ambang_confidence: row.ambang_confidence_minor == null ? null : minorToConfidence(Number(row.ambang_confidence_minor)),
    gambar: row.gambar_url == null ? null : {
      public_id: row.gambar_public_id == null ? null : String(row.gambar_public_id),
      url: String(row.gambar_url),
    },
    keterangan: row.keterangan == null ? null : String(row.keterangan),
    hasil: results.map((result) => ({
      id_hasil_deteksi: String(result.id_hasil_deteksi),
      nama_hama: String(result.nama_hama),
      confidence: result.confidence_minor == null ? null : minorToConfidence(Number(result.confidence_minor)),
      jumlah_objek: Number(result.jumlah_objek),
    })),
  };
}

export async function getDetection(db: Executor, id: string) {
  const header = (await db.execute({ sql: `${headerSelect} WHERE d.id_deteksi=?`, args: [id] })).rows[0];
  if (!header) throw new ApiError(404, 'DETECTION_NOT_FOUND', 'Data deteksi tidak ditemukan.');
  return detectionResponse(header, (await db.execute({ sql: selectResults(1), args: [id] })).rows);
}

export async function listDetections(db: Executor, query: ListDetectionQuery) {
  const args = [query.id_pemindahan ?? null, query.id_pemindahan ?? null, query.status_deteksi ?? null, query.status_deteksi ?? null];
  const where = '(? IS NULL OR d.id_pemindahan=?) AND (? IS NULL OR d.status_deteksi=?)';
  const total = Number((await db.execute({ sql: `SELECT COUNT(*) AS total FROM deteksi d WHERE ${where}`, args })).rows[0].total);
  const headers = (await db.execute({
    sql: `${headerSelect} WHERE ${where} ORDER BY d.tanggal_deteksi DESC, d.id_deteksi DESC LIMIT ? OFFSET ?`,
    args: [...args, query.limit, (query.page - 1) * query.limit],
  })).rows;
  const results = new Map<string, Row[]>();
  if (headers.length) {
    const ids = headers.map((header) => String(header.id_deteksi));
    for (const row of (await db.execute({ sql: selectResults(ids.length), args: ids })).rows) {
      const id = String(row.id_deteksi);
      results.set(id, [...(results.get(id) ?? []), row]);
    }
  }
  return {
    data: headers.map((header) => detectionResponse(header, results.get(String(header.id_deteksi)) ?? [])),
    meta: { page: query.page, limit: query.limit, total, total_pages: Math.ceil(total / query.limit) },
  };
}
