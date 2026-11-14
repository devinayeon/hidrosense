import { z } from 'zod';
import { activeListQuerySchema, idParamSchema, newPasswordSchema, usernameSchema } from '../../common/validation.js';
export { emptyQuerySchema, parseInput } from '../../common/validation.js';

const fields = {
  nama: z.string().trim().min(1).max(100),
  username: usernameSchema,
  email: z.string().trim().max(100).email().nullable().optional(),
  // Minimal satu angka: "---" atau "+" lolos pola karakter tetapi bukan nomor telepon.
  no_telepon: z.string().trim().min(1).max(20).regex(/^\+?[0-9 ()-]+$/).regex(/[0-9]/).nullable().optional(),
  alamat: z.string().trim().min(1).max(1000).nullable().optional(),
};
const password = newPasswordSchema;
/** Aktivasi dan penonaktifan tidak punya body; klien HTTP umum tetap mengirim `{}` atau body kosong. */
export const emptyBodySchema = z.strictObject({}).optional();
export const createEmployeeSchema = z.strictObject({ ...fields, password });
export const updateEmployeeSchema = z.strictObject({
  ...fields, password: password.optional(),
}).partial().refine((value) => Object.keys(value).length > 0);
export const updateProfileSchema = z.strictObject({
  ...fields, password: password.optional(), current_password: z.string().min(1).max(128).optional(),
}).partial().refine((value) => Object.keys(value).some((key) => key !== 'current_password'))
  .refine((value) => (!value.username && !value.password) || Boolean(value.current_password));

export const employeeIdSchema = idParamSchema;
export const listEmployeesSchema = activeListQuerySchema.extend({
  q: z.string().trim().max(100).optional(),
});

export type AccountChanges = z.infer<typeof updateEmployeeSchema>;
