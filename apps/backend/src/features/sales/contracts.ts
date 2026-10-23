import { z } from 'zod';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';
import { parseWeight } from '../../db/harvest-weights.js';
import { parseMoney } from '../../db/sales-amounts.js';

export { idParamSchema, parseInput } from '../../common/validation.js';

const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((v) => {
  const ms = Date.parse(v + 'T00:00:00Z');
  return Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10) === v;
});

const weight = z.string().refine((v) => {
  try { return parseWeight(v) > 0n; } catch { return false; }
});
const money = z.string().refine((v) => {
  try { return parseMoney(v) > 0n; } catch { return false; }
});
const note = z.string().trim().max(1000).transform((v) => v || null).nullable();
const buyer = z.string().trim().min(1).max(100);
const paymentStatus = z.enum(['lunas', 'belum_lunas']);

const saleFields = {
  tanggal_penjualan: date,
  pembeli: buyer,
  status_pembayaran: paymentStatus,
  keterangan: note.optional().transform((v) => v ?? null),
  id_panen: integerIdSchema,
  jumlah_kg: weight,
  harga_per_kg: money,
};

export const createSaleSchema = z.strictObject(saleFields);

const detailKeys = ['id_panen', 'jumlah_kg', 'harga_per_kg'] as const;
const updateKeys = ['tanggal_penjualan', 'pembeli', 'status_pembayaran', 'keterangan', ...detailKeys] as const;
const hasDetailField = (v: Record<string, unknown>) => detailKeys.some((key) => v[key] !== undefined);

export const updateSaleSchema = z.strictObject({
  expected_version: integerIdSchema,
  tanggal_penjualan: date.optional(),
  pembeli: buyer.optional(),
  status_pembayaran: paymentStatus.optional(),
  keterangan: note.optional(),
  id_panen: integerIdSchema.optional(),
  jumlah_kg: weight.optional(),
  harga_per_kg: money.optional(),
})
  .refine((v) => updateKeys.some((key) => v[key] !== undefined), 'Minimal satu field harus diperbarui.')
  .refine((v) => !hasDetailField(v) || detailKeys.every((key) => v[key] !== undefined), 'Batch, berat, dan harga harus diisi bersama.');

export const listSalesQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
});

export const emptyQuerySchema = z.strictObject({});

export type CreateSaleInput = z.infer<typeof createSaleSchema>;
export type UpdateSaleInput = z.infer<typeof updateSaleSchema>;
export type ListSalesQuery = z.infer<typeof listSalesQuerySchema>;
