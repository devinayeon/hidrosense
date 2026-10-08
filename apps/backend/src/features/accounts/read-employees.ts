import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { employeeIdSchema, listEmployeesSchema, parseInput } from './contracts.js';
import { accountColumns, accountResponse, getAccount } from './store.js';

export function registerReadEmployees(app: FastifyInstance, db: Client, clock: () => number) {
  const preHandler = requirePermission(db, 'pegawai:manage', clock);
  app.get('/api/v1/employees', { preHandler }, async (request) => {
    const { page, limit, status_aktif, q } = parseInput(listEmployeesSchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const search = q ? `%${q}%` : null;
    // A read batch keeps the count and page in the same database snapshot.
    const [count, records] = await db.batch([
      { sql: `SELECT COUNT(*) AS total FROM users u JOIN roles r ON r.id_role=u.id_role
          WHERE r.nama_role='pegawai' AND (? IS NULL OR u.status_aktif=?)
          AND (? IS NULL OR (u.nama LIKE ? OR u.username LIKE ?))`, args: [filter, filter, search, search, search] },
      { sql: `SELECT ${accountColumns} FROM users u JOIN roles r ON r.id_role=u.id_role
          WHERE r.nama_role='pegawai' AND (? IS NULL OR u.status_aktif=?)
          AND (? IS NULL OR (u.nama LIKE ? OR u.username LIKE ?))
          ORDER BY u.id_user LIMIT ? OFFSET ?`, args: [filter, filter, search, search, search, limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(accountResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });
  app.get('/api/v1/employees/:id', { preHandler }, async (request) => {
    const { id } = parseInput(employeeIdSchema, request.params);
    return { data: await getAccount(db, id, 'pegawai') };
  });
}
