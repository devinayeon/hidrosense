import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import type { AppConfig } from '../../config.js';
import type { CreateScanInput } from './contracts.js';
import { getScan, insertScan } from './store.js';

/** Folder unggah per pengguna. Sama dengan folder yang ditandatangani `POST /unggahan/tanda-tangan`. */
export const scanFolder = (actorId: string) => `hidrosense/pindai/${actorId}`;

/**
 * Hanya foto di folder pindai milik pengguna sendiri, pada akun Cloudinary aplikasi, yang diterima.
 * URL bebas bisa melacak pengguna atau memuat konten orang lain saat riwayat dibuka.
 */
export function assertOwnCloudinaryPhoto(
  raw: string,
  publicId: string | null,
  actorId: string,
  config: AppConfig,
) {
  if (!config.cloudinary) {
    throw new ApiError(503, 'UPLOAD_NOT_CONFIGURED', 'Layanan unggah foto belum dikonfigurasi.');
  }
  const invalid = () => new ApiError(400, 'VALIDATION_ERROR', 'Alamat foto harus berasal dari folder pindai milik akun ini.');
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw invalid();
  }
  // Bentuk secure_url hasil unggah bertanda tangan: /<cloud>/image/upload/v<versi>/<folder>/<berkas>.
  // Cloud name dan id pengguna hanya huruf, angka, '_' atau '-', jadi aman dipakai dalam pola.
  const pattern = new RegExp(
    `^/${config.cloudinary.cloudName}/image/upload/(v[0-9]+/)?${scanFolder(actorId)}/[A-Za-z0-9_.-]+$`,
  );
  if (url.protocol !== 'https:' || url.hostname !== 'res.cloudinary.com' || url.search !== '' || !pattern.test(url.pathname)) {
    throw invalid();
  }
  if (publicId !== null && !new RegExp(`^${scanFolder(actorId)}/[A-Za-z0-9_.-]+$`).test(publicId)) throw invalid();
}

export async function createScan(tx: Transaction, actorId: string, input: CreateScanInput, config: AppConfig, now: number) {
  assertOwnCloudinaryPhoto(input.gambar, input.cloudinary_public_id, actorId, config);
  const transfer = (await tx.execute({ sql: 'SELECT 1 FROM pemindahan WHERE id_pemindahan = ?', args: [input.id_pemindahan] })).rows[0];
  if (!transfer) throw new ApiError(422, 'TRANSFER_NOT_FOUND', 'Data pemindahan tidak ditemukan.');
  const id = await insertScan(
    tx,
    {
      id_pemindahan: input.id_pemindahan,
      id_user: actorId,
      gambar: input.gambar,
      cloudinary_public_id: input.cloudinary_public_id,
      versi_model: input.versi_model,
      tanggal_deteksi: new Date(now).toISOString(),
    },
    input.deteksi,
  );
  return getScan(tx, id);
}
