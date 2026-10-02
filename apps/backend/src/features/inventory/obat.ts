import type { FastifyInstance } from 'fastify';
import type { Client, InValue } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { createObatSchema, updateObatSchema, idParamSchema, listQuerySchema, parseInput } from './contracts.js';
import { getObat, obatResponse, syncColumns } from './store.js';
import { inventoryWrite } from './write.js';

export function registerObat(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  app.post('/api/v1/obat', { preHandler: writeGuard }, async (request, reply) => {
    const input = parseInput(createObatSchema, request.body);
    const result = await inventoryWrite(db, request, clock, 'obat.create', input, async (tx) => {
      const inserted = await tx.execute({
        sql: `INSERT INTO obat (nama_obat,jenis_obat,dosis,aturan_penggunaan,deskripsi)
          VALUES (?,?,?,?,?) RETURNING CAST(id_obat AS TEXT) AS id_obat`,
        args: [input.nama_obat, input.jenis_obat ?? null, input.dosis ?? null,
          input.aturan_penggunaan ?? null, input.deskripsi ?? null],
      });
      return getObat(tx, String(inserted.rows[0].id_obat));
    });
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/obat/${result.data.id_obat}`).send(result);
  });

  app.get('/api/v1/obat', { preHandler: readGuard }, async (request) => {
    const { page, limit, status_aktif } = parseInput(listQuerySchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const [count, records] = await db.batch([
      { sql: 'SELECT COUNT(*) AS total FROM obat WHERE (? IS NULL OR status_aktif=?)', args: [filter, filter] },
      { sql: `SELECT CAST(id_obat AS TEXT) AS id_obat,nama_obat,jenis_obat,dosis,aturan_penggunaan,deskripsi,status_aktif,${syncColumns('obat', 'obat.id_obat')} FROM obat
          WHERE (? IS NULL OR status_aktif=?) ORDER BY obat.id_obat LIMIT ? OFFSET ?`,
        args: [filter, filter, limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(obatResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });

  app.get('/api/v1/obat/:id', { preHandler: readGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getObat(db, id) };
  });

  app.patch('/api/v1/obat/:id', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateObatSchema, request.body);
    return inventoryWrite(db, request, clock, 'obat.update', { id, input }, async (tx) => {
      await getObat(tx, id);
      const assignments: string[] = [];
      const args: InValue[] = [];
      for (const field of ['nama_obat', 'jenis_obat', 'dosis', 'aturan_penggunaan', 'deskripsi'] as const) {
        if (field in input) { assignments.push(`${field}=?`); args.push(input[field] ?? null); }
      }
      args.push(id);
      await tx.execute({ sql: `UPDATE obat SET ${assignments.join(',')} WHERE id_obat=?`, args });
      return getObat(tx, id);
    });
  });

  app.post('/api/v1/obat/:id/deactivate', { preHandler: writeGuard }, async (request) => {
    const { id } = parseInput(idParamSchema, request.params);
    return inventoryWrite(db, request, clock, 'obat.deactivate', { id }, async (tx) => {
      await getObat(tx, id);
      await tx.execute({ sql: 'UPDATE obat SET status_aktif=0 WHERE id_obat=?', args: [id] });
      return getObat(tx, id);
    });
  });
}
