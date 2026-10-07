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

export const createTransferSchema = z.strictObject({
  id_penyemaian: integerIdSchema,
  id_meja: integerIdSchema,
  tanggal_pemindahan: dateSchema,
  jumlah_tanaman: z.number().int().positive().max(1_000_000),
  keterangan: z.string().trim().max(1000).nullable().optional()
    .transform((v) => v ?? null),
});

export const updateTransferSchema = z.strictObject({
  keterangan: z.string().trim().max(1000).nullable().optional(),
}).refine(
  (v) => Object.keys(v).length > 0,
  { message: 'Minimal satu field harus diperbarui.' },
);

export const listTransferQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  id_meja: integerIdSchema.optional(),
  id_penyemaian: integerIdSchema.optional(),
});

export const emptyQuerySchema = z.strictObject({});

export type CreateTransferInput = z.infer<typeof createTransferSchema>;
export type UpdateTransferInput = z.infer<typeof updateTransferSchema>;
export type ListTransferQuery = z.infer<typeof listTransferQuerySchema>;
