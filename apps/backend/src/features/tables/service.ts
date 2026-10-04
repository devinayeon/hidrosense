import type { Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { assertCodeAvailable, getTable, insertTable, patchTable } from './store.js';
import type { CreateTableInput, UpdateTableInput } from './contracts.js';

export async function createTable(tx: Transaction, input: CreateTableInput) {
  await assertCodeAvailable(tx, input.kode_meja);
  return insertTable(tx, input);
}
export async function updateTable(tx: Transaction, id: string, input: UpdateTableInput) {
  const existing = await getTable(tx, id);
  if (input.jumlah_lubang !== undefined && input.jumlah_lubang < existing.tanaman_aktif) {
    throw new ApiError(409, 'TABLE_UNDERCAPACITY', 'Kapasitas tidak boleh lebih kecil dari tanaman aktif.');
  }
  if (input.kode_meja !== undefined) await assertCodeAvailable(tx, input.kode_meja, id);
  return patchTable(tx, id, input);
}
