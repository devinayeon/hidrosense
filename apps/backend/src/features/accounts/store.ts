import type { Client, InValue, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { authenticate, type Principal } from '../../common/sessions.js';
import type { AccountChanges } from './contracts.js';

type Executor = Pick<Client, 'execute'>;
export const accountColumns = `CAST(u.id_user AS TEXT) AS id_user,u.nama,u.username,
  u.email,u.no_telepon,u.alamat,u.status_aktif,r.nama_role`;

export function accountResponse(row: Row) {
  return {
    id_user: String(row.id_user), nama: String(row.nama), username: String(row.username),
    email: row.email === null ? null : String(row.email),
    no_telepon: row.no_telepon === null ? null : String(row.no_telepon),
    alamat: row.alamat === null ? null : String(row.alamat),
    status_aktif: Number(row.status_aktif), role: String(row.nama_role),
  };
}

export async function getAccount(db: Executor, id: string, role: 'pegawai' | 'petani') {
  const row = (await db.execute({
    sql: `SELECT ${accountColumns} FROM users u JOIN roles r ON r.id_role=u.id_role
      WHERE u.id_user=? AND r.nama_role=?`, args: [id, role],
  })).rows[0];
  if (!row) throw new ApiError(404, 'ACCOUNT_NOT_FOUND', 'Akun tidak ditemukan.');
  return accountResponse(row);
}

export async function assertUsernameAvailable(db: Executor, username: string, exceptId?: string) {
  const result = await db.execute({
    sql: 'SELECT 1 FROM users WHERE username=? AND (? IS NULL OR id_user<>?)',
    args: [username, exceptId ?? null, exceptId ?? null],
  });
  if (result.rows.length) throw new ApiError(409, 'USERNAME_TAKEN', 'Username sudah digunakan.');
}

// Recheck authorization inside the write transaction, including after slow password hashing.
export async function accountWrite<T>(db: Client, authorization: string | undefined, permission: string,
  clock: () => number, operation: (tx: Transaction, actor: Principal) => Promise<T>): Promise<T> {
  const tx = await db.transaction('write');
  try {
    const actor = await authenticate(tx, authorization, clock());
    if (!actor.permissions.includes(permission)) throw new ApiError(403, 'FORBIDDEN', 'Akses tidak diizinkan untuk akun ini.');
    const result = await operation(tx, actor);
    await tx.commit();
    return result;
  } catch (error) {
    if (!tx.closed) await tx.rollback();
    throw error;
  } finally { tx.close(); }
}

export async function updateAccount(tx: Transaction, id: string, changes: AccountChanges, passwordHash?: string) {
  const assignments: string[] = [];
  const args: InValue[] = [];
  // Only server-owned column names enter SQL; all values are bound parameters.
  for (const field of ['nama', 'username', 'email', 'no_telepon', 'alamat'] as const) {
    if (changes[field] !== undefined) { assignments.push(`${field}=?`); args.push(changes[field]); }
  }
  if (passwordHash) { assignments.push('password=?'); args.push(passwordHash); }
  args.push(id);
  await tx.execute({ sql: `UPDATE users SET ${assignments.join(',')} WHERE id_user=?`, args });
  if (passwordHash || changes.username !== undefined) {
    await tx.execute({ sql: 'DELETE FROM auth_sessions WHERE id_user=?', args: [id] });
  }
}
