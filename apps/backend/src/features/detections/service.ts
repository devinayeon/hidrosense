import type { InValue, Transaction } from '@libsql/client';
import { jakartaDate } from '../../common/dates.js';
import { ApiError } from '../../common/errors.js';
import { confidenceToMinor, type CreateDetectionInput, type UpdateDetectionInput } from './contracts.js';
import { getDetection } from './store.js';

// A scan is timed by the phone, whose clock can run slightly ahead of the server's.
const CLOCK_DRIFT_MS = 5 * 60 * 1000;

export async function createDetection(tx: Transaction, input: CreateDetectionInput, actorId: string, now: number) {
  const scannedAt = Date.parse(input.tanggal_deteksi);
  if (scannedAt > now + CLOCK_DRIFT_MS) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Tanggal deteksi tidak boleh di masa depan.');
  }
  const batch = (await tx.execute({
    sql: 'SELECT tanggal_pemindahan FROM pemindahan WHERE id_pemindahan=?', args: [input.id_pemindahan],
  })).rows[0];
  if (!batch) throw new ApiError(422, 'TRANSFER_NOT_FOUND', 'Data pemindahan tidak ditemukan.');
  if (jakartaDate(scannedAt) < String(batch.tanggal_pemindahan)) {
    throw new ApiError(400, 'INVALID_DETECTION_DATE', 'Tanggal deteksi mendahului tanggal pemindahan.');
  }
  const id = String((await tx.execute({
    sql: `INSERT INTO deteksi (id_pemindahan,id_user,tanggal_deteksi,status_deteksi,model_versi,
        ambang_confidence_minor,gambar_public_id,gambar_url,keterangan)
      VALUES (?,?,?,?,?,?,?,?,?) RETURNING CAST(id_deteksi AS TEXT) AS id`,
    args: [input.id_pemindahan, actorId, new Date(scannedAt).toISOString(), input.status_deteksi, input.model_versi,
      input.ambang_confidence === null ? null : confidenceToMinor(input.ambang_confidence),
      input.gambar?.public_id ?? null, input.gambar?.url ?? null, input.keterangan],
  })).rows[0].id);
  for (const result of input.hasil) {
    await tx.execute({
      sql: 'INSERT INTO hasil_deteksi (id_deteksi,nama_hama,confidence_minor,jumlah_objek) VALUES (?,?,?,?)',
      args: [id, result.nama_hama, confidenceToMinor(result.confidence), result.jumlah_objek],
    });
  }
  return getDetection(tx, id);
}

export async function updateDetection(tx: Transaction, id: string, input: UpdateDetectionInput) {
  const existing = await getDetection(tx, id);
  const fields: string[] = [];
  const args: InValue[] = [];
  if (input.gambar !== undefined) {
    // The image is evidence for the stored result, so it cannot be swapped once attached.
    if (existing.gambar && existing.gambar.public_id !== input.gambar.public_id) {
      throw new ApiError(409, 'DETECTION_IMAGE_LOCKED', 'Gambar deteksi sudah tersimpan dan tidak dapat diganti.');
    }
    fields.push('gambar_public_id=?', 'gambar_url=?');
    args.push(input.gambar.public_id, input.gambar.url);
  }
  if (input.keterangan !== undefined) {
    fields.push('keterangan=?');
    args.push(input.keterangan);
  }
  await tx.execute({ sql: `UPDATE deteksi SET ${fields.join(',')} WHERE id_deteksi=?`, args: [...args, id] });
  return getDetection(tx, id);
}
