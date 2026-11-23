import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import type { AppConfig } from '../../config.js';
import { createScanSchema, emptyQuerySchema, idParamSchema, listScanQuerySchema, parseInput } from './contracts.js';
import { getScan, listScans } from './store.js';
import { scanWrite } from './write.js';

/** Hasil pindai foto: satu foto Cloudinary dan hitungan hama per kelas. */
export function registerScans(app: FastifyInstance, db: Client, clock: () => number, config: AppConfig) {
  const read = requirePermission(db, 'deteksi:read', clock);
  const write = requirePermission(db, 'deteksi:write', clock);

  app.post('/api/v1/pindaian', { preHandler: write }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createScanSchema, request.body);
    const result = await scanWrite(db, request, clock, config, input);
    return reply
      .code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/pindaian/${result.data.id_hasil_deteksi}`)
      .send(result);
  });

  app.get('/api/v1/pindaian', { preHandler: read }, async (request) => {
    const query = parseInput(listScanQuerySchema, request.query);
    const tx = await db.transaction('read');
    try {
      return await listScans(tx, query);
    } finally {
      tx.close();
    }
  });

  app.get('/api/v1/pindaian/:id', { preHandler: read }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    parseInput(emptyQuerySchema, request.query);
    return { data: await getScan(db, id) };
  });
}
