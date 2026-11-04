import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import {
  createDetectionSchema, emptyQuerySchema, idParamSchema, listDetectionQuerySchema, parseInput, updateDetectionSchema,
} from './contracts.js';
import { getDetection, listDetections } from './store.js';
import { detectionWrite } from './write.js';

export function registerDetections(app: FastifyInstance, db: Client, clock: () => number) {
  const read = requirePermission(db, 'deteksi:read', clock);
  const write = requirePermission(db, 'deteksi:write', clock);

  app.post('/api/v1/deteksi', { preHandler: write }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createDetectionSchema, request.body);
    const result = await detectionWrite(db, request, clock, { action: 'create', input });
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/deteksi/${result.data.id_deteksi}`).send(result);
  });

  app.get('/api/v1/deteksi', { preHandler: read }, async (request) => {
    const query = parseInput(listDetectionQuerySchema, request.query);
    const tx = await db.transaction('read');
    try { return await listDetections(tx, query); } finally { tx.close(); }
  });

  app.get('/api/v1/deteksi/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const tx = await db.transaction('read');
    try { return { data: await getDetection(tx, id) }; } finally { tx.close(); }
  });

  app.patch('/api/v1/deteksi/:id', { preHandler: write }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateDetectionSchema, request.body);
    return detectionWrite(db, request, clock, { action: 'update', id, input });
  });
}
