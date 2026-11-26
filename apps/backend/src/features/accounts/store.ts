import type { Client, InValue, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import type { AccountChanges } from './contracts.js';

type Executor = Pick<Client, 'execute'>;
export const accountColumns = `CAST(u.id_user AS TEXT) AS id_user,u.nama,u.username,
  u.email,u.no_telepon,u.alamat,u.status_aktif,r.nama_role,u.updated_at`;

export function accountResponse(row: Row) {
  return {
    id_user: String(row.id_user), nama: String(row.nama), username: String(row.username),
    email: row.email === null ? null : String(row.email),
    no_telepon: row.no_telepon === null ? null : String(row.no_telepon),
    alamat: row.alamat === null ? null : String(row.alamat),
    status_aktif: Number(row.status_aktif), role: String(row.nama_role),
    updated_at: row.updated_at === null ? null : Number(row.updated_at),
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

/** Akun milik pemilik sesi sendiri; peran tidak difilter karena siapa pun
 *  berhak membaca profilnya sendiri (petani maupun pegawai). */
export async function getAccountById(db: Executor, id: string) {
  const row = (await db.execute({
    sql: `SELECT ${accountColumns} FROM users u JOIN roles r ON r.id_role=u.id_role
      WHERE u.id_user=?`, args: [id],
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

/** Email boleh kosong, tetapi bila terisi harus unik; akun nonaktif tetap memegang emailnya. */
export async function assertEmailAvailable(db: Executor, email: string | null | undefined, exceptId?: string) {
  if (!email) return;
  const result = await db.execute({
    sql: 'SELECT 1 FROM users WHERE lower(email)=? AND (? IS NULL OR id_user<>?)',
    args: [email, exceptId ?? null, exceptId ?? null],
  });
  if (result.rows.length) throw new ApiError(409, 'EMAIL_TAKEN', 'Email sudah digunakan.');
}

export async function updateAccount(tx: Transaction, id: string, changes: AccountChanges, passwordHash: string | undefined, now: number) {
  // Baca username lama sebelum UPDATE. Formulir mengirim ulang semua field, jadi field yang
  // ikut terkirim belum tentu berubah; sesi hanya dicabut bila username benar-benar lain.
  const stored = changes.username === undefined ? undefined : (await tx.execute({
    sql: 'SELECT username FROM users WHERE id_user=?', args: [id],
  })).rows[0]?.username;
  const usernameChanged = changes.username !== undefined && changes.username !== stored;
  const assignments: string[] = ['updated_at=?'];
  const args: InValue[] = [now];
  // Only server-owned column names enter SQL; all values are bound parameters.
  for (const field of ['nama', 'username', 'email', 'no_telepon', 'alamat'] as const) {
    if (changes[field] !== undefined) { assignments.push(`${field}=?`); args.push(changes[field]); }
  }
  if (passwordHash) { assignments.push('password=?'); args.push(passwordHash); }
  args.push(id);
  await tx.execute({ sql: `UPDATE users SET ${assignments.join(',')} WHERE id_user=?`, args });
  if (passwordHash || usernameChanged) {
    await tx.execute({ sql: 'DELETE FROM auth_sessions WHERE id_user=?', args: [id] });
  }
}
