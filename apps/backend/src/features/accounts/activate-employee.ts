import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { emptyBodySchema, emptyQuerySchema, employeeIdSchema, parseInput } from './contracts.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { getAccount } from './store.js';

export function registerActivateEmployee(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/employees/:id/activate', {
    preHandler: requirePermission(db, 'pegawai:manage', clock),
  }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(employeeIdSchema, request.params);
    parseInput(emptyBodySchema, request.body);
    await authenticatedWrite(db, request.headers.authorization, 'pegawai:manage', clock, async (tx) => {
      await getAccount(tx, id, 'pegawai');
      await tx.execute({ sql: 'UPDATE users SET status_aktif=1,updated_at=? WHERE id_user=?', args: [clock(), id] });
    });
    return reply.code(204).send();
  });
}
