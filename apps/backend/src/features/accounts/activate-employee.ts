import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { ApiError } from '../../common/errors.js';
import { employeeIdSchema, parseInput } from './contracts.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { getAccount } from './store.js';

export function registerActivateEmployee(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/employees/:id/activate', {
    preHandler: requirePermission(db, 'pegawai:manage', clock),
  }, async (request, reply) => {
    const { id } = parseInput(employeeIdSchema, request.params);
    if (request.body !== undefined) throw new ApiError(400, 'VALIDATION_ERROR', 'Endpoint ini tidak menerima body.');
    await authenticatedWrite(db, request.headers.authorization, 'pegawai:manage', clock, async (tx) => {
      await getAccount(tx, id, 'pegawai');
      await tx.execute({ sql: 'UPDATE users SET status_aktif=1 WHERE id_user=?', args: [id] });
    });
    return reply.code(204).send();
  });
}
