import { z } from 'zod';
import { positiveDecimalSchema } from '../../common/quantities.js';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';

export { idParamSchema, parseInput } from '../../common/validation.js';

const directionSchema = z.enum(['masuk', 'keluar']);
const reasonSchema = z.string().trim().min(1).max(1000);
/** Satu baris barang stok. Dipakai juga oleh perawatan yang memakai obat dari inventaris. */
export const stockLineSchema = z.strictObject({
  id_inventaris: integerIdSchema,
  jumlah: positiveDecimalSchema,
  satuan: z.string().trim().min(1).max(30),
});

export const createStockSchema = z.strictObject({
  jenis_stok: directionSchema,
  details: z.array(stockLineSchema).min(1).max(100)
    .refine((lines) => new Set(lines.map((line) => line.id_inventaris)).size === lines.length)
    .transform((lines) => lines.sort((left, right) => {
      const a = BigInt(left.id_inventaris);
      const b = BigInt(right.id_inventaris);
      return a < b ? -1 : a > b ? 1 : 0;
    })),
  keterangan: reasonSchema.nullable().optional().transform((value) => value ?? null),
});

export const reverseStockSchema = z.strictObject({ keterangan: reasonSchema });

export const historyQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  id_inventaris: integerIdSchema.optional(),
  jenis_stok: directionSchema.optional(),
});

export { emptyQuerySchema } from '../../common/validation.js';
export type StockInput = z.infer<typeof createStockSchema>;
export type StockLine = StockInput['details'][number];
