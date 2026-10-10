import { backfillHarvest } from './harvest-weights.js';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const defaultDirectory = fileURLToPath(new URL('../../migrations/', import.meta.url));

export async function loadMigrations(directory = defaultDirectory) {
  const files = (await readdir(directory)).filter((name) => name.endsWith('.sql')).sort();
  const pairs = new Map();
  for (const file of files) {
    const match = file.match(/^(\d{4}_[a-z0-9_]+)\.(up|down)\.sql$/);
    if (!match) throw new Error(`Invalid migration filename: ${file}`);
    const [, id, direction] = match;
    const pair = pairs.get(id) ?? { id };
    pair[direction] = (await readFile(join(directory, file), 'utf8')).replaceAll('\r\n', '\n');
    pairs.set(id, pair);
  }
  const versions = new Set();
  return [...pairs.values()].map((migration) => {
    if (!migration.up?.trim() || !migration.down?.trim()) throw new Error(`Migration ${migration.id} requires a nonempty up/down pair.`);
    const version = migration.id.slice(0, 4);
    if (versions.has(version)) throw new Error(`Duplicate migration version: ${version}`);
    versions.add(version);
    return { ...migration, checksum: createHash('sha256').update(migration.up).update('\0').update(migration.down).digest('hex') };
  });
}

async function appliedMigrations(executor) {
  const exists = await executor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='_schema_migrations'");
  if (!exists.rows.length) return [];
  return (await executor.execute('SELECT id, checksum, applied_at FROM _schema_migrations ORDER BY id')).rows;
}

function validateHistory(applied, migrations) {
  for (let i = 0; i < applied.length; i++) {
    if (applied[i].id !== migrations[i]?.id) throw new Error('Migration history differs from local files: an applied migration is missing or out of order.');
    if (applied[i].checksum !== migrations[i].checksum) throw new Error(`Applied migration ${applied[i].id} has changed (checksum mismatch). Create a new migration instead.`);
  }
}

export async function migrationStatus(client, migrations) {
  const applied = await appliedMigrations(client);
  validateHistory(applied, migrations);
  return migrations.map((migration, i) => ({ id: migration.id, status: i < applied.length ? 'applied' : 'pending', applied_at: applied[i]?.applied_at ?? null }));
}

export async function migrate(client, migrations, { direction = 'up', allowDataLoss = false } = {}) {
  if (!['up', 'down'].includes(direction)) throw new Error('Migration direction must be up or down.');
  if (direction === 'down' && !allowDataLoss) throw new Error('Rollback may delete data; allowDataLoss must be explicitly enabled after taking a backup.');
  const tx = await client.transaction('write');
  let current = 'history';
  try {
    if (Number((await tx.execute('PRAGMA foreign_keys')).rows[0].foreign_keys) !== 1) {
      throw new Error('Migration transaction must enforce foreign keys.');
    }
    await tx.execute(`CREATE TABLE IF NOT EXISTS _schema_migrations (
      id TEXT PRIMARY KEY NOT NULL,
      checksum TEXT NOT NULL,
      applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`);
    const applied = await appliedMigrations(tx);
    validateHistory(applied, migrations);
    const pending = direction === 'up'
      ? migrations.slice(applied.length)
      : applied.length ? [migrations[applied.length - 1]] : [];
    for (const migration of pending) {
      current = migration.id;
      // SQL is trusted, reviewed migration code; runtime values use bound parameters.
      // Do not put BEGIN/COMMIT or foreign_keys=OFF in migration files.
      await tx.executeMultiple(migration[direction]);
      if (direction === 'up' && migration.id === '0011_harvest_weights') await backfillHarvest(tx);
      if (direction === 'up') {
        await tx.execute({ sql: 'INSERT INTO _schema_migrations (id, checksum) VALUES (?, ?)', args: [migration.id, migration.checksum] });
      } else {
        await tx.execute({ sql: 'DELETE FROM _schema_migrations WHERE id = ?', args: [migration.id] });
      }
    }
    if ((await tx.execute('PRAGMA foreign_key_check')).rows.length) throw new Error('Foreign key integrity check failed.');
    await tx.commit();
    return pending.map((migration) => migration.id);
  } catch (error) {
    if (!tx.closed) await tx.rollback();
    throw new Error(`Migration ${direction} failed at ${current}: ${error.message}`, { cause: error });
  } finally {
    tx.close();
  }
}
