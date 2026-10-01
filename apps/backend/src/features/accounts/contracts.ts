import { z } from 'zod';
import { ApiError } from '../../common/errors.js';

const fields = {
  nama: z.string().trim().min(1).max(100),
  username: z.string().min(1).max(50).regex(/^\S(?:.*\S)?$/u),
  email: z.string().trim().max(100).email().nullable().optional(),
  no_telepon: z.string().trim().min(1).max(20).regex(/^\+?[0-9 ()-]+$/).nullable().optional(),
  alamat: z.string().trim().min(1).max(1000).nullable().optional(),
};
const password = z.string().min(12).max(128);
export const createEmployeeSchema = z.strictObject({ ...fields, password });
export const updateEmployeeSchema = z.strictObject({
  ...fields, password: password.optional(),
}).partial().refine((value) => Object.keys(value).length > 0);
export const updateProfileSchema = z.strictObject({
  ...fields, password: password.optional(), current_password: z.string().min(1).max(128).optional(),
}).partial().refine((value) => Object.keys(value).some((key) => key !== 'current_password'))
  .refine((value) => (!value.username && !value.password) || Boolean(value.current_password));

export const employeeIdSchema = z.strictObject({
  id: z.string().regex(/^[1-9][0-9]{0,18}$/)
    .pipe(z.string().refine((value) => BigInt(value) <= 9223372036854775807n)),
});
export const listEmployeesSchema = z.strictObject({
  page: z.string().regex(/^[1-9][0-9]{0,5}$/).default('1').transform(Number),
  limit: z.string().regex(/^[1-9][0-9]{0,2}$/).default('20').transform(Number)
    .refine((value) => value <= 100),
  status_aktif: z.enum(['0', '1']).optional(),
});

export type AccountChanges = z.infer<typeof updateEmployeeSchema>;
export function parseInput<T>(schema: z.ZodType<T>, input: unknown): T {
  const result = schema.safeParse(input);
  if (!result.success) throw new ApiError(400, 'VALIDATION_ERROR', 'Input tidak sesuai kontrak API.');
  return result.data;
}
