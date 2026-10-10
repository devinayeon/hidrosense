import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  createHarvestSchema,
  emptyQuerySchema,
  idParamSchema,
  listHarvestQuerySchema,
  parseInput,
  updateHarvestSchema,
} from './contracts.js';
import { getHarvest, listHarvests } from './store.js';
import { harvestWrite } from './write.js';

export function registerHarvest(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'panen:read', clock);
  const write = requirePermission(db, 'panen:write', clock);

  app.post('/api/v1/panen', { preHandler: write, bodyLimit: 64 * 1024 }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createHarvestSchema, request.body);
    const result = await harvestWrite(db, request, clock, { action: 'create', input });
    return reply
      .code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/panen/${result.data.id_panen}`)
      .send(result);
  });

  app.get('/api/v1/panen', { preHandler: read }, async (request) => {
    const query = parseInput(listHarvestQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listHarvests(tx, query);
    } finally {
      tx.close();
    }
  });

  app.get('/api/v1/panen/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const tx = await db.transaction('read');
    try { return { data: await getHarvest(tx, id) }; } finally { tx.close(); }
  });

  app.patch('/api/v1/panen/:id', { preHandler: write, bodyLimit: 64 * 1024 }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateHarvestSchema, request.body);
    return harvestWrite(db, request, clock, { action: 'update', id, input });
  });
}
