import { z } from 'zod';
import { integerIdSchema as intId } from '../../common/validation.js';
export { idParamSchema, activeListQuerySchema as listQuerySchema, parseInput } from '../../common/validation.js';

// ── shared field definitions ──────────────────────────────────────────────────

const positiveDecimal = z.string()
  .regex(/^\d{1,10}(\.\d{1,2})?$/)
  .refine((value) => /[1-9]/.test(value))
  .transform((value) => {
    const [whole, fraction] = value.split('.');
    const normalizedWhole = BigInt(whole).toString();
    const normalizedFraction = fraction?.replace(/0+$/, '');
    return normalizedFraction ? `${normalizedWhole}.${normalizedFraction}` : normalizedWhole;
  });

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
