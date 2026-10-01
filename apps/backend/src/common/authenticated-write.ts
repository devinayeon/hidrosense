import type { Client, Transaction } from '@libsql/client';
import { ApiError } from './errors.js';
import { authenticate, type Principal } from './sessions.js';

// Recheck the current session and permissions in the same transaction as the write.
export async function authenticatedWrite<T>(
  db: Client,
  authorization: string | undefined,
  permission: string | undefined,
  clock: () => number,
  operation: (tx: Transaction, actor: Principal) => Promise<T>,
): Promise<T> {
  const tx = await db.transaction('write');
  try {
    const actor = await authenticate(tx, authorization, clock());
    if (permission && !actor.permissions.includes(permission)) {
      throw new ApiError(403, 'FORBIDDEN', 'Akses tidak diizinkan untuk akun ini.');
    }
    const result = await operation(tx, actor);
    await tx.commit();
    return result;
  } catch (error) {
    if (!tx.closed) await tx.rollback();
    throw error;
  } finally { tx.close(); }
}
