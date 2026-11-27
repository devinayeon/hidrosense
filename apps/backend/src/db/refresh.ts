import type { Client } from '@libsql/client';
import { migrate, type Migration } from './migrate.js';

type Executor = Pick<Client, 'execute'>;

/** Quote an SQLite identifier so table names can never break the statement. */
const quote = (identifier: string) => `"${identifier.replaceAll('"', '""')}"`;

async function userTables(db: Executor): Promise<string[]> {
  const rows = (await db.execute(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  )).rows;
  return rows.map((row) => String(row.name));
}

/**
 * Children must be dropped before their parents because foreign keys are
 * enforced. Build that order from the live schema instead of a hardcoded list,
 * so new migrations are covered automatically.
 */
async function dropOrder(db: Executor, tables: string[]): Promise<string[]> {
  const known = new Set(tables);
  const referencedBy = new Map<string, number>(tables.map((name) => [name, 0]));
  const parents = new Map<string, string[]>();
  for (const table of tables) {
    const rows = (await db.execute(`PRAGMA foreign_key_list(${quote(table)})`)).rows;
    const refs = [...new Set(rows.map((row) => String(row.table))
      .filter((name) => known.has(name) && name !== table))];
    parents.set(table, refs);
    for (const parent of refs) referencedBy.set(parent, (referencedBy.get(parent) ?? 0) + 1);
  }
  const order: string[] = [];
  const removed = new Set<string>();
  while (order.length < tables.length) {
    const ready = tables.filter((name) => !removed.has(name) && referencedBy.get(name) === 0);
    if (!ready.length) throw new Error('Tidak bisa menentukan urutan hapus tabel: ada relasi melingkar.');
    for (const name of ready) {
      removed.add(name);
      order.push(name);
      for (const parent of parents.get(name) ?? []) {
        referencedBy.set(parent, (referencedBy.get(parent) ?? 1) - 1);
      }
    }
  }
  return order;
}

/** Drop every user table in one transaction so a failure leaves the schema intact. */
export async function dropAllTables(db: Client): Promise<string[]> {
  const tables = await userTables(db);
  if (!tables.length) return [];
  const order = await dropOrder(db, tables);
  const tx = await db.transaction('write');
  try {
    for (const table of order) await tx.execute(`DROP TABLE IF EXISTS ${quote(table)}`);
    await tx.commit();
    return order;
  } catch (error) {
    if (!tx.closed) await tx.rollback();
    throw error;
  } finally {
    tx.close();
  }
}

/**
 * Return the database to a fresh state: no user tables, then every migration
 * applied again. The caller decides whether to seed afterwards.
 */
export async function refreshDatabase(db: Client, migrations: Migration[]) {
  const dropped = await dropAllTables(db);
  const applied = await migrate(db, migrations);
  return { dropped, applied };
}