import type { FastifyInstance } from 'fastify';
import type { Client, InValue } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { createInventarisSchema, updateInventarisSchema, idParamSchema, listQuerySchema, parseInput } from './contracts.js';
import { assertJenisExists, assertObatExists, getInventaris, inventarisResponse, inventarisColumns } from './store.js';
import { inventoryWrite } from './write.js';
import { ApiError } from '../../common/errors.js';
import { toMinor } from '../../common/quantities.js';

export function registerInventaris(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  app.post('/api/v1/inventaris', { preHandler: writeGuard }, async (request, reply) => {
    const input = parseInput(createInventarisSchema, request.body);
    const result = await inventoryWrite(db, request, clock, 'inventaris.create', input, async (tx) => {
      await assertJenisExists(tx, input.id_jenis_inventaris);
      if (input.id_obat != null) await assertObatExists(tx, input.id_obat);
      const inserted = await tx.execute({
        sql: `INSERT INTO inventaris (id_jenis_inventaris,id_obat,nama_barang,satuan,stok_minimum,stok_minimum_minor)
          VALUES (?,?,?,?,?,?) RETURNING CAST(id_inventaris AS TEXT) AS id_inventaris`,
        args: [input.id_jenis_inventaris, input.id_obat ?? null, input.nama_barang, input.satuan,
          input.stok_minimum ?? null, input.stok_minimum == null ? null : toMinor(input.stok_minimum)],
      });
      return getInventaris(tx, String(inserted.rows[0].id_inventaris));
    });
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/inventaris/${result.data.id_inventaris}`).send(result);
  });

  app.get('/api/v1/inventaris', { preHandler: readGuard }, async (request) => {
    const { page, limit, status_aktif } = parseInput(listQuerySchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const [count, records] = await db.batch([
      { sql: `SELECT COUNT(*) AS total FROM inventaris i WHERE (? IS NULL OR i.status_aktif=?)`, args: [filter, filter] },
      { sql: `SELECT ${inventarisColumns} FROM inventaris i
          JOIN jenis_inventaris j ON j.id_jenis_inventaris=i.id_jenis_inventaris LEFT JOIN obat o ON o.id_obat=i.id_obat
          LEFT JOIN stok_saldo b ON b.id_inventaris=i.id_inventaris
          WHERE (? IS NULL OR i.status_aktif=?) ORDER BY i.id_inventaris LIMIT ? OFFSET ?`,
        args: [filter, filter, limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(inventarisResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });

  app.get('/api/v1/inventaris/:id', { preHandler: readGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getInventaris(db, id) };
  });

  app.patch('/api/v1/inventaris/:id', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateInventarisSchema, request.body);
    return inventoryWrite(db, request, clock, 'inventaris.update', { id, input }, async (tx) => {
      const current = await getInventaris(tx, id);
      if (input.satuan !== undefined && input.satuan !== current.satuan) {
        const history = await tx.execute({ sql: 'SELECT 1 FROM detail_stok WHERE id_inventaris=? LIMIT 1', args: [id] });
        if (history.rows.length) throw new ApiError(409, 'UNIT_LOCKED', 'Satuan barang sudah digunakan dalam histori stok.');
      }
      if (input.id_jenis_inventaris !== undefined) await assertJenisExists(tx, input.id_jenis_inventaris);
      if (input.id_obat != null) await assertObatExists(tx, input.id_obat);
      const assignments: string[] = [];
      const args: InValue[] = [];
      for (const field of ['id_jenis_inventaris', 'id_obat', 'nama_barang', 'satuan', 'stok_minimum'] as const) {
        if (field in input) { assignments.push(`${field}=?`); args.push(input[field] ?? null); }
      }
      if ('stok_minimum' in input) {
        assignments.push('stok_minimum_minor=?');
        args.push(input.stok_minimum == null ? null : toMinor(input.stok_minimum));
      }
      args.push(id);
      await tx.execute({ sql: `UPDATE inventaris SET ${assignments.join(',')} WHERE id_inventaris=?`, args });
      return getInventaris(tx, id);
    });
  });

  app.post('/api/v1/inventaris/:id/deactivate', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return inventoryWrite(db, request, clock, 'inventaris.deactivate', { id }, async (tx) => {
      await getInventaris(tx, id);
      await tx.execute({ sql: 'UPDATE inventaris SET status_aktif=0 WHERE id_inventaris=?', args: [id] });
      return getInventaris(tx, id);
    });
  });
}
