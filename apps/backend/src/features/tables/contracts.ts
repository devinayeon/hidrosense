import { z } from 'zod';
import { activeListQuerySchema } from '../../common/validation.js';
export { idParamSchema, parseInput } from '../../common/validation.js';

const fields = {
  kode_meja: z.string().trim().min(1).max(30),
  jumlah_lubang: z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
  status_meja: z.string().trim().min(1).max(30),
  keterangan: z.string().trim().max(1000).nullable(),
};
export const createTableSchema = z.strictObject({
  ...fields, status_meja: fields.status_meja.default('tersedia'),
  keterangan: fields.keterangan.optional().transform((value) => value ?? null),
});
export const updateTableSchema = z.strictObject(fields).partial()
  .refine((value) => Object.keys(value).length > 0);
export const listTableSchema = z.strictObject({
  page: activeListQuerySchema.shape.page, limit: activeListQuerySchema.shape.limit,
  status_meja: fields.status_meja.optional(),
});
export const emptyQuerySchema = z.strictObject({});
export type CreateTableInput = z.infer<typeof createTableSchema>;
export type UpdateTableInput = z.infer<typeof updateTableSchema>;
export type ListTableInput = z.infer<typeof listTableSchema>;
