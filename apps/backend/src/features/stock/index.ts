import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import { createStockSchema, reverseStockSchema, historyQuerySchema, emptyQuerySchema,
  idParamSchema, parseInput } from './contracts.js';
import { getBalance, getMovement, listMovements } from './store.js';
import { recordMovement, reverseMovement } from './service.js';
import { stockWrite } from './write.js';

export function registerStock(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'inventaris:read', clock);
  const write = requirePermission(db, 'inventaris:write', clock);
  app.post('/api/v1/stok', { preHandler: write }, async (request, reply) => {
    const input = parseInput(createStockSchema, request.body);
    parseInput(emptyQuerySchema, request.query);
    const result = await stockWrite(db, request, clock, 'stok.create', input,
      (tx, actorId, now) => recordMovement(tx, actorId, now, input));
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/stok/${result.data.id_stok}`).send(result);
  });
  app.post('/api/v1/stok/:id/reverse', { preHandler: write }, async (request, reply) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(reverseStockSchema, request.body);
    parseInput(emptyQuerySchema, request.query);
    const result = await stockWrite(db, request, clock, 'stok.reverse', { id, ...input },
      (tx, actorId, now) => reverseMovement(tx, actorId, now, id, input.keterangan));
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/stok/${result.data.id_stok}`).send(result);
  });
  app.get('/api/v1/stok', { preHandler: read }, async (request) => {
    const query = parseInput(historyQuerySchema, request.query);
    const tx = await db.transaction('read');
    try { return await listMovements(tx, query); }
    finally { tx.close(); }
  });
  app.get('/api/v1/stok/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getMovement(db, id) };
  });
  app.get('/api/v1/inventaris/:id/saldo', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getBalance(db, id) };
  });
}
