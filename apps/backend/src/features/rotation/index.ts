import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  acceptSchema,
  createRecommendationSchema,
  emptyQuerySchema,
  idParamSchema,
  listRecommendationQuerySchema,
  parseInput,
  rejectSchema,
} from './contracts.js';
import { getRecommendation, listRecommendations } from './store.js';
import { rotationWrite } from './write.js';

/**
 * Rekomendasi rotasi obat per meja. Status berubah satu arah (menunggu → diterima atau ditolak),
 * jadi mengulang keputusan yang sama aman dan keputusan berbeda ditolak 409.
 */
export function registerRotation(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'rekomendasi:read', clock);
  const create = requirePermission(db, 'deteksi:write', clock);
  const decide = requirePermission(db, 'rekomendasi:decide', clock);

  app.post('/api/v1/rekomendasi-obat', { preHandler: create }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createRecommendationSchema, request.body);
    const result = await rotationWrite(db, request, clock, { action: 'create', input });
    const { created, ...body } = result;
    return reply
      .code(created ? 201 : 200)
      .header('location', `/api/v1/rekomendasi-obat/${result.data.id_rekomendasi}`)
      .send(body);
  });

  app.get('/api/v1/rekomendasi-obat', { preHandler: read }, async (request) => {
    const query = parseInput(listRecommendationQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listRecommendations(tx, query);
    } finally {
      tx.close();
    }
  });

  app.get('/api/v1/rekomendasi-obat/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getRecommendation(db, id) };
  });

  app.post('/api/v1/rekomendasi-obat/:id/terima', { preHandler: decide }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(acceptSchema, request.body ?? {});
    return rotationWrite(db, request, clock, { action: 'accept', id, input });
  });

  app.post('/api/v1/rekomendasi-obat/:id/tolak', { preHandler: decide }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(rejectSchema, request.body ?? {});
    return rotationWrite(db, request, clock, { action: 'reject', id, input });
  });
}
