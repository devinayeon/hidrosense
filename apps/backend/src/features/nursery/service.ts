import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { recordMovement } from '../stock/service.js';
import { getSowing, countMoved } from './store.js';
import type { CreateSowingInput, UpdateSowingInput } from './contracts.js';

/**
 * Create a new sowing and atomically consume the seed materials from stock.
 * The stock write gets origin: { id_penyemaian } to prevent double-consumption.
 */
export async function createSowing(
  tx: Transaction,
  actorId: string,
  now: number,
  input: CreateSowingInput,
) {
  // Insert penyemaian row first to obtain its ID for the stock origin FK.
  const inserted = (await tx.execute({
    sql: `INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian, keterangan)
      VALUES (?, ?, ?, 'aktif', ?) RETURNING CAST(id_penyemaian AS TEXT) AS id_penyemaian`,
    args: [actorId, input.tanggal_semai, input.jumlah_benih, input.keterangan ?? null],
  })).rows[0];
  const id = String(inserted.id_penyemaian);

  // Consume seed materials via stock ledger in same transaction.
  // B006 recordMovement handles item-active check, unit lock, and balance atomicity.
  await recordMovement(tx, actorId, now, {
    jenis_stok: 'keluar',
    details: input.materials,
    keterangan: `Penyemaian #${id}`,
  }, { id_penyemaian: id });

  return getSowing(tx, id, now);
}

/**
 * Update mutable fields on an existing sowing.
 * jumlah_benih cannot be set below the count already transferred to beds.
 */
export async function updateSowing(
  tx: Transaction,
  id: string,
  input: UpdateSowingInput,
  now: number,
) {
  // Ensure exists
  await getSowing(tx, id, now);

  if (input.jumlah_benih !== undefined) {
    const moved = await countMoved(tx, id);
    if (input.jumlah_benih < moved) {
      throw new ApiError(409, 'SOWING_UNDERCAPACITY',
        `Jumlah benih tidak boleh lebih kecil dari yang sudah dipindahkan (${moved}).`);
    }
  }

  const assignments: string[] = [];
  const args: (string | number | null)[] = [];

  if (input.jumlah_benih !== undefined) {
    assignments.push('jumlah_benih=?');
    args.push(input.jumlah_benih);
  }
  if (input.status_penyemaian !== undefined) {
    assignments.push('status_penyemaian=?');
    args.push(input.status_penyemaian);
  }
  if ('keterangan' in input) {
    assignments.push('keterangan=?');
    args.push(input.keterangan ?? null);
  }
  if (!assignments.length) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Minimal satu field harus diperbarui.');
  }
  args.push(id);

  await tx.execute({
    sql: `UPDATE penyemaian SET ${assignments.join(',')} WHERE id_penyemaian=?`,
    args,
  });
  return getSowing(tx, id, now);
}
