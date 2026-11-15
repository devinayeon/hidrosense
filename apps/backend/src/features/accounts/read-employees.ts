import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { emptyQuerySchema, employeeIdSchema, listEmployeesSchema, parseInput } from './contracts.js';
import { accountColumns, accountResponse, getAccount } from './store.js';

/** Pencarian tidak membedakan huruf besar kecil, juga untuk é, dan é yang disusun dua kodepoin sama dengan satu. */
const fold = (text: string) => text.normalize('NFC').toLowerCase().normalize('NFC');

export function registerReadEmployees(app: FastifyInstance, db: Client, clock: () => number) {
  const preHandler = requirePermission(db, 'pegawai:manage', clock);
  app.get('/api/v1/employees', { preHandler }, async (request) => {
    const { page, limit, status_aktif, q } = parseInput(listEmployeesSchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const where = "r.nama_role='pegawai' AND (? IS NULL OR u.status_aktif=?)";
    if (q) {
      // LIKE di SQLite hanya mengenal huruf besar kecil ASCII dan tidak menyamakan susunan Unicode.
      // Jumlah pegawai satu kebun kecil, jadi pencarian disaring di aplikasi: satu baca, satu
      // gambaran data, dan teks dicari apa adanya (% dan _ bukan wildcard).
      const needle = fold(q);
      const rows = (await db.execute({
        sql: `SELECT ${accountColumns} FROM users u JOIN roles r ON r.id_role=u.id_role
          WHERE ${where} ORDER BY u.id_user`, args: [filter, filter],
      })).rows.filter((row) => fold(String(row.nama)).includes(needle) || fold(String(row.username)).includes(needle));
      return {
        data: rows.slice((page - 1) * limit, page * limit).map(accountResponse),
        meta: { page, limit, total: rows.length, total_pages: Math.ceil(rows.length / limit) },
      };
    }
    // A read batch keeps the count and page in the same database snapshot.
    const [count, records] = await db.batch([
      { sql: `SELECT COUNT(*) AS total FROM users u JOIN roles r ON r.id_role=u.id_role WHERE ${where}`, args: [filter, filter] },
      { sql: `SELECT ${accountColumns} FROM users u JOIN roles r ON r.id_role=u.id_role
          WHERE ${where} ORDER BY u.id_user LIMIT ? OFFSET ?`, args: [filter, filter, limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(accountResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });
  app.get('/api/v1/employees/:id', { preHandler }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(employeeIdSchema, request.params);
    return { data: await getAccount(db, id, 'pegawai') };
  });
}
