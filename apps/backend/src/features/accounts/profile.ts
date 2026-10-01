import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { hashPassword, verifyPassword } from '../../common/passwords.js';
import { ApiError } from '../../common/errors.js';
import { parseInput, updateProfileSchema } from './contracts.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { assertUsernameAvailable, getAccount, updateAccount } from './store.js';

export function registerProfile(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/profile', { preHandler: requirePermission(db, 'profil:read', clock) }, async (request) => {
    return { data: await getAccount(db, request.principal!.id_user, 'petani') };
  });
  app.patch('/api/v1/profile', { preHandler: requirePermission(db, 'profil:write', clock) }, async (request) => {
    const input = parseInput(updateProfileSchema, request.body);
    const id = request.principal!.id_user;
    let verifiedHash: string | undefined;
    if (input.username !== undefined || input.password !== undefined) {
      const row = (await db.execute({ sql: 'SELECT password FROM users WHERE id_user=?', args: [id] })).rows[0];
      verifiedHash = row ? String(row.password) : '';
      if (!await verifyPassword(input.current_password!, verifiedHash)) {
        throw new ApiError(403, 'CURRENT_PASSWORD_INVALID', 'Password saat ini tidak sesuai.');
      }
    }
    const passwordHash = input.password ? await hashPassword(input.password) : undefined;
    const data = await authenticatedWrite(db, request.headers.authorization, 'profil:write', clock, async (tx, actor) => {
      if (verifiedHash !== undefined) {
        const row = (await tx.execute({ sql: 'SELECT password FROM users WHERE id_user=?', args: [actor.id_user] })).rows[0];
        if (row.password !== verifiedHash) throw new ApiError(409, 'ACCOUNT_CHANGED', 'Akun berubah; ulangi setelah login.');
      }
      if (input.username !== undefined) await assertUsernameAvailable(tx, input.username, actor.id_user);
      await updateAccount(tx, actor.id_user, input, passwordHash);
      return getAccount(tx, actor.id_user, 'petani');
    });
    return { data };
  });
}
