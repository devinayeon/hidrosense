import { z } from 'zod';
import { hamaSchema } from '../../common/pests.js';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';

export { emptyQuerySchema, idParamSchema, parseInput } from '../../common/validation.js';

const detectionSchema = z.strictObject({
  hama: hamaSchema,
  jumlah: z.number().int().min(1).max(100_000),
  confidence_maks: z.number().min(0).max(1).nullable().optional().transform((v) => v ?? null),
});

/** Satu foto, hitungan per kelas. Daftar kosong berarti tidak ada hama terdeteksi pada foto itu. */
export const createScanSchema = z.strictObject({
  id_pemindahan: integerIdSchema,
  gambar: z.string().url().max(500),
  cloudinary_public_id: z.string().trim().min(1).max(255).nullable().optional().transform((v) => v ?? null),
  versi_model: z.string().trim().min(1).max(60),
  deteksi: z.array(detectionSchema).max(3),
}).refine((v) => new Set(v.deteksi.map((d) => d.hama)).size === v.deteksi.length, {
  message: 'Setiap hama hanya boleh muncul sekali.',
  path: ['deteksi'],
});

export const listScanQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  id_pemindahan: integerIdSchema.optional(),
});

export type CreateScanInput = z.infer<typeof createScanSchema>;
export type ListScanQuery = z.infer<typeof listScanQuerySchema>;
