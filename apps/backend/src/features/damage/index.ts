import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  createDamageSchema,
  emptyQuerySchema,
  idParamSchema,
  listDamageQuerySchema,
  parseInput,
  updateDamageSchema,
} from './contracts.js';
import { getDamage, listDamages } from './store.js';
import { damageWrite } from './write.js';

export function registerDamage(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'budidaya:read', clock);
  const write = requirePermission(db, 'budidaya:write', clock);

  app.post('/api/v1/kerusakan', { preHandler: write }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createDamageSchema, request.body);
    const result = await damageWrite(db, request, clock, { action: 'create', input });
    return reply
      .code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/kerusakan/${result.data.id_kerusakan}`)
      .send(result);
  });

  app.get('/api/v1/kerusakan', { preHandler: read }, async (request) => {
    const query = parseInput(listDamageQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listDamages(tx, query);
    } finally {
      tx.close();
    }
  });

  app.get('/api/v1/kerusakan/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getDamage(db, id) };
  });

  app.patch('/api/v1/kerusakan/:id', { preHandler: write }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateDamageSchema, request.body);
    return damageWrite(db, request, clock, { action: 'update', id, input });
  });
}
