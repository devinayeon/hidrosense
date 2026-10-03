import { z } from 'zod';
import { ApiError } from './errors.js';

export const integerIdSchema = z.string().regex(/^[1-9][0-9]{0,18}$(?![\s\S])/)
  .pipe(z.string().refine((value) => BigInt(value) <= 9223372036854775807n));
export const uuidSchema = z.string().uuid();
export const clientUuidSchema = uuidSchema.transform((value) => value.toLowerCase());
export const idParamSchema = z.strictObject({ id: integerIdSchema });
export const activeListQuerySchema = z.strictObject({
  page: z.string().regex(/^[1-9][0-9]{0,5}$(?![\s\S])/).default('1').transform(Number),
  limit: z.string().regex(/^[1-9][0-9]{0,2}$(?![\s\S])/).default('20').transform(Number)
    .refine((value) => value <= 100),
  status_aktif: z.enum(['0', '1']).optional(),
});

export function parseInput<T>(schema: z.ZodType<T>, input: unknown): T {
  const result = schema.safeParse(input);
  if (!result.success) throw new ApiError(400, 'VALIDATION_ERROR', 'Input tidak sesuai kontrak API.');
  return result.data;
}
