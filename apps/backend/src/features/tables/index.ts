import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import { createTableSchema, updateTableSchema, listTableSchema, emptyQuerySchema, idParamSchema, parseInput } from './contracts.js';
import { getTable, listTables } from './store.js';
import { tableWrite } from './write.js';

export function registerTables(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'budidaya:read', clock);
  const write = requirePermission(db, 'budidaya:write', clock);
  app.post('/api/v1/meja-tanam', { preHandler: write }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createTableSchema, request.body);
    const result = await tableWrite(db, request, clock, { action: 'create', input });
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/meja-tanam/${result.data.id_meja}`).send(result);
  });
  app.get('/api/v1/meja-tanam', { preHandler: read }, async (request) => {
    const query = parseInput(listTableSchema, request.query);
    const tx = await db.transaction('read');
    try { return await listTables(tx, query); } finally { tx.close(); }
  });
  app.get('/api/v1/meja-tanam/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getTable(db, id) };
  });
  app.patch('/api/v1/meja-tanam/:id', { preHandler: write }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateTableSchema, request.body);
    return tableWrite(db, request, clock, { action: 'update', id, input });
  });
}
