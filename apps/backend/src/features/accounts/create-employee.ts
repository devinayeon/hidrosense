import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { hashPassword } from '../../common/passwords.js';
import { ApiError } from '../../common/errors.js';
import { createEmployeeSchema, parseInput } from './contracts.js';
import { accountWrite, assertUsernameAvailable, getAccount } from './store.js';

export function registerCreateEmployee(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/employees', { preHandler: requirePermission(db, 'pegawai:manage', clock) }, async (request, reply) => {
    const input = parseInput(createEmployeeSchema, request.body);
    const passwordHash = await hashPassword(input.password);
    const data = await accountWrite(db, request.headers.authorization, 'pegawai:manage', clock, async (tx) => {
      await assertUsernameAvailable(tx, input.username);
      const role = (await tx.execute("SELECT id_role FROM roles WHERE nama_role='pegawai'")).rows[0];
      if (!role) throw new ApiError(503, 'NOT_READY', 'Role pegawai belum tersedia.');
      const result = await tx.execute({
        sql: `INSERT INTO users (id_role,nama,username,password,email,no_telepon,alamat)
          VALUES (?,?,?,?,?,?,?) RETURNING CAST(id_user AS TEXT) AS id_user`,
        args: [role.id_role, input.nama, input.username, passwordHash,
          input.email ?? null, input.no_telepon ?? null, input.alamat ?? null],
      });
      return getAccount(tx, String(result.rows[0].id_user), 'pegawai');
    });
    return reply.code(201).header('location', `/api/v1/employees/${data.id_user}`).send({ data });
  });
}
