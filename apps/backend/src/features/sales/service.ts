import type { InValue, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import { formatWeight, parseWeight } from '../../db/harvest-weights.js';
import { formatMoney, parseMoney } from '../../db/sales-amounts.js';
import { getSale } from './store.js';
import type { CreateSaleInput, UpdateSaleInput } from './contracts.js';

type SaleLineInput = { id_panen: string; jumlah_kg: string; harga_per_kg: string };

function jakartaToday(now: number) {
  return new Date(now + 7 * 3600000).toISOString().slice(0, 10);
}

function validateDate(date: string, now: number) {
  if (date > jakartaToday(now)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Tanggal penjualan tidak boleh di masa depan.');
  }
}

async function harvestForSale(tx: Transaction, idPanen: string) {
  const row = (await tx.execute({
    sql: `SELECT CAST(p.id_panen AS TEXT) AS id_panen, p.tanggal_panen,
        COUNT(d.id_detail_panen) AS detail_count,
        COALESCE(SUM(CASE WHEN d.berat_minor IS NOT NULL THEN 1 ELSE 0 END), 0) AS known_count,
        SUM(d.berat_minor) AS layak
      FROM panen p
      LEFT JOIN detail_panen d ON d.id_panen = p.id_panen
      WHERE p.id_panen = ?
      GROUP BY p.id_panen`,
    args: [idPanen],
  })).rows[0];
  if (!row) throw new ApiError(404, 'HARVEST_NOT_FOUND', 'Data panen tidak ditemukan.');
  if (Number(row.detail_count) === 0
    || Number(row.known_count) !== Number(row.detail_count)
    || row.layak == null) {
    throw new ApiError(409, 'HARVEST_NOT_SELLABLE', 'Panen belum memiliki berat layak yang diketahui.');
  }
  return { date: String(row.tanggal_panen), saleable: BigInt(String(row.layak)) };
}

async function soldForHarvest(tx: Transaction, idPanen: string, excludeSaleId?: string) {
  const rows = (await tx.execute({
    sql: `SELECT CAST(jumlah_kg_minor AS TEXT) AS minor,
        CAST(jumlah_kg AS TEXT) AS kg,
        CAST(CAST(jumlah_kg AS TEXT) AS NUMERIC) = jumlah_kg AS roundtrip
      FROM detail_penjualan
      WHERE id_panen = ?${excludeSaleId === undefined ? '' : ' AND id_penjualan <> ?'}`,
    args: excludeSaleId === undefined ? [idPanen] : [idPanen, excludeSaleId],
  })).rows;
  let total = 0n;
  for (const row of rows) {
    if (row.minor != null) {
      total += BigInt(String(row.minor));
      continue;
    }
    if (Number(row.roundtrip) !== 1) {
      throw new ApiError(409, 'SALE_LEGACY_AMOUNT_INVALID', 'Nilai penjualan lama tidak dapat dibaca dengan pasti.');
    }
    try {
      total += parseWeight(String(row.kg));
    } catch {
      throw new ApiError(409, 'SALE_LEGACY_AMOUNT_INVALID', 'Nilai penjualan lama tidak dapat dibaca dengan pasti.');
    }
  }
  return total;
}

async function validateLine(tx: Transaction, line: SaleLineInput, date: string, excludeSaleId?: string) {
  const quantity = parseWeight(line.jumlah_kg);
  const harvest = await harvestForSale(tx, line.id_panen);
  if (date < harvest.date) {
    throw new ApiError(400, 'INVALID_SALE_DATE', 'Tanggal penjualan mendahului tanggal panen.');
  }
  const sold = await soldForHarvest(tx, line.id_panen, excludeSaleId);
  const remaining = harvest.saleable - sold;
  if (quantity > remaining) {
    throw new ApiError(
      409,
      'SALE_EXCEEDS_HARVEST_STOCK',
      `Berat jual melebihi stok panen. Sisa stok ${formatWeight(remaining < 0n ? 0n : remaining)} Kg.`,
    );
  }
  return { quantity, price: parseMoney(line.harga_per_kg) };
}

function lineFromInput(input: CreateSaleInput): SaleLineInput {
  return { id_panen: input.id_panen, jumlah_kg: input.jumlah_kg, harga_per_kg: input.harga_per_kg };
}

async function insertLine(tx: Transaction, saleId: string, line: SaleLineInput) {
  const quantity = parseWeight(line.jumlah_kg);
  const price = parseMoney(line.harga_per_kg);
  await tx.execute({
    sql: `INSERT INTO detail_penjualan
      (id_penjualan, id_panen, jumlah_kg, harga_per_kg, jumlah_kg_minor, harga_per_kg_minor)
      VALUES (?, ?, ?, ?, ?, ?)`,
    args: [saleId, line.id_panen, formatWeight(quantity), formatMoney(price), quantity, price],
  });
}

export async function createSale(tx: Transaction, input: CreateSaleInput, actor: string, now: number) {
  validateDate(input.tanggal_penjualan, now);
  const line = lineFromInput(input);
  await validateLine(tx, line, input.tanggal_penjualan);
  const id = String((await tx.execute({
    sql: 'INSERT INTO penjualan (id_user, tanggal_penjualan, pembeli, status_pembayaran, keterangan) VALUES (?, ?, ?, ?, ?) RETURNING CAST(id_penjualan AS TEXT) AS id',
    args: [actor, input.tanggal_penjualan, input.pembeli, input.status_pembayaran, input.keterangan],
  })).rows[0].id);
  await insertLine(tx, id, line);
  return getSale(tx, id);
}

export async function updateSale(tx: Transaction, id: string, input: UpdateSaleInput, now: number) {
  const existing = await getSale(tx, id);
  if (existing.version == null || existing.version !== input.expected_version) {
    throw new ApiError(409, 'SALE_VERSION_CONFLICT', 'Versi penjualan telah berubah.');
  }
  const date = input.tanggal_penjualan ?? existing.tanggal_penjualan;
  validateDate(date, now);

  const detailChanged = input.id_panen !== undefined;
  if (detailChanged) {
    if (input.jumlah_kg === undefined || input.harga_per_kg === undefined) {
      throw new ApiError(400, 'VALIDATION_ERROR', 'Batch, berat, dan harga harus diisi bersama.');
    }
    const line = { id_panen: input.id_panen!, jumlah_kg: input.jumlah_kg, harga_per_kg: input.harga_per_kg };
    await validateLine(tx, line, date, id);
    await tx.execute({ sql: 'DELETE FROM detail_penjualan WHERE id_penjualan = ?', args: [id] });
    await insertLine(tx, id, line);
  } else {
    for (const detail of existing.details) {
      if (date < detail.tanggal_panen) {
        throw new ApiError(400, 'INVALID_SALE_DATE', 'Tanggal penjualan mendahului tanggal panen.');
      }
    }
  }

  const fields: string[] = [];
  const args: InValue[] = [];
  if (input.tanggal_penjualan !== undefined) { fields.push('tanggal_penjualan = ?'); args.push(input.tanggal_penjualan); }
  if (input.pembeli !== undefined) { fields.push('pembeli = ?'); args.push(input.pembeli); }
  if (input.status_pembayaran !== undefined) { fields.push('status_pembayaran = ?'); args.push(input.status_pembayaran); }
  if (input.keterangan !== undefined) { fields.push('keterangan = ?'); args.push(input.keterangan); }
  if (fields.length) {
    await tx.execute({ sql: `UPDATE penjualan SET ${fields.join(', ')} WHERE id_penjualan = ?`, args: [...args, id] });
  }
  return getSale(tx, id);
}
