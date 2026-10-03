import { z } from 'zod';
import { integerIdSchema as intId } from '../../common/validation.js';
import { positiveDecimalSchema as positiveDecimal } from '../../common/quantities.js';
export { idParamSchema, activeListQuerySchema as listQuerySchema, parseInput } from '../../common/validation.js';

export const createJenisSchema = z.strictObject({
  nama_jenis: z.string().trim().min(1).max(50),
});

export const updateJenisSchema = createJenisSchema;

export const createObatSchema = z.strictObject({
  nama_obat: z.string().trim().min(1).max(100),
  jenis_obat: z.string().trim().min(1).max(50).nullable().optional(),
  dosis: z.string().trim().min(1).max(100).nullable().optional(),
  aturan_penggunaan: z.string().trim().min(1).nullable().optional(),
  deskripsi: z.string().trim().min(1).nullable().optional(),
});

export const updateObatSchema = createObatSchema.partial()
  .refine((v) => Object.keys(v).length > 0);

export const createInventarisSchema = z.strictObject({
  id_jenis_inventaris: intId,
  id_obat: intId.nullable().optional(),
  nama_barang: z.string().trim().min(1).max(100),
  satuan: z.string().trim().min(1).max(30),
  stok_minimum: positiveDecimal.nullable().optional(),
});

export const updateInventarisSchema = createInventarisSchema.partial()
  .refine((v) => Object.keys(v).length > 0);
