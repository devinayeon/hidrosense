import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { Client, Row } from '@libsql/client';
import { ApiError } from './errors.js';
import { permissionsFor } from './permissions.js';

export const ACCESS_TTL_MS = 15 * 60 * 1000;
export const REFRESH_TTL_MS = 7 * 24 * 60 * 60 * 1000;
export const tokenPattern = '^[A-Za-z0-9_-]{43}$';
export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');
export const newTokens = () => ({ access: randomBytes(32).toString('base64url'), refresh: randomBytes(32).toString('base64url') });

export function publicUser(row: Row) {
  return {
    id_user: String(row.id_user), nama: String(row.nama), username: String(row.username),
    role: String(row.nama_role), permissions: [...permissionsFor(String(row.nama_role))],
  };
}

export type Principal = ReturnType<typeof publicUser> & { sessionId: string };

export async function authenticate(db: Pick<Client, 'execute'>, authorization: string | undefined, now: number): Promise<Principal> {
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/i.exec(authorization ?? '');
  if (!match) throw new ApiError(401, 'UNAUTHENTICATED', 'Sesi tidak valid atau kedaluwarsa.');
  const result = await db.execute({
    sql: `SELECT s.id_session, CAST(u.id_user AS TEXT) AS id_user, u.nama, u.username, r.nama_role
      FROM auth_sessions s JOIN users u ON u.id_user=s.id_user JOIN roles r ON r.id_role=u.id_role
      WHERE s.access_token_hash=? AND s.access_expires_at>? AND s.refresh_expires_at>?
      AND u.status_aktif=1 AND s.credential_hash=u.password`,
    args: [tokenHash(match[1]), now, now],
  });
  const row = result.rows[0];
  if (!row || !permissionsFor(String(row.nama_role)).length) {
    throw new ApiError(401, 'UNAUTHENTICATED', 'Sesi tidak valid atau kedaluwarsa.');
  }
  return { ...publicUser(row), sessionId: String(row.id_session) };
}

export function tokenResponse(tokens: ReturnType<typeof newTokens>, accessExpiry: number, refreshExpiry: number, now: number) {
  return {
    token_type: 'Bearer', access_token: tokens.access, refresh_token: tokens.refresh,
    expires_in: Math.floor((accessExpiry - now) / 1000),
    access_expires_at: new Date(accessExpiry).toISOString(),
    refresh_expires_at: new Date(refreshExpiry).toISOString(),
  };
}

export async function createSession(db: Client, user: Row, now: number) {
  const tokens = newTokens();
  const accessExpiry = now + ACCESS_TTL_MS;
  const refreshExpiry = now + REFRESH_TTL_MS;
  const inserted = await db.execute({
    sql: `INSERT INTO auth_sessions
      (id_session,id_user,access_token_hash,refresh_token_hash,credential_hash,created_at,access_expires_at,refresh_expires_at)
      SELECT ?,u.id_user,?,?,u.password,?,?,? FROM users u JOIN roles r ON r.id_role=u.id_role
      WHERE u.id_user=? AND u.username=? AND u.status_aktif=1 AND u.password=?
        AND r.nama_role IN ('petani','pegawai')`,
    // Credentials read before scrypt must still identify the same account at commit time.
    args: [randomUUID(), tokenHash(tokens.access), tokenHash(tokens.refresh), now, accessExpiry, refreshExpiry,
      user.id_user, user.username, user.password],
  });
  if (!inserted.rowsAffected) throw new ApiError(401, 'INVALID_CREDENTIALS', 'Username atau password tidak valid.');
  const principal = await authenticate(db, `Bearer ${tokens.access}`, now);
  const { sessionId: _sessionId, ...identity } = principal;
  return { ...tokenResponse(tokens, accessExpiry, refreshExpiry, now), user: identity };
}
