import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';

export function registerLogout(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/auth/logout', { preHandler: requirePermission(db, undefined, clock) }, async (request, reply) => {
    await db.execute({ sql: 'DELETE FROM auth_sessions WHERE id_session=?', args: [request.principal!.sessionId] });
    return reply.code(204).send();
  });
}
