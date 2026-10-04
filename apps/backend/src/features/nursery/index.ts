import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  createSowingSchema, updateSowingSchema, listSowingQuerySchema, emptyQuerySchema,
  idParamSchema, parseInput,
} from './contracts.js';
import { getSowing, listSowings } from './store.js';
import { createSowing, updateSowing } from './service.js';
import { nurseryWrite } from './write.js';

export function registerNursery(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'penyemaian:read', clock);
  const write = requirePermission(db, 'penyemaian:write', clock);

  // POST /api/v1/penyemaian — create sowing + consume materials (idempotent)
  app.post('/api/v1/penyemaian', { preHandler: write }, async (request, reply) => {
    const input = parseInput(createSowingSchema, request.body);
    parseInput(emptyQuerySchema, request.query);
    const result = await nurseryWrite(db, request, clock, 'penyemaian.create', input,
      (tx, actorId, now) => createSowing(tx, actorId, now, input));
    return reply
      .code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/penyemaian/${result.data.id_penyemaian}`)
      .send(result);
  });

  // GET /api/v1/penyemaian — paginated list with optional filters
  app.get('/api/v1/penyemaian', { preHandler: read }, async (request) => {
    const query = parseInput(listSowingQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listSowings(tx, query, clock());
    } finally {
      tx.close();
    }
  });

  // GET /api/v1/penyemaian/:id — detail with age, readiness, and consumed stock
  app.get('/api/v1/penyemaian/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getSowing(db, id, clock()) };
  });

  // PATCH /api/v1/penyemaian/:id — update jumlah_benih, status, keterangan (idempotent)
  app.patch('/api/v1/penyemaian/:id', { preHandler: write }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateSowingSchema, request.body);
    parseInput(emptyQuerySchema, request.query);
    const result = await nurseryWrite(db, request, clock, 'penyemaian.update', { id, ...input },
      (tx, _actorId, now) => updateSowing(tx, id, input, now));
    return result;
  });
}
