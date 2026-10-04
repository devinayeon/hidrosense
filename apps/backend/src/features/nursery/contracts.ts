import { z } from 'zod';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';

export { idParamSchema, parseInput } from '../../common/validation.js';

/** YYYY-MM-DD validated as a real calendar date */
const dateSchema = z.string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((d) => {
    const ms = Date.parse(d + 'T00:00:00Z');
    if (isNaN(ms)) return false;
    // Reject dates that shift after UTC parse (e.g. month overflow like Feb 30)
    const back = new Date(ms).toISOString().slice(0, 10);
    return back === d;
  }, { message: 'Tanggal tidak valid.' });

const materialLineSchema = z.strictObject({
  id_inventaris: integerIdSchema,
  jumlah: z.string().regex(/^\d+(\.\d{1,2})?$/).refine((v) => parseFloat(v) > 0, {
    message: 'Jumlah harus lebih dari nol.',
  }),
  satuan: z.string().trim().min(1).max(30),
});

export const createSowingSchema = z.strictObject({
  tanggal_semai: dateSchema,
  jumlah_benih: z.number().int().positive().max(1_000_000),
  keterangan: z.string().trim().max(1000).nullable().optional()
    .transform((v) => v ?? null),
  /** Materials consumed from stock. Required: at least one seed material must be recorded. */
  materials: z.array(materialLineSchema)
    .min(1, { message: 'Minimal satu bahan konsumsi harus dicatat.' })
    .max(50)
    .refine(
      (lines) => new Set(lines.map((l) => l.id_inventaris)).size === lines.length,
      { message: 'Setiap barang inventaris hanya boleh muncul sekali.' },
    ),
});

export const updateSowingSchema = z.strictObject({
  jumlah_benih: z.number().int().positive().max(1_000_000).optional(),
  status_penyemaian: z.enum(['aktif', 'selesai']).optional(),
  keterangan: z.string().trim().max(1000).nullable().optional(),
}).refine(
  (v) => Object.keys(v).length > 0,
  { message: 'Minimal satu field harus diperbarui.' },
);

export const listSowingQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  status_penyemaian: z.enum(['aktif', 'selesai']).optional(),
  /** When '1', only return sowings where age >= 15 days */
  siap_pindah: z.enum(['1']).optional(),
});

export const emptyQuerySchema = z.strictObject({});

export type CreateSowingInput = z.infer<typeof createSowingSchema>;
export type UpdateSowingInput = z.infer<typeof updateSowingSchema>;
export type SowingMaterial = CreateSowingInput['materials'][number];
