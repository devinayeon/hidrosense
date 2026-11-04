import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { sweepExpiredAuthRecords } from '../../common/maintenance.js';
import { verifyPassword } from '../../common/passwords.js';
import { createSession } from '../../common/sessions.js';
import { consumeLimit } from '../../common/rate-limit.js';
import { parseInput } from '../../common/validation.js';
import { loginSchema } from './contracts.js';

export function registerLogin(app: FastifyInstance, db: Client, clock: () => number) {
  app.post('/api/v1/auth/login', async (request, reply) => {
    const { username, password } = parseInput(loginSchema, request.body);
    // Keyed per source IP and exact username: usernames are case-sensitive, so
    // 'Petani' and 'petani' are two accounts and must not share a bucket.
    // Accepted ceiling: an account has no cross-IP cap, so distributed guessing is bounded
    // only by the 120/minute IP quota. An account-wide cap would bring back the lockout.
    await consumeLimit(db, `login:${request.ip}:${username}`, 10, 15 * 60 * 1000, clock(), reply);
    const user = (await db.execute({
      // Preserve SQLite 64-bit IDs as strings throughout the authentication path.
      sql: 'SELECT CAST(id_user AS TEXT) AS id_user,username,password,status_aktif FROM users WHERE username=?', args: [username],
    })).rows[0];
    const valid = await verifyPassword(password, user ? String(user.password) : '');
    if (!valid || !user || user.status_aktif !== 1) {
      throw new ApiError(401, 'INVALID_CREDENTIALS', 'Username atau password tidak valid.');
    }
    const session = await createSession(db, user, clock());
    await sweepExpiredAuthRecords(db, clock(), request.log);
    return { data: session };
  });
}
