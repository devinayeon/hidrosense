import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { verifyPassword } from '../../common/passwords.js';
import { createSession } from '../../common/sessions.js';
import { consumeLimit } from '../../common/rate-limit.js';

export function registerLogin(app: FastifyInstance, db: Client, clock: () => number) {
  app.post<{ Body: { username: string; password: string } }>('/api/v1/auth/login', {
    schema: { body: {
      type: 'object', additionalProperties: false, required: ['username', 'password'],
      properties: {
        username: { type: 'string', minLength: 1, maxLength: 50, pattern: '\\S' },
        password: { type: 'string', minLength: 1, maxLength: 128 },
      },
    } },
  }, async (request, reply) => {
    const { username, password } = request.body;
    await consumeLimit(db, `login:${username.toLowerCase()}`, 10, 15 * 60 * 1000, clock(), reply);
    const user = (await db.execute({
      sql: 'SELECT id_user,password,status_aktif FROM users WHERE username=?', args: [username],
    })).rows[0];
    const valid = await verifyPassword(password, user ? String(user.password) : '');
    if (!valid || !user || user.status_aktif !== 1) {
      throw new ApiError(401, 'INVALID_CREDENTIALS', 'Username atau password tidak valid.');
    }
    return { data: await createSession(db, user, clock()) };
  });
}
