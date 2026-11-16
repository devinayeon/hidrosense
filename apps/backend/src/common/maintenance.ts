import type { Client } from '@libsql/client';
import type { FastifyBaseLogger } from 'fastify';

/** Removes only expired infrastructure records, never domain data. */
export function purgeExpiredAuthRecords(db: Pick<Client, 'batch'>, now: number) {
  return db.batch([
    { sql: 'DELETE FROM auth_sessions WHERE refresh_expires_at<=?', args: [now] },
    { sql: 'DELETE FROM auth_rate_limits WHERE resets_at<=?', args: [now] },
  ], 'write');
}

/**
 * Runs inside login and refresh because a serverless instance can be frozen between requests,
 * so no timer can own this. Cleanup must never cost a user their sign-in.
 */
export async function sweepExpiredAuthRecords(db: Pick<Client, 'batch'>, now: number, log: FastifyBaseLogger) {
  try {
    await purgeExpiredAuthRecords(db, now);
  } catch {
    // Never log the raw error: database errors may contain SQL or connection details.
    log.error({ code: 'AUTH_PURGE_FAILED' }, 'Auth purge failed');
  }
}
