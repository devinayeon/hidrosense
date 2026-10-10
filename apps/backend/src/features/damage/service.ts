import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { countTableActive } from '../transfers/store.js';
import { insertDamage, patchDamage, sumDamageForTransfer } from './store.js';
import type { CreateDamageInput, UpdateDamageInput } from './contracts.js';

function validateFutureDate(date: string | undefined, now: number) {
  const today = new Date(now + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
  if (date !== undefined && date > today) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Tanggal kerusakan tidak boleh di masa depan.');
  }
}

export async function createDamage(tx: Transaction, input: CreateDamageInput, now: number) {
  validateFutureDate(input.tanggal_kejadian, now);
  // 1. Fetch & validate transfer (pemindahan)
  const transferRow = (await tx.execute({
    sql: 'SELECT id_pemindahan, tanggal_pemindahan, jumlah_tanaman FROM pemindahan WHERE id_pemindahan = ?',
    args: [input.id_pemindahan],
  })).rows[0];
  if (!transferRow) {
    throw new ApiError(404, 'TRANSFER_NOT_FOUND', 'Data pemindahan tidak ditemukan.');
  }

  if (input.tanggal_kejadian < String(transferRow.tanggal_pemindahan)) {
    throw new ApiError(
      400,
      'INVALID_DAMAGE_DATE',
      'Tanggal kerusakan tidak boleh mendahului tanggal pemindahan.',
    );
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

export async function updateDamage(tx: Transaction, id: string, input: UpdateDamageInput, now: number) {
  validateFutureDate(input.tanggal_kejadian, now);
  const existing = (await tx.execute({
    sql: `SELECT d.id_pemindahan, d.jumlah_tanaman, d.tanggal_kejadian,
      p.tanggal_pemindahan, p.jumlah_tanaman AS jumlah_pindah,
      CAST(p.id_meja AS TEXT) AS id_meja, m.jumlah_lubang
      FROM kerusakan_tanaman d
      JOIN pemindahan p ON p.id_pemindahan = d.id_pemindahan
      JOIN meja_tanam m ON m.id_meja = p.id_meja
      WHERE d.id_kerusakan = ?`,
    args: [id],
  })).rows[0];
  if (!existing) throw new ApiError(404, 'DAMAGE_NOT_FOUND', 'Data kerusakan tanaman tidak ditemukan.');

  if (input.tanggal_kejadian !== undefined) {
    if (input.tanggal_kejadian < String(existing.tanggal_pemindahan)) {
      throw new ApiError(
        400,
        'INVALID_DAMAGE_DATE',
        'Tanggal kerusakan tidak boleh mendahului tanggal pemindahan.',
      );
    }
  }

  if (input.jumlah_tanaman !== undefined) {
    const restored = Number(existing.jumlah_tanaman) - input.jumlah_tanaman;
    if (restored > 0) {
      const active = await countTableActive(tx, String(existing.id_meja));
      if (active + restored > Number(existing.jumlah_lubang)) {
        throw new ApiError(
          409,
          'DAMAGE_RESTORE_EXCEEDS_TABLE_CAPACITY',
          'Koreksi kerusakan melebihi kapasitas lubang meja tanam.',
        );
      }
    }

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
