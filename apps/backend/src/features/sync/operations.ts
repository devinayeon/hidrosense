import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requirePermission } from '../../common/authorization.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { reserveClientId } from '../../common/sync.js';
import { clientUuidSchema, parseInput, uuidSchema } from '../../common/validation.js';

const schema = z.strictObject({
  operation_key: uuidSchema,
  operation_type: z.literal('sync.reserve-id'),
  payload: z.strictObject({}),
  resource_type: z.string().regex(/^[a-z][a-z0-9_.-]*$/).max(80),
  client_id: clientUuidSchema,
});

export function registerSyncOperations(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/sync/operations', { preHandler: requirePermission(db, undefined, clock) }, async (request, reply) => {
    const input = parseInput(schema, request.body);
    const result = await authenticatedWrite(db, request.headers.authorization, undefined, clock,
      (tx, actor) => reserveClientId(tx, actor.id_user, input, clock()));
    return reply.code(result.replayed ? 200 : 201).send(result);
  });
}
