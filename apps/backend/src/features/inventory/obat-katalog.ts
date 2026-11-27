import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { pageQuerySchema } from '../../common/validation.js';
import { parseInput } from './contracts.js';
import { katalogResponse } from './store.js';

/**
 * Katalog obat bawaan (`obat_katalog`) untuk dropdown barang jenis Obat.
 *
 * Katalog ini juga dipakai mesin rekomendasi rotasi; endpoint terpisah menjaga
 * halaman inventaris tidak perlu membaca tabel rekomendasi.
 */
export function registerObatKatalog(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/obat-katalog', {
    preHandler: requirePermission(db, 'inventaris:read', clock),
  }, async (request) => {
    const { page, limit } = parseInput(pageQuerySchema, request.query);
    const [count, records] = await db.batch([
      { sql: 'SELECT COUNT(*) AS total FROM obat_katalog', args: [] },
      { sql: `SELECT CAST(id_katalog AS TEXT) AS id_katalog,bahan_aktif,jenis,kode_moa,phi_hari
          FROM obat_katalog ORDER BY id_katalog LIMIT ? OFFSET ?`,
        args: [limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return {
      data: records.rows.map(katalogResponse),
      meta: { page, limit, total, total_pages: Math.ceil(total / limit) },
    };
  });
}