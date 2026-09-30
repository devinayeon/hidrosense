import type { FastifyInstance } from 'fastify';
import type { Client } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { ACCESS_TTL_MS, newTokens, tokenHash, tokenPattern, tokenResponse } from '../../common/sessions.js';

export function registerRefresh(app: FastifyInstance, db: Client, clock: () => number) {
  app.post<{ Body: { refresh_token: string } }>('/api/v1/auth/refresh', {
    schema: { body: {
      type: 'object', additionalProperties: false, required: ['refresh_token'],
      properties: { refresh_token: { type: 'string', pattern: tokenPattern } },
    } },
  }, async (request) => {
    const now = clock();
    const tokens = newTokens();
    // One conditional write makes concurrent refresh single-use across processes.
    const result = await db.execute({
      sql: `UPDATE auth_sessions SET access_token_hash=?,refresh_token_hash=?,access_expires_at=MIN(?,refresh_expires_at)
        WHERE refresh_token_hash=? AND refresh_expires_at>?
        AND EXISTS (SELECT 1 FROM users u JOIN roles r ON r.id_role=u.id_role
          WHERE u.id_user=auth_sessions.id_user AND u.status_aktif=1
          AND u.password=auth_sessions.credential_hash AND r.nama_role IN ('petani','pegawai'))
        RETURNING access_expires_at,refresh_expires_at`,
      args: [tokenHash(tokens.access), tokenHash(tokens.refresh), now + ACCESS_TTL_MS, tokenHash(request.body.refresh_token), now],
    });
    const row = result.rows[0];
    if (!row) throw new ApiError(401, 'UNAUTHENTICATED', 'Sesi tidak valid atau kedaluwarsa.');
    return { data: tokenResponse(tokens, Number(row.access_expires_at), Number(row.refresh_expires_at), now) };
  });
}
