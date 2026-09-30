import type { Client } from '@libsql/client';
import type { FastifyReply } from 'fastify';
import { tokenHash } from './sessions.js';
import { ApiError } from './errors.js';

export async function consumeLimit(db: Client, key: string, max: number, windowMs: number, now: number, reply: FastifyReply) {
  const result = await db.execute({
    sql: `INSERT INTO auth_rate_limits (bucket_key,hits,resets_at) VALUES (?,1,?)
      ON CONFLICT(bucket_key) DO UPDATE SET
        hits=CASE WHEN resets_at<=? THEN 1 ELSE hits+1 END,
        resets_at=CASE WHEN resets_at<=? THEN excluded.resets_at ELSE resets_at END
      RETURNING hits,resets_at`,
    args: [tokenHash(key), now + windowMs, now, now],
  });
  const bucket = result.rows[0];
  if (Number(bucket.hits) > max) {
    reply.header('retry-after', String(Math.max(1, Math.ceil((Number(bucket.resets_at) - now) / 1000))));
    throw new ApiError(429, 'RATE_LIMITED', 'Terlalu banyak permintaan. Coba kembali nanti.');
  }
}
