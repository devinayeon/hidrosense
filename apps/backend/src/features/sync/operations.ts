import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requirePermission } from '../../common/authorization.js';
import { ApiError } from '../../common/errors.js';
import { authenticate } from '../../common/sessions.js';
import { replayOperation } from '../../common/sync.js';

const uuid = z.string().uuid();
const schema = z.strictObject({
  operation_key: uuid,
  operation_type: z.string().regex(/^[a-z][a-z0-9_.-]*$/).max(80),
  payload: z.json(),
  resource_type: z.string().regex(/^[a-z][a-z0-9_.-]*$/).max(80).optional(),
  client_id: uuid.optional(),
}).refine((value) => Boolean(value.resource_type) === Boolean(value.client_id));

export function registerSyncOperations(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/sync/operations', { preHandler: requirePermission(db, undefined, clock) }, async (request, reply) => {
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) throw new ApiError(400, 'VALIDATION_ERROR', 'Input tidak sesuai kontrak API.');
    const tx = await db.transaction('write');
    try {
      const principal = await authenticate(tx, request.headers.authorization, clock());
      const result = await replayOperation(tx, principal.id_user, parsed.data, clock());
      await tx.commit();
      return reply.code(result.replayed ? 200 : 201).send(result);
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });
}
