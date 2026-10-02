import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { mkdir, open } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createClient } from '@libsql/client';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate, migrationStatus } from '../src/db/migrate.js';

if (process.env.TURSO_MIGRATION_DEPLOY !== '1' || !/^(libsql|https):/.test(process.env.DATABASE_URL ?? '')) {
  throw new Error('Requires TURSO_MIGRATION_DEPLOY=1 and a remote DATABASE_URL.');
}
const quote = name => `"${name.replaceAll('"', '""')}"`;
function digest(rows) {
  const encoded = rows.map(row => JSON.stringify(Array.from(row), (_, value) =>
    typeof value === 'bigint' ? { integer: String(value) } : value instanceof ArrayBuffer
      ? { blob: Buffer.from(value).toString('hex') } : value)).sort();
  return createHash('sha256').update(JSON.stringify(encoded)).digest('hex');
}
const backupPath = resolve('backups', `turso-before-0002-0005-${randomUUID()}.sqlite`);
const report = { startedAt: new Date().toISOString(), backupPath, applied: [] };
let remote, reader, backup;
try {
  remote = await openDatabase();
  const migrations = await loadMigrations();
  report.before = await migrationStatus(remote, migrations);
  reader = createClient({ url: process.env.DATABASE_URL, authToken: process.env.DATABASE_AUTH_TOKEN, intMode: 'bigint', concurrency: 1 });
  const read = await reader.transaction('read');
  const snapshot = [];
  let objects;
  try {
    objects = (await read.execute("SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type,name")).rows;
    for (const table of objects.filter(item => item.type === 'table')) {
      assert.ok(!table.name.startsWith('_hidro_verify_'), 'A scratch probe is still active.');
      const result = await read.execute(`SELECT * FROM ${quote(table.name)}`);
      snapshot.push({ name: table.name, columns: result.columns, rows: result.rows, hash: digest(result.rows) });
    }
    if ((await read.execute("SELECT 1 FROM sqlite_master WHERE name='sqlite_sequence'")).rows.length) {
      const result = await read.execute('SELECT * FROM sqlite_sequence');
      snapshot.push({ name: 'sqlite_sequence', columns: result.columns, rows: result.rows, hash: digest(result.rows) });
    }
    await read.commit();
  } finally { if (!read.closed) await read.rollback(); read.close(); }
  await mkdir(resolve('backups'), { recursive: true, mode: 0o700 });
  const file = await open(backupPath, 'wx', 0o600); await file.close();
  backup = createClient({ url: `file:${backupPath.replaceAll('\\', '/')}`, intMode: 'bigint' });
  await backup.execute('PRAGMA foreign_keys=OFF');
  const restore = await backup.transaction('write');
  try {
    for (const table of objects.filter(item => item.type === 'table')) await restore.execute(table.sql);
    for (const table of snapshot) {
      if (table.name === 'sqlite_sequence') await restore.execute('DELETE FROM sqlite_sequence');
      for (const row of table.rows) await restore.execute({
        sql: `INSERT INTO ${quote(table.name)} (${table.columns.map(quote).join(',')}) VALUES (${table.columns.map(() => '?').join(',')})`,
        args: Array.from(row),
      });
    }
    for (const item of objects.filter(item => item.type !== 'table')) await restore.execute(item.sql);
    await restore.commit();
  } finally { if (!restore.closed) await restore.rollback(); restore.close(); }
  await backup.execute('PRAGMA foreign_keys=ON');
  assert.equal((await backup.execute('PRAGMA foreign_key_check')).rows.length, 0);
  assert.equal((await backup.execute('PRAGMA integrity_check')).rows[0][0], 'ok');
  for (const table of snapshot) assert.equal(digest((await backup.execute(`SELECT * FROM ${quote(table.name)}`)).rows), table.hash);
  backup.close(); backup = undefined;
  // Reopen the file to prove the logical restore persisted before touching remote schema.
  backup = createClient({ url: `file:${backupPath.replaceAll('\\', '/')}`, intMode: 'bigint' });
  for (const table of snapshot) assert.equal(digest((await backup.execute(`SELECT * FROM ${quote(table.name)}`)).rows), table.hash);
  report.backupVerified = true;
  report.snapshotTables = snapshot.length;
  report.applied = await migrate(remote, migrations);
  report.after = await migrationStatus(remote, migrations);
  assert.ok(report.after.every(item => item.status === 'applied'));
  for (const table of snapshot.filter(item => !['_schema_migrations', 'sqlite_sequence'].includes(item.name))) {
    const rows = (await reader.execute(`SELECT ${table.columns.map(quote).join(',')} FROM ${quote(table.name)}`)).rows;
    assert.equal(digest(rows), table.hash, `Domain preservation failed: ${table.name}`);
  }
  assert.equal((await remote.execute('PRAGMA foreign_key_check')).rows.length, 0);
  assert.deepEqual(await migrate(remote, migrations), []);
  report.domainDataPreserved = true;
  report.idempotentRerun = true;
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  report.error = { name: error.name, code: error.code ?? null };
  process.exitCode = 1;
} finally {
  remote?.close(); reader?.close(); backup?.close();
  report.finishedAt = new Date().toISOString();
  console.log(JSON.stringify(report, null, 2));
}
