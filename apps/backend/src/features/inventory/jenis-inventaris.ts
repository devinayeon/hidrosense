import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { authenticate } from '../../common/sessions.js';
import {
  createJenisSchema, updateJenisSchema, idParamSchema, parseInput,
} from './contracts.js';
import { assertJenisNameAvailable, getJenis, jenisResponse } from './store.js';

export function registerJenisInventaris(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  // POST /api/v1/jenis-inventaris
  app.post('/api/v1/jenis-inventaris', { preHandler: writeGuard }, async (request, reply) => {
    const input = parseInput(createJenisSchema, request.body);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      await assertJenisNameAvailable(tx, input.nama_jenis);
      const result = await tx.execute({
        sql: `INSERT INTO jenis_inventaris (nama_jenis) VALUES (?)
          RETURNING CAST(id_jenis_inventaris AS TEXT) AS id_jenis_inventaris`,
        args: [input.nama_jenis],
      });
      const id = String(result.rows[0].id_jenis_inventaris);
      const data = await getJenis(tx, id);
      await tx.commit();
      return reply.code(201).header('location', `/api/v1/jenis-inventaris/${id}`).send({ data });
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });

  // GET /api/v1/jenis-inventaris
  app.get('/api/v1/jenis-inventaris', { preHandler: readGuard }, async () => {
    const rows = (await db.execute(
      'SELECT id_jenis_inventaris,nama_jenis FROM jenis_inventaris ORDER BY id_jenis_inventaris',
    )).rows;
    return { data: rows.map(jenisResponse) };
  });

  // GET /api/v1/jenis-inventaris/:id
  app.get('/api/v1/jenis-inventaris/:id', { preHandler: readGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getJenis(db, id) };
  });

  // PATCH /api/v1/jenis-inventaris/:id
  app.patch('/api/v1/jenis-inventaris/:id', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateJenisSchema, request.body);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      // Verify jenis exists before uniqueness check.
      await getJenis(tx, id);
      await assertJenisNameAvailable(tx, input.nama_jenis, id);
      await tx.execute({
        sql: 'UPDATE jenis_inventaris SET nama_jenis=? WHERE id_jenis_inventaris=?',
        args: [input.nama_jenis, id],
      });
      const data = await getJenis(tx, id);
      await tx.commit();
      return { data };
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });

  // jenis_inventaris has no status_aktif. Deletion not supported — referenced by inventaris history.
}
