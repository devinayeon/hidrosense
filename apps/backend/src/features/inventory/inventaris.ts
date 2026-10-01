import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import type { InValue } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { authenticate } from '../../common/sessions.js';
import {
  createInventarisSchema, updateInventarisSchema, idParamSchema, listQuerySchema, parseInput,
} from './contracts.js';
import {
  assertJenisExists, assertObatExists,
  getInventaris, inventarisResponse, inventarisColumns,
} from './store.js';

export function registerInventaris(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  // POST /api/v1/inventaris
  app.post('/api/v1/inventaris', { preHandler: writeGuard }, async (request, reply) => {
    const input = parseInput(createInventarisSchema, request.body);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      await assertJenisExists(tx, input.id_jenis_inventaris);
      if (input.id_obat != null) await assertObatExists(tx, input.id_obat);
      const result = await tx.execute({
        sql: `INSERT INTO inventaris (id_jenis_inventaris,id_obat,nama_barang,satuan,stok_minimum)
          VALUES (?,?,?,?,?) RETURNING CAST(id_inventaris AS TEXT) AS id_inventaris`,
        args: [
          input.id_jenis_inventaris,
          input.id_obat ?? null,
          input.nama_barang,
          input.satuan,
          input.stok_minimum ?? null,
        ],
      });
      const id = String(result.rows[0].id_inventaris);
      const data = await getInventaris(tx, id);
      await tx.commit();
      return reply.code(201).header('location', `/api/v1/inventaris/${id}`).send({ data });
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });

  // GET /api/v1/inventaris
  app.get('/api/v1/inventaris', { preHandler: readGuard }, async (request) => {
    const { page, limit, status_aktif } = parseInput(listQuerySchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const [count, records] = await db.batch([
      {
        sql: `SELECT COUNT(*) AS total FROM inventaris i
          JOIN jenis_inventaris j ON j.id_jenis_inventaris=i.id_jenis_inventaris
          LEFT JOIN obat o ON o.id_obat=i.id_obat
          WHERE (? IS NULL OR i.status_aktif=?)`,
        args: [filter, filter],
      },
      {
        sql: `SELECT ${inventarisColumns} FROM inventaris i
          JOIN jenis_inventaris j ON j.id_jenis_inventaris=i.id_jenis_inventaris
          LEFT JOIN obat o ON o.id_obat=i.id_obat
          WHERE (? IS NULL OR i.status_aktif=?) ORDER BY i.id_inventaris LIMIT ? OFFSET ?`,
        args: [filter, filter, limit, (page - 1) * limit],
      },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(inventarisResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });

  // GET /api/v1/inventaris/:id
  app.get('/api/v1/inventaris/:id', { preHandler: readGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getInventaris(db, id) };
  });

  // PATCH /api/v1/inventaris/:id
  app.patch('/api/v1/inventaris/:id', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateInventarisSchema, request.body);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      await getInventaris(tx, id);
      if (input.id_jenis_inventaris !== undefined) await assertJenisExists(tx, input.id_jenis_inventaris);
      if (input.id_obat != null) await assertObatExists(tx, input.id_obat);
      const assignments: string[] = [];
      const args: InValue[] = [];
      for (const field of ['id_jenis_inventaris', 'id_obat', 'nama_barang', 'satuan'] as const) {
        if (field in input) { assignments.push(`${field}=?`); args.push(input[field] ?? null); }
      }
      if ('stok_minimum' in input) { assignments.push('stok_minimum=?'); args.push(input.stok_minimum ?? null); }
      args.push(id);
      await tx.execute({ sql: `UPDATE inventaris SET ${assignments.join(',')} WHERE id_inventaris=?`, args });
      const data = await getInventaris(tx, id);
      await tx.commit();
      return { data };
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });

  // POST /api/v1/inventaris/:id/deactivate
  app.post('/api/v1/inventaris/:id/deactivate', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const tx = await db.transaction('write');
    try {
      await authenticate(tx, request.headers.authorization, clock());
      await getInventaris(tx, id);
      await tx.execute({ sql: 'UPDATE inventaris SET status_aktif=0 WHERE id_inventaris=?', args: [id] });
      const data = await getInventaris(tx, id);
      await tx.commit();
      return { data };
    } catch (error) {
      if (!tx.closed) await tx.rollback();
      throw error;
    } finally { tx.close(); }
  });
}
