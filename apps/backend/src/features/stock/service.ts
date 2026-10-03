import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { initializeStockIdentity } from '../../common/sync.js';
import { createStockSchema, parseInput, type StockInput } from './contracts.js';
import { appendMovement, assertItemsAvailable, getMovement, isReversed, type StockOrigin } from './store.js';

export async function recordMovement(tx: Transaction, actorId: string, now: number,
  input: StockInput, origin?: StockOrigin) {
  // Enforce the same rules for future domain callers, not only the HTTP boundary.
  const normalized = parseInput(createStockSchema, input);
  if (origin && normalized.jenis_stok !== 'keluar') {
    throw new ApiError(409, 'REVERSAL_NOT_ALLOWED', 'Pemakaian domain harus berupa stok keluar.');
  }
  await assertItemsAvailable(tx, normalized.details);
  const movement = await appendMovement(tx, actorId, now, normalized, null, origin);
  // B007/B014 use their primary domain receipt, so initialize the secondary stock identity here.
  // Manual writes initialize it through stockWrite's domain mutation wrapper instead.
  if (origin) return { ...movement, ...await initializeStockIdentity(tx, movement.id_stok, now) };
  return movement;
}

export async function reverseMovement(tx: Transaction, actorId: string, now: number,
  id: string, keterangan: string) {
  const original = await getMovement(tx, id);
  if (original.reversal_of || original.id_penyemaian || original.id_perawatan) {
    throw new ApiError(409, 'REVERSAL_NOT_ALLOWED', 'Transaksi ini harus dikoreksi melalui fitur pemiliknya.');
  }
  if (await isReversed(tx, id)) throw new ApiError(409, 'STOK_ALREADY_REVERSED', 'Transaksi sudah dibalik.');
  const details = original.details.map(({ id_inventaris, jumlah, satuan }) => ({ id_inventaris, jumlah, satuan }));
  await assertItemsAvailable(tx, details, true);
  return appendMovement(tx, actorId, now, {
    jenis_stok: original.jenis_stok === 'masuk' ? 'keluar' : 'masuk', details, keterangan,
  }, id);
}
