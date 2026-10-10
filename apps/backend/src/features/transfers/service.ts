import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import {
  countMovedSeedlings,
  countTableActive,
  getTransfer,
  insertTransfer,
  patchTransfer,
} from './store.js';
import type { CreateTransferInput, UpdateTransferInput } from './contracts.js';

const dayMs = 24 * 60 * 60 * 1000;

export async function createTransfer(
  tx: Transaction,
  input: CreateTransferInput,
  now: number,
) {
  // 1. Fetch & validate penyemaian
  const sowingRow = (await tx.execute({
    sql: 'SELECT id_penyemaian, tanggal_semai, jumlah_benih, status_penyemaian FROM penyemaian WHERE id_penyemaian = ?',
    args: [input.id_penyemaian],
  })).rows[0];
  if (!sowingRow) {
    throw new ApiError(404, 'PENYEMAIAN_NOT_FOUND', 'Data penyemaian tidak ditemukan.');
  }
  if (sowingRow.status_penyemaian !== 'aktif') {
    throw new ApiError(409, 'SOWING_INACTIVE', 'Data penyemaian tidak aktif atau sudah selesai.');
  }

  // 2. Validate seedling age (minimum 15 days)
  const semaiMs = Date.parse(`${String(sowingRow.tanggal_semai)}T00:00:00Z`);
  const pindahMs = Date.parse(`${input.tanggal_pemindahan}T00:00:00Z`);
  const umurSemaiHari = Math.floor((pindahMs - semaiMs) / dayMs);

  const today = new Date(now + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
  if (input.tanggal_pemindahan > today) {
    throw new ApiError(400, 'INVALID_TRANSFER_DATE', 'Tanggal pemindahan tidak boleh di masa depan.');
  }

  if (umurSemaiHari < 0) {
    throw new ApiError(400, 'INVALID_TRANSFER_DATE', 'Tanggal pemindahan tidak boleh lebih awal dari tanggal semai.');
  }
  if (umurSemaiHari < 15) {
    throw new ApiError(400, 'SEEDLING_NOT_READY', 'Bibit belum mencapai umur minimal 15 hari untuk dipindahkan.');
  }

  // 3. Validate available seedlings count
  const alreadyMoved = await countMovedSeedlings(tx, input.id_penyemaian);
  const availableSeedlings = Number(sowingRow.jumlah_benih) - alreadyMoved;
  if (input.jumlah_tanaman > availableSeedlings) {
    throw new ApiError(409, 'SEEDLING_INSUFFICIENT', 'Jumlah bibit yang dipindahkan melebihi sisa bibit yang tersedia.');
  }

  // 4. Fetch & validate table
  const tableRow = (await tx.execute({
    sql: 'SELECT id_meja, kode_meja, jumlah_lubang, status_meja FROM meja_tanam WHERE id_meja = ?',
    args: [input.id_meja],
  })).rows[0];
  if (!tableRow) {
    throw new ApiError(404, 'TABLE_NOT_FOUND', 'Meja tanam tidak ditemukan.');
  }
  const statusMeja = String(tableRow.status_meja).toLowerCase();
  if (statusMeja !== 'tersedia') {
    throw new ApiError(409, 'TABLE_NOT_AVAILABLE', 'Meja tanam sedang tidak dapat digunakan.');
  }

  // 5. Validate table capacity
  const currentActive = await countTableActive(tx, input.id_meja);
  const availableCapacity = Number(tableRow.jumlah_lubang) - currentActive;
  if (input.jumlah_tanaman > availableCapacity) {
    throw new ApiError(409, 'TABLE_CAPACITY_EXCEEDED', 'Kapasitas lubang meja tanam tidak mencukupi.');
  }

  // 6. Insert transfer
  const result = await insertTransfer(tx, input, now);

  // 7. Auto-mark sowing as 'selesai' if all seedlings moved
  if (alreadyMoved + input.jumlah_tanaman >= Number(sowingRow.jumlah_benih)) {
    await tx.execute({
      sql: "UPDATE penyemaian SET status_penyemaian = 'selesai' WHERE id_penyemaian = ?",
      args: [input.id_penyemaian],
    });
  }

  return result;
}

export async function updateTransfer(
  tx: Transaction,
  id: string,
  input: UpdateTransferInput,
  now: number,
) {
  return patchTransfer(tx, id, input, now);
}
