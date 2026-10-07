import type { Client, InValue, Row, Transaction } from '@libsql/client';
import { ApiError } from '../../common/errors.js';
import type { CreateDamageInput, ListDamageQuery, UpdateDamageInput } from './contracts.js';

type Executor = Pick<Client, 'execute'>;

const linkJoin = `LEFT JOIN sync_resource_links l ON l.resource_type='kerusakan_tanaman' AND l.domain_id=CAST(k.id_kerusakan AS TEXT)
  LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id`;

const columns = `
  CAST(k.id_kerusakan AS TEXT) AS id_kerusakan,
  l.public_id,
  CAST(v.version AS TEXT) AS version,
  CAST(k.id_pemindahan AS TEXT) AS id_pemindahan,
  k.tanggal_kejadian,
  k.jumlah_tanaman,
  k.jenis_kerusakan,
  k.keterangan
`;

function damageRow(row: Row) {
  return {
    id_kerusakan: String(row.id_kerusakan),
    public_id: row.public_id == null ? null : String(row.public_id),
    version: row.version == null ? null : String(row.version),
    id_pemindahan: String(row.id_pemindahan),
    tanggal_kejadian: String(row.tanggal_kejadian),
    jumlah_tanaman: Number(row.jumlah_tanaman),
    jenis_kerusakan: String(row.jenis_kerusakan),
    keterangan: row.keterangan == null ? null : String(row.keterangan),
  };
}

export async function getDamage(db: Executor, id: string) {
  const row = (await db.execute({
    sql: `SELECT ${columns} FROM kerusakan_tanaman k ${linkJoin} WHERE k.id_kerusakan = ?`,
    args: [id],
  })).rows[0];
  if (!row) throw new ApiError(404, 'DAMAGE_NOT_FOUND', 'Data kerusakan tanaman tidak ditemukan.');
  return damageRow(row);
}

export async function listDamages(db: Executor, query: ListDamageQuery) {
  const filterPemindahan = query.id_pemindahan ?? null;
  const whereSql = `(? IS NULL OR k.id_pemindahan = ?)`;
  const args = [filterPemindahan, filterPemindahan];

  const count = (await db.execute({
    sql: `SELECT COUNT(*) AS total FROM kerusakan_tanaman k WHERE ${whereSql}`,
    args,
  })).rows[0];
  const total = Number(count.total);

  const rows = (await db.execute({
    sql: `SELECT ${columns} FROM kerusakan_tanaman k ${linkJoin}
      WHERE ${whereSql}
      ORDER BY k.tanggal_kejadian DESC, k.id_kerusakan DESC
      LIMIT ? OFFSET ?`,
    args: [...args, query.limit, (query.page - 1) * query.limit],
  })).rows;

  return {
    data: rows.map(damageRow),
    meta: {
      page: query.page,
      limit: query.limit,
      total,
      total_pages: Math.ceil(total / query.limit),
    },
  };
}

export async function sumDamageForTransfer(tx: Transaction, idPemindahan: string): Promise<number> {
  const row = (await tx.execute({
    sql: 'SELECT COALESCE(SUM(jumlah_tanaman), 0) AS total FROM kerusakan_tanaman WHERE id_pemindahan = ?',
    args: [idPemindahan],
  })).rows[0];
  return Number(row.total);
}

export async function insertDamage(tx: Transaction, input: CreateDamageInput) {
  const inserted = (await tx.execute({
    sql: `INSERT INTO kerusakan_tanaman (id_pemindahan, tanggal_kejadian, jumlah_tanaman, jenis_kerusakan, keterangan)
      VALUES (?, ?, ?, ?, ?) RETURNING CAST(id_kerusakan AS TEXT) AS id_kerusakan`,
    args: [input.id_pemindahan, input.tanggal_kejadian, input.jumlah_tanaman, input.jenis_kerusakan, input.keterangan ?? null],
  })).rows[0];
  return getDamage(tx, String(inserted.id_kerusakan));
}

export async function patchDamage(tx: Transaction, id: string, input: UpdateDamageInput) {
  await getDamage(tx, id);
  const fields: string[] = [];
  const args: InValue[] = [];

  if ('tanggal_kejadian' in input && input.tanggal_kejadian !== undefined) {
    fields.push('tanggal_kejadian = ?');
    args.push(input.tanggal_kejadian);
  }
  if ('jumlah_tanaman' in input && input.jumlah_tanaman !== undefined) {
    fields.push('jumlah_tanaman = ?');
    args.push(input.jumlah_tanaman);
  }
  if ('jenis_kerusakan' in input && input.jenis_kerusakan !== undefined) {
    fields.push('jenis_kerusakan = ?');
    args.push(input.jenis_kerusakan);
  }
  if ('keterangan' in input) {
    fields.push('keterangan = ?');
    args.push(input.keterangan ?? null);
  }

  if (fields.length > 0) {
    await tx.execute({
      sql: `UPDATE kerusakan_tanaman SET ${fields.join(', ')} WHERE id_kerusakan = ?`,
      args: [...args, id],
    });
  }

  return getDamage(tx, id);
}
