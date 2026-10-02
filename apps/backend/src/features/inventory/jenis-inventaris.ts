import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { createJenisSchema, updateJenisSchema, idParamSchema, listQuerySchema, parseInput } from './contracts.js';
import { assertJenisNameAvailable, getJenis, jenisResponse, syncColumns } from './store.js';
import { inventoryWrite } from './write.js';

export function registerJenisInventaris(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  app.post('/api/v1/jenis-inventaris', { preHandler: writeGuard }, async (request, reply) => {
    const input = parseInput(createJenisSchema, request.body);
    const result = await inventoryWrite(db, request, clock, 'jenis-inventaris.create', input, async (tx) => {
      await assertJenisNameAvailable(tx, input.nama_jenis);
      const inserted = await tx.execute({
        sql: `INSERT INTO jenis_inventaris (nama_jenis) VALUES (?)
          RETURNING CAST(id_jenis_inventaris AS TEXT) AS id_jenis_inventaris`, args: [input.nama_jenis],
      });
      return getJenis(tx, String(inserted.rows[0].id_jenis_inventaris));
    });
    const id = result.data.id_jenis_inventaris;
    return reply.code(result.replayed ? 200 : 201).header('location', `/api/v1/jenis-inventaris/${id}`).send(result);
  });

  app.get('/api/v1/jenis-inventaris', { preHandler: readGuard }, async (request) => {
    const { page, limit, status_aktif } = parseInput(listQuerySchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const [count, records] = await db.batch([
      { sql: 'SELECT COUNT(*) AS total FROM jenis_inventaris WHERE (? IS NULL OR status_aktif=?)', args: [filter, filter] },
      { sql: `SELECT CAST(id_jenis_inventaris AS TEXT) AS id_jenis_inventaris,nama_jenis,status_aktif,${syncColumns('jenis-inventaris', 'jenis_inventaris.id_jenis_inventaris')} FROM jenis_inventaris
          WHERE (? IS NULL OR status_aktif=?) ORDER BY jenis_inventaris.id_jenis_inventaris LIMIT ? OFFSET ?`,
        args: [filter, filter, limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(jenisResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });

  app.get('/api/v1/jenis-inventaris/:id', { preHandler: readGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getJenis(db, id) };
  });

  app.patch('/api/v1/jenis-inventaris/:id', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateJenisSchema, request.body);
    return inventoryWrite(db, request, clock, 'jenis-inventaris.update', { id, input }, async (tx) => {
      await getJenis(tx, id);
      await assertJenisNameAvailable(tx, input.nama_jenis, id);
      await tx.execute({ sql: 'UPDATE jenis_inventaris SET nama_jenis=? WHERE id_jenis_inventaris=?', args: [input.nama_jenis, id] });
      return getJenis(tx, id);
    });
  });

  app.post('/api/v1/jenis-inventaris/:id/deactivate', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return inventoryWrite(db, request, clock, 'jenis-inventaris.deactivate', { id }, async (tx) => {
      await getJenis(tx, id);
      await tx.execute({ sql: 'UPDATE jenis_inventaris SET status_aktif=0 WHERE id_jenis_inventaris=?', args: [id] });
      return getJenis(tx, id);
    });
  });
}
