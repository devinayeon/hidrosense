import { z } from 'zod';
import { hamaSchema } from '../../common/pests.js';
import { stockLineSchema } from '../stock/contracts.js';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';

export { emptyQuerySchema, idParamSchema, parseInput } from '../../common/validation.js';

export { hamaSchema };
export const tingkatSchema = z.enum(['ringan', 'sedang', 'berat']);
export const statusSchema = z.enum(['menunggu', 'diterima', 'ditolak']);
export const alasanTolakSchema = z.enum([
  'tidak_tersedia',
  'harga',
  'sudah_ditangani',
  'tidak_yakin_hama',
  'lainnya',
]);

/** Catatan opsional: spasi saja dianggap kosong. */
const noteSchema = z.string().trim().max(500).nullable().optional().transform((v) => v || null);

/** YYYY-MM-DD yang benar-benar ada di kalender. */
const dateSchema = z.string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((d) => {
    const ms = Date.parse(`${d}T00:00:00Z`);
    return !Number.isNaN(ms) && new Date(ms).toISOString().slice(0, 10) === d;
  }, { message: 'Tanggal tidak valid.' });

export const createRecommendationSchema = z.strictObject({
  id_meja: integerIdSchema,
  hama: hamaSchema,
  tingkat: tingkatSchema,
  id_hasil_deteksi: integerIdSchema.optional(),
});

export const acceptSchema = z.strictObject({
  tanggal_aplikasi: dateSchema.optional(),
  catatan: noteSchema,
  /** Obat dari inventaris yang dipakai. Dipotong dari stok dalam transaksi yang sama. */
  bahan: z.array(stockLineSchema).min(1).max(5).optional()
    .refine((rows) => !rows || new Set(rows.map((r) => r.id_inventaris)).size === rows.length, {
      message: 'Setiap barang hanya boleh muncul sekali.',
    }),
});

/** Menolak tidak murni "tidak": alasan terstruktur wajib, catatan wajib bila alasan "lainnya". */
export const rejectSchema = z.strictObject({
  alasan: alasanTolakSchema,
  catatan: noteSchema,
}).refine((v) => v.alasan !== 'lainnya' || v.catatan !== null, {
  message: 'Catatan wajib diisi bila alasan "lainnya".',
  path: ['catatan'],
});

export const listRecommendationQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  status: statusSchema.optional(),
  id_meja: integerIdSchema.optional(),
  hama: hamaSchema.optional(),
});

export type CreateRecommendationInput = z.infer<typeof createRecommendationSchema>;
export type AcceptInput = z.infer<typeof acceptSchema>;
export type RejectInput = z.infer<typeof rejectSchema>;
export type ListRecommendationQuery = z.infer<typeof listRecommendationQuerySchema>;
