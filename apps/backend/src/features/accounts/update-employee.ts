import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { hashPassword } from '../../common/passwords.js';
import { ApiError } from '../../common/errors.js';
import { employeeIdSchema, parseInput, updateEmployeeSchema } from './contracts.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { assertUsernameAvailable, getAccount, updateAccount } from './store.js';

export function registerUpdateEmployee(app: FastifyInstance, db: Client, clock: () => number) {
  app.patch('/api/v1/employees/:id', { preHandler: requirePermission(db, 'pegawai:manage', clock) }, async (request) => {
    const { id } = parseInput(employeeIdSchema, request.params);
    const input = parseInput(updateEmployeeSchema, request.body);
    const passwordHash = input.password ? await hashPassword(input.password) : undefined;
    const data = await authenticatedWrite(db, request.headers.authorization, 'pegawai:manage', clock, async (tx) => {
      const existing = await getAccount(tx, id, 'pegawai');
      if (existing.status_aktif === 0) {
        throw new ApiError(409, 'ACCOUNT_DEACTIVATED', 'Akun pegawai sedang dinonaktifkan. Aktifkan kembali akun terlebih dahulu.');
      }
      if (input.username !== undefined) await assertUsernameAvailable(tx, input.username, id);
      await updateAccount(tx, id, input, passwordHash);
      return getAccount(tx, id, 'pegawai');
    });
    return { data };
  });
}
