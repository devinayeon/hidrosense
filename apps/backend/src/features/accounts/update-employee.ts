import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { hashPassword, verifyPassword } from '../../common/passwords.js';
import { ApiError } from '../../common/errors.js';
import { emptyQuerySchema, employeeIdSchema, parseInput, updateEmployeeSchema } from './contracts.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { assertEmailAvailable, assertUsernameAvailable, getAccount, updateAccount } from './store.js';

export function registerUpdateEmployee(app: FastifyInstance, db: Client, clock: () => number) {
  app.patch('/api/v1/employees/:id', { preHandler: requirePermission(db, 'pegawai:manage', clock) }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(employeeIdSchema, request.params);
    const input = parseInput(updateEmployeeSchema, request.body);
    const passwordHash = input.password ? await hashPassword(input.password) : undefined;
    const data = await authenticatedWrite(db, request.headers.authorization, 'pegawai:manage', clock, async (tx) => {
      const existing = await getAccount(tx, id, 'pegawai');
      if (existing.status_aktif === 0) {
        throw new ApiError(409, 'ACCOUNT_DEACTIVATED', 'Akun pegawai sedang dinonaktifkan. Aktifkan kembali akun terlebih dahulu.');
      }
      if (input.password) {
        // Password baru yang identik dengan yang lama tidak mengubah apa pun;
        // tolak supaya petani tidak mengira password sudah diganti.
        const row = (await tx.execute({ sql: 'SELECT password FROM users WHERE id_user=?', args: [id] })).rows[0];
        if (row && await verifyPassword(input.password, String(row.password))) {
          throw new ApiError(400, 'PASSWORD_UNCHANGED', 'Password baru tidak boleh sama dengan password lama.');
        }
      }
      if (input.username !== undefined) await assertUsernameAvailable(tx, input.username, id);
      await assertEmailAvailable(tx, input.email, id);
      await updateAccount(tx, id, input, passwordHash, clock());
      return getAccount(tx, id, 'pegawai');
    });
    return { data };
  });
}
