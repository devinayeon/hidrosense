import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { assertCodeAvailable, getTable, insertTable, patchTable, syncTableStatus } from './store.js';
import type { CreateTableInput, UpdateTableInput } from './contracts.js';

function rejectDerivedStatus(status: string | undefined) {
  if (status?.toLowerCase() === 'penuh') {
    throw new ApiError(400, 'TABLE_STATUS_DERIVED', 'Status penuh ditentukan otomatis dari kapasitas dan tanaman aktif.');
  }
}
export async function createTable(tx: Transaction, input: CreateTableInput) {
  rejectDerivedStatus(input.status_meja);
  await assertCodeAvailable(tx, input.kode_meja);
  return insertTable(tx, input);
}
export async function updateTable(tx: Transaction, id: string, input: UpdateTableInput) {
  rejectDerivedStatus(input.status_meja);
  const existing = await getTable(tx, id);
  if (input.jumlah_lubang !== undefined && input.jumlah_lubang < existing.tanaman_aktif) {
    throw new ApiError(409, 'TABLE_UNDERCAPACITY', 'Kapasitas tidak boleh lebih kecil dari tanaman aktif.');
  }
  if (input.kode_meja !== undefined) await assertCodeAvailable(tx, input.kode_meja, id);
  await patchTable(tx, id, input);
  await syncTableStatus(tx, id);
  return getTable(tx, id);
}
