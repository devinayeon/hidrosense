import { z } from 'zod';
import { ApiError } from '../../common/errors.js';

// ── shared field definitions ──────────────────────────────────────────────────

const intId = z.string().regex(/^[1-9][0-9]{0,18}$/)
  .pipe(z.string().refine((v) => BigInt(v) <= 9223372036854775807n));

const positiveDecimal = z.string()
  .regex(/^\d{1,10}(\.\d{1,2})?$/)
  .transform(Number)
  .refine((n) => n > 0);

// ── jenis_inventaris ──────────────────────────────────────────────────────────

export const createJenisSchema = z.strictObject({
  nama_jenis: z.string().trim().min(1).max(50),
});

export const updateJenisSchema = z.strictObject({
  nama_jenis: z.string().trim().min(1).max(50),
});

// ── obat ──────────────────────────────────────────────────────────────────────

export const createObatSchema = z.strictObject({
  nama_obat: z.string().trim().min(1).max(100),
  jenis_obat: z.string().trim().min(1).max(50).nullable().optional(),
  dosis: z.string().trim().min(1).max(100).nullable().optional(),
  aturan_penggunaan: z.string().trim().min(1).nullable().optional(),
  deskripsi: z.string().trim().min(1).nullable().optional(),
});

export const updateObatSchema = createObatSchema.partial()
  .refine((v) => Object.keys(v).length > 0);

// ── inventaris ────────────────────────────────────────────────────────────────

export const createInventarisSchema = z.strictObject({
  id_jenis_inventaris: intId,
  id_obat: intId.nullable().optional(),
  nama_barang: z.string().trim().min(1).max(100),
  satuan: z.string().trim().min(1).max(30),
  stok_minimum: positiveDecimal.nullable().optional(),
});

export const updateInventarisSchema = z.strictObject({
  id_jenis_inventaris: intId.optional(),
  id_obat: intId.nullable().optional(),
  nama_barang: z.string().trim().min(1).max(100).optional(),
  satuan: z.string().trim().min(1).max(30).optional(),
  stok_minimum: positiveDecimal.nullable().optional(),
}).refine((v) => Object.keys(v).length > 0);

// ── shared params ─────────────────────────────────────────────────────────────

export const idParamSchema = z.strictObject({ id: intId });

export const listQuerySchema = z.strictObject({
  page: z.string().regex(/^[1-9][0-9]{0,5}$/).default('1').transform(Number),
  limit: z.string().regex(/^[1-9][0-9]{0,2}$/).default('20').transform(Number).refine((v) => v <= 100),
  status_aktif: z.enum(['0', '1']).optional(),
});

export function parseInput<T>(schema: z.ZodType<T>, input: unknown): T {
  const result = schema.safeParse(input);
  if (!result.success) throw new ApiError(400, 'VALIDATION_ERROR', 'Input tidak sesuai kontrak API.');
  return result.data;
}
