import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import type { InValue } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { authenticate } from '../../common/sessions.js';
import { createObatSchema, updateObatSchema, idParamSchema, listQuerySchema, parseInput } from './contracts.js';
import { getObat, obatResponse } from './store.js';

export function registerObat(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  // POST /api/v1/obat
  app.post('/api/v1/obat', { preHandler: writeGuard }, async (request, reply) => {
    const input = parseInput(createObatSchema, request.body);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      const result = await tx.execute({
        sql: `INSERT INTO obat (nama_obat,jenis_obat,dosis,aturan_penggunaan,deskripsi)
          VALUES (?,?,?,?,?) RETURNING CAST(id_obat AS TEXT) AS id_obat`,
        args: [
          input.nama_obat,
          input.jenis_obat ?? null,
          input.dosis ?? null,
          input.aturan_penggunaan ?? null,
          input.deskripsi ?? null,
        ],
      });
      const id = String(result.rows[0].id_obat);
      const data = await getObat(tx, id);
      await tx.commit();
      return reply.code(201).header('location', `/api/v1/obat/${id}`).send({ data });
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });

  // GET /api/v1/obat
  app.get('/api/v1/obat', { preHandler: readGuard }, async (request) => {
    const { page, limit, status_aktif } = parseInput(listQuerySchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const [count, records] = await db.batch([
      { sql: 'SELECT COUNT(*) AS total FROM obat WHERE (? IS NULL OR status_aktif=?)', args: [filter, filter] },
      {
        sql: `SELECT id_obat,nama_obat,jenis_obat,dosis,aturan_penggunaan,deskripsi,status_aktif FROM obat
          WHERE (? IS NULL OR status_aktif=?) ORDER BY id_obat LIMIT ? OFFSET ?`,
        args: [filter, filter, limit, (page - 1) * limit],
      },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(obatResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });

  // GET /api/v1/obat/:id
  app.get('/api/v1/obat/:id', { preHandler: readGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getObat(db, id) };
  });

  // PATCH /api/v1/obat/:id
  app.patch('/api/v1/obat/:id', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateObatSchema, request.body);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      await getObat(tx, id);
      const assignments: string[] = [];
      const args: InValue[] = [];
      for (const field of ['nama_obat', 'jenis_obat', 'dosis', 'aturan_penggunaan', 'deskripsi'] as const) {
        if (field in input) { assignments.push(`${field}=?`); args.push(input[field] ?? null); }
      }
      args.push(id);
      await tx.execute({ sql: `UPDATE obat SET ${assignments.join(',')} WHERE id_obat=?`, args });
      const data = await getObat(tx, id);
      await tx.commit();
      return { data };
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });

  // POST /api/v1/obat/:id/deactivate
  app.post('/api/v1/obat/:id/deactivate', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      await getObat(tx, id);
      await tx.execute({ sql: 'UPDATE obat SET status_aktif=0 WHERE id_obat=?', args: [id] });
      const data = await getObat(tx, id);
      await tx.commit();
      return { data };
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });
}
