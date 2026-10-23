import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  createSaleSchema,
  emptyQuerySchema,
  idParamSchema,
  listSalesQuerySchema,
  parseInput,
  updateSaleSchema,
} from './contracts.js';
import { getSale, listSales } from './store.js';
import { salesWrite } from './write.js';

export function registerSales(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'penjualan:read', clock);
  const write = requirePermission(db, 'penjualan:write', clock);

  app.post('/api/v1/penjualan', { preHandler: write, bodyLimit: 64 * 1024 }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createSaleSchema, request.body);
    const result = await salesWrite(db, request, clock, { action: 'create', input });
    return reply
      .code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/penjualan/${result.data.id_penjualan}`)
      .send(result);
  });

  app.get('/api/v1/penjualan', { preHandler: read }, async (request) => {
    const query = parseInput(listSalesQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listSales(tx, query);
    } finally {
      tx.close();
    }
  });

  app.get('/api/v1/penjualan/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return { data: await getSale(tx, id) };
    } finally {
      tx.close();
    }
  });

  app.patch('/api/v1/penjualan/:id', { preHandler: write, bodyLimit: 64 * 1024 }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateSaleSchema, request.body);
    return salesWrite(db, request, clock, { action: 'update', id, input });
  });
}
