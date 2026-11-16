import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { emptyQuerySchema, parseInput } from '../../common/validation.js';

export function registerMe(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/auth/me', { preHandler: requirePermission(db, undefined, clock) }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { sessionId: _sessionId, ...user } = request.principal!;
    return { data: user };
  });
}
