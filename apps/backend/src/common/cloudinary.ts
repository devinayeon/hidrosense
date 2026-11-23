import type { AppConfig } from '../config.js';
import { ApiError } from './errors.js';

/**
 * Folder unggah per pengguna. Folder ini ikut ditandatangani `POST /unggahan/tanda-tangan` dan
 * diperiksa lagi saat pindaian disimpan, jadi kedua fitur harus memakai fungsi yang sama.
 */
export const scanFolder = (actorId: string) => `hidrosense/pindai/${actorId}`;

/** Konfigurasi Cloudinary, atau 503 bila server belum diberi kredensial. */
export function requireCloudinary(config: AppConfig) {
  if (!config.cloudinary) {
    throw new ApiError(503, 'UPLOAD_NOT_CONFIGURED', 'Layanan unggah foto belum dikonfigurasi.');
  }
  return config.cloudinary;
}
