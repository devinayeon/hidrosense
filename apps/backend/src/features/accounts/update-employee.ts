import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { hashPassword } from '../../common/passwords.js';
import { employeeIdSchema, parseInput, updateEmployeeSchema } from './contracts.js';
import { accountWrite, assertUsernameAvailable, getAccount, updateAccount } from './store.js';

export function registerUpdateEmployee(app: FastifyInstance, db: Client, clock: () => number) {
  app.patch('/api/v1/employees/:id', { preHandler: requirePermission(db, 'pegawai:manage', clock) }, async (request) => {
    const { id } = parseInput(employeeIdSchema, request.params);
    const input = parseInput(updateEmployeeSchema, request.body);
    const passwordHash = input.password ? await hashPassword(input.password) : undefined;
    const data = await accountWrite(db, request.headers.authorization, 'pegawai:manage', clock, async (tx) => {
      await getAccount(tx, id, 'pegawai');
      if (input.username !== undefined) await assertUsernameAvailable(tx, input.username, id);
      await updateAccount(tx, id, input, passwordHash);
      return getAccount(tx, id, 'pegawai');
    });
    return { data };
  });
}
