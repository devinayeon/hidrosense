import { z } from 'zod';
import { activeListQuerySchema, integerIdSchema } from '../../common/validation.js';
import { parseWeight } from '../../db/harvest-weights.js';
export { idParamSchema, parseInput } from '../../common/validation.js';
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v => {
  const ms = Date.parse(v + 'T00:00:00Z');
  return Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10) === v;
});
const weight = z.string().refine(v => { try { parseWeight(v); return true; } catch { return false; } });
const note = z.string().trim().max(1000).transform(v => v || null).nullable();
const weights = { berat_total: weight, berat_reject: weight };
const validWeights = (v: { berat_total: string; berat_reject: string }) => {
  try { const total = parseWeight(v.berat_total); return total > 0n && parseWeight(v.berat_reject) <= total; } catch { return false; }
};
const createDetail = z.strictObject({ id_pemindahan: integerIdSchema, jumlah_tanaman: z.number().int().min(1).max(1000000), ...weights }).refine(validWeights);
const patchDetail = z.strictObject({ id_detail_panen: integerIdSchema, ...weights }).refine(validWeights);
export const createHarvestSchema = z.strictObject({ tanggal_panen: date, keterangan: note.optional().transform(v => v ?? null), details: z.array(createDetail).min(1).max(100) }).refine(v => new Set(v.details.map(d => d.id_pemindahan)).size === v.details.length);
export const updateHarvestSchema = z.strictObject({ expected_version: integerIdSchema, keterangan: note.optional(), details: z.array(patchDetail).min(1).max(100).optional() }).refine(v => v.keterangan !== undefined || v.details !== undefined).refine(v => !v.details || new Set(v.details.map(d => d.id_detail_panen)).size === v.details.length);
export const listHarvestQuerySchema = z.strictObject({ page: activeListQuerySchema.shape.page, limit: activeListQuerySchema.shape.limit });
export const emptyQuerySchema = z.strictObject({});
export type CreateHarvestInput = z.infer<typeof createHarvestSchema>;
export type UpdateHarvestInput = z.infer<typeof updateHarvestSchema>;
export type ListHarvestQuery = z.infer<typeof listHarvestQuerySchema>;
