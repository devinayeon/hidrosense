import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  createTransferSchema,
  emptyQuerySchema,
  idParamSchema,
  listTransferQuerySchema,
  parseInput,
  updateTransferSchema,
} from './contracts.js';
import { getTransfer, listTransfers } from './store.js';
import { transferWrite } from './write.js';

export function registerTransfers(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'budidaya:read', clock);
  const write = requirePermission(db, 'budidaya:write', clock);

  app.post('/api/v1/pemindahan', { preHandler: write }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createTransferSchema, request.body);
    const result = await transferWrite(db, request, clock, { action: 'create', input });
    return reply
      .code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/pemindahan/${result.data.id_pemindahan}`)
      .send(result);
  });

  app.get('/api/v1/pemindahan', { preHandler: read }, async (request) => {
    const query = parseInput(listTransferQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listTransfers(tx, query, clock());
    } finally {
      tx.close();
    }
  });

  app.get('/api/v1/pemindahan/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getTransfer(db, id, clock()) };
  });

  app.patch('/api/v1/pemindahan/:id', { preHandler: write }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateTransferSchema, request.body);
    return transferWrite(db, request, clock, { action: 'update', id, input });
  });
}
