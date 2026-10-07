import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { insertDamage, patchDamage, sumDamageForTransfer } from './store.js';
import type { CreateDamageInput, UpdateDamageInput } from './contracts.js';

export async function createDamage(tx: Transaction, input: CreateDamageInput) {
  // 1. Fetch & validate transfer (pemindahan)
  const transferRow = (await tx.execute({
    sql: 'SELECT id_pemindahan, jumlah_tanaman FROM pemindahan WHERE id_pemindahan = ?',
    args: [input.id_pemindahan],
  })).rows[0];
  if (!transferRow) {
    throw new ApiError(404, 'TRANSFER_NOT_FOUND', 'Data pemindahan tidak ditemukan.');
  }

  // 2. Check total damage + new does not exceed transferred count
  const totalDamaged = await sumDamageForTransfer(tx, input.id_pemindahan);
  const alreadyHarvested = Number((await tx.execute({
    sql: 'SELECT COALESCE(SUM(jumlah_tanaman), 0) AS total FROM detail_panen WHERE id_pemindahan = ?',
    args: [input.id_pemindahan],
  })).rows[0].total);

  const jumlahPindah = Number(transferRow.jumlah_tanaman);
  const remaining = jumlahPindah - totalDamaged - alreadyHarvested;

  if (input.jumlah_tanaman > remaining) {
    throw new ApiError(
      409,
      'DAMAGE_EXCEEDS_ACTIVE',
      'Jumlah tanaman rusak melebihi sisa tanaman aktif pada batch.',
    );
  }

  return insertDamage(tx, input);
}

export async function updateDamage(tx: Transaction, id: string, input: UpdateDamageInput) {
  if (input.jumlah_tanaman !== undefined) {
    // Re-validate the count headroom after adjustment
    const existing = (await tx.execute({
      sql: `SELECT d.id_pemindahan, d.jumlah_tanaman,
        p.jumlah_tanaman AS jumlah_pindah
        FROM kerusakan_tanaman d
        JOIN pemindahan p ON p.id_pemindahan = d.id_pemindahan
        WHERE d.id_kerusakan = ?`,
      args: [id],
    })).rows[0];
    if (!existing) throw new ApiError(404, 'DAMAGE_NOT_FOUND', 'Data kerusakan tanaman tidak ditemukan.');

    const totalDamaged = await sumDamageForTransfer(tx, String(existing.id_pemindahan));
    const alreadyHarvested = Number((await tx.execute({
      sql: 'SELECT COALESCE(SUM(jumlah_tanaman), 0) AS total FROM detail_panen WHERE id_pemindahan = ?',
      args: [existing.id_pemindahan],
    })).rows[0].total);

    const jumlahPindah = Number(existing.jumlah_pindah);
    // Subtract current damage row before checking new value
    const otherDamaged = totalDamaged - Number(existing.jumlah_tanaman);
    const remaining = jumlahPindah - otherDamaged - alreadyHarvested;

    if (input.jumlah_tanaman > remaining) {
      throw new ApiError(
        409,
        'DAMAGE_EXCEEDS_ACTIVE',
        'Jumlah tanaman rusak melebihi sisa tanaman aktif pada batch.',
      );
    }
  }

  return patchDamage(tx, id, input);
}
