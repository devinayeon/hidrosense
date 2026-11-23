import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import { ApiError } from '../../common/errors.js';
import { emptyQuerySchema, parseInput } from '../../common/validation.js';
import type { AppConfig } from '../../config.js';
import { scanFolder } from '../scans/service.js';
import { signCloudinaryParams } from './signature.js';

/**
 * Tanda tangan unggahan foto ke Cloudinary. Aplikasi mengunggah langsung ke Cloudinary dengan
 * tanda tangan ini, jadi api_secret tidak pernah ada di aplikasi dan tidak pernah dikirim keluar.
 * Folder ditentukan server per pengguna; klien tidak bisa memilihnya.
 */
export function registerUploads(
  app: FastifyInstance,
  db: Client,
  clock: () => number,
  config: AppConfig,
) {
  app.post(
    '/api/v1/unggahan/tanda-tangan',
    { preHandler: requirePermission(db, 'deteksi:write', clock) },
    async (request) => {
      parseInput(emptyQuerySchema, request.query);
      const cloudinary = config.cloudinary;
      if (!cloudinary) {
        throw new ApiError(503, 'UPLOAD_NOT_CONFIGURED', 'Layanan unggah foto belum dikonfigurasi.');
      }
      const timestamp = Math.floor(clock() / 1000);
      const folder = scanFolder(request.principal!.id_user);
      return {
        data: {
          cloud_name: cloudinary.cloudName,
          api_key: cloudinary.apiKey,
          timestamp,
          folder,
          signature: signCloudinaryParams({ folder, timestamp }, cloudinary.apiSecret),
          upload_url: `https://api.cloudinary.com/v1_1/${cloudinary.cloudName}/image/upload`,
        },
      };
    },
  );
}
