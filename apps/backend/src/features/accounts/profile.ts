import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { hashPassword, verifyPassword } from '../../common/passwords.js';
import { ApiError } from '../../common/errors.js';
import { emptyBodySchema, emptyQuerySchema, parseInput, updateProfileSchema } from './contracts.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { assertEmailAvailable, assertUsernameAvailable, getAccountById, updateAccount } from './store.js';

export function registerProfile(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/profile', { preHandler: requirePermission(db, 'profil:read', clock) }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    return { data: await getAccountById(db, request.principal!.id_user) };
  });
  app.patch('/api/v1/profile', { preHandler: requirePermission(db, 'profil:write', clock) }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(updateProfileSchema, request.body);
    const id = request.principal!.id_user;
    let verifiedHash: string | undefined;
    if (input.username !== undefined || input.password !== undefined) {
      const row = (await db.execute({ sql: 'SELECT password FROM users WHERE id_user=?', args: [id] })).rows[0];
      verifiedHash = row ? String(row.password) : '';
      if (!await verifyPassword(input.current_password!, verifiedHash)) {
        throw new ApiError(403, 'CURRENT_PASSWORD_INVALID', 'Password saat ini tidak sesuai.');
      }
      // Password baru yang identik dengan yang lama ditolak di sini; klien juga
      // memperingatkan lebih dulu, ini penjaga terakhirnya.
      if (input.password !== undefined && await verifyPassword(input.password, verifiedHash)) {
        throw new ApiError(400, 'PASSWORD_UNCHANGED', 'Password baru tidak boleh sama dengan password lama.');
      }
    }
    const passwordHash = input.password ? await hashPassword(input.password) : undefined;
    const data = await authenticatedWrite(db, request.headers.authorization, 'profil:write', clock, async (tx, actor) => {
      if (verifiedHash !== undefined) {
        const row = (await tx.execute({ sql: 'SELECT password FROM users WHERE id_user=?', args: [actor.id_user] })).rows[0];
        if (row.password !== verifiedHash) throw new ApiError(409, 'ACCOUNT_CHANGED', 'Akun berubah; ulangi setelah login.');
      }
      if (input.username !== undefined) await assertUsernameAvailable(tx, input.username, actor.id_user);
      await assertEmailAvailable(tx, input.email, actor.id_user);
      await updateAccount(tx, actor.id_user, input, passwordHash, clock());
      return getAccountById(tx, actor.id_user);
    });
    return { data };
  });
}

/** Pegawai menonaktifkan akunnya sendiri dari halaman Profil. Hanya peran yang
 *  punya `profil:deactivate` (pegawai) yang boleh; sesi server ikut dicabut. */
export function registerDeactivateSelf(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/profile/deactivate', {
    preHandler: requirePermission(db, 'profil:deactivate', clock),
  }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    parseInput(emptyBodySchema, request.body);
    await authenticatedWrite(db, request.headers.authorization, 'profil:deactivate', clock, async (tx, actor) => {
      await tx.execute({ sql: 'UPDATE users SET status_aktif=0,updated_at=? WHERE id_user=?', args: [clock(), actor.id_user] });
      await tx.execute({ sql: 'DELETE FROM auth_sessions WHERE id_user=?', args: [actor.id_user] });
    });
    return reply.code(204).send();
  });
}
