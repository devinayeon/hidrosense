import { z } from 'zod';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';

export { idParamSchema, parseInput } from '../../common/validation.js';

/** YYYY-MM-DD validated as a real calendar date */
const dateSchema = z.string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((d) => {
    const ms = Date.parse(d + 'T00:00:00Z');
    if (isNaN(ms)) return false;
    const back = new Date(ms).toISOString().slice(0, 10);
    return back === d;
  }, { message: 'Tanggal tidak valid.' });

export const createDamageSchema = z.strictObject({
  id_pemindahan: integerIdSchema,
  tanggal_kejadian: dateSchema,
  jumlah_tanaman: z.number().int().positive().max(1_000_000),
  jenis_kerusakan: z.string().trim().min(1).max(100),
  keterangan: z.string().trim().max(1000).nullable().optional()
    .transform((v) => v ?? null),
});

export const updateDamageSchema = z.strictObject({
  tanggal_kejadian: dateSchema.optional(),
  jumlah_tanaman: z.number().int().positive().max(1_000_000).optional(),
  jenis_kerusakan: z.string().trim().min(1).max(100).optional(),
  keterangan: z.string().trim().max(1000).nullable().optional(),
}).refine(
  (v) => Object.keys(v).length > 0,
  { message: 'Minimal satu field harus diperbarui.' },
);

export const listDamageQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  id_pemindahan: integerIdSchema.optional(),
});

export const emptyQuerySchema = z.strictObject({});

export type CreateDamageInput = z.infer<typeof createDamageSchema>;
export type UpdateDamageInput = z.infer<typeof updateDamageSchema>;
export type ListDamageQuery = z.infer<typeof listDamageQuerySchema>;
