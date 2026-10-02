import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate, migrationStatus } from '../src/db/migrate.js';
import { buildApp } from '../src/app.ts';
import { readConfig } from '../src/config.ts';
import { accountColumns } from '../src/features/accounts/store.ts';
import { inventarisColumns } from '../src/features/inventory/store.ts';

// Opt-in live probe. Only uniquely named scratch tables receive writes.
if (process.env.TURSO_LIVE_VERIFY !== '1' || !/^(libsql|https):/.test(process.env.DATABASE_URL ?? '')) {
  throw new Error('Requires TURSO_LIVE_VERIFY=1 and a remote DATABASE_URL.');
}
const prefix = `_hidro_verify_${randomBytes(8).toString('hex')}`;
const parent = `${prefix}_parent`;
const child = `${prefix}_child`;
const report = { startedAt: new Date().toISOString(), checks: [], scratchPrefix: prefix };
let remote, peer, local;
function pass(name, details = {}) { report.checks.push({ name, status: 'passed', ...details }); }
function safeError(error) { return { name: error.name, code: error.code ?? null }; }
async function schema(db) {
  const rows = (await db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name")).rows;
  return rows.filter(row => !String(row.name).startsWith('_hidro_verify_'));
}
const normalize = sql => String(sql ?? '').replace(/\s+/g, ' ').trim();
try {
  const start = performance.now();
  remote = await openDatabase();
  report.connectionMs = Math.round(performance.now() - start);
  pass('remote connection and foreign keys');
  report.sqliteVersion = (await remote.execute('SELECT sqlite_version() AS version')).rows[0].version;
  const migrations = await loadMigrations();
  report.migrations = await migrationStatus(remote, migrations);
  pass('migration history checksum validation');
  local = await openDatabase({ url: ':memory:' });
  await migrate(local, migrations);
  const expected = await schema(local);
  const actual = await schema(remote);
  const mismatches = expected.filter(item => !actual.some(row => row.type === item.type && row.name === item.name && normalize(row.sql) === normalize(item.sql)))
    .map(item => ({ type: item.type, name: item.name }));
  report.schema = { expectedObjects: expected.length, remoteObjects: actual.length, mismatches,
    unexpectedObjects: actual.filter(item => !expected.some(row => row.name === item.name)).map(item => item.name) };
  report.checks.push({ name: 'deployed schema matches B000-B005', status: mismatches.length ? 'failed' : 'passed' });
  report.featureQueries = [];
  const featureQueries = [
    ['B002 sessions', 'SELECT id_session FROM auth_sessions LIMIT 0'],
    ['B003 account projection', `SELECT ${accountColumns} FROM users u JOIN roles r ON r.id_role=u.id_role LIMIT 0`],
    ['B004 sync metadata', 'SELECT m.public_id,v.version,o.operation_key FROM sync_id_maps m LEFT JOIN sync_resource_versions v ON v.public_id=m.public_id AND v.resource_type=m.resource_type LEFT JOIN sync_operations o ON o.id_user=m.id_user LIMIT 0'],
    ['B005 inventory projection', `SELECT ${inventarisColumns} FROM inventaris i JOIN jenis_inventaris j ON j.id_jenis_inventaris=i.id_jenis_inventaris LEFT JOIN obat o ON o.id_obat=i.id_obat LIMIT 0`],
  ];
  for (const [name, sql] of featureQueries) {
    await local.execute(sql); // Validate the probe against the current schema first.
    try { await remote.execute(sql); report.featureQueries.push({ name, status: 'passed' }); }
    catch (error) { report.featureQueries.push({ name, status: 'blocked', error: safeError(error) }); }
  }
  const app = buildApp({ db: await openDatabase(), config: readConfig({ LOG_LEVEL: 'silent', NODE_ENV: 'test' }) });
  try {
    const live = await app.inject('/health/live');
    const ready = await app.inject('/health/ready');
    assert.equal(live.statusCode, 200);
    assert.equal(ready.statusCode, report.migrations.some(item => item.status === 'pending') ? 503 : 200);
    if (ready.statusCode === 503) assert.equal(ready.json().error.code, 'NOT_READY');
    report.health = { live: live.statusCode, ready: ready.statusCode };
    pass('B001 health and readiness reflect remote migration state');
  } finally { await app.close(); }
  assert.equal((await remote.execute('PRAGMA foreign_key_check')).rows.length, 0);
  pass('remote foreign key integrity');
  assert.equal((await remote.execute({ sql: 'SELECT CAST(? AS INTEGER) AS small, CAST(CAST(? AS INTEGER) AS TEXT) AS big',
    args: [42, '9223372036854775807'] })).rows[0].big, '9223372036854775807');
  pass('bound queries and signed 64-bit TEXT projection');
  const samples = [];
  for (let i = 0; i < 12; i++) {
    const started = performance.now();
    assert.equal((await remote.execute({ sql: 'SELECT ? AS value', args: [i] })).rows[0].value, i);
    samples.push(Math.round(performance.now() - started));
  }
  const sorted = [...samples].sort((a, b) => a - b);
  report.latencyMs = { samples, min: sorted[0], median: (sorted[5] + sorted[6]) / 2, p95: sorted[11], max: sorted[11] };
  pass('12 sequential remote queries');
  peer = await openDatabase();
  let tx = await remote.transaction('write');
  try {
    await tx.execute(`CREATE TABLE ${parent} (id INTEGER PRIMARY KEY, marker TEXT NOT NULL, version INTEGER NOT NULL)`);
    await tx.execute({ sql: `INSERT INTO ${parent} VALUES (1,?,1)`, args: [prefix] });
    await tx.rollback();
  } finally { if (!tx.closed) await tx.rollback(); tx.close(); }
  assert.equal((await peer.execute({ sql: 'SELECT 1 FROM sqlite_master WHERE name=?', args: [parent] })).rows.length, 0);
  pass('DDL and DML rollback observed by independent client');
  tx = await remote.transaction('write');
  const commitStarted = performance.now();
  try {
    assert.equal(Number((await tx.execute('PRAGMA foreign_keys')).rows[0].foreign_keys), 1);
    await tx.execute(`CREATE TABLE ${parent} (id INTEGER PRIMARY KEY, marker TEXT NOT NULL, version INTEGER NOT NULL)`);
    await tx.execute(`CREATE TABLE ${child} (id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL REFERENCES ${parent}(id), amount NUMERIC)`);
    await tx.execute({ sql: `INSERT INTO ${parent} VALUES (?,?,1)`, args: ['9223372036854775807', prefix] });
    await tx.execute({ sql: `INSERT INTO ${child} VALUES (1,?,?)`, args: ['9223372036854775807', '0.125'] });
    await tx.commit();
  } finally { if (!tx.closed) await tx.rollback(); tx.close(); }
  const row = (await peer.execute(`SELECT CAST(id AS TEXT) AS id,marker FROM ${parent}`)).rows[0];
  assert.equal(row.id, '9223372036854775807');
  assert.equal(row.marker, prefix);
  assert.equal((await peer.execute(`SELECT CAST(amount AS TEXT) AS amount FROM ${child}`)).rows[0].amount, '0.125');
  pass('atomic multi-table commit and persistence across independent clients');
  report.commitTransactionMs = Math.round(performance.now() - commitStarted);
  tx = await remote.transaction('write');
  try {
    const version = (await tx.execute({ sql: `INSERT INTO ${parent} VALUES (?,?,1) ON CONFLICT(id) DO UPDATE SET version=version+1 RETURNING CAST(version AS TEXT) AS version`,
      args: ['9223372036854775807', prefix] })).rows[0].version;
    assert.equal(version, '2');
    await assert.rejects(tx.execute(`INSERT INTO ${child} VALUES (2,123,1)`), error => String(error.code).includes('CONSTRAINT'));
    await tx.rollback();
  } finally { if (!tx.closed) await tx.rollback(); tx.close(); }
  assert.equal((await peer.execute(`SELECT version FROM ${parent}`)).rows[0].version, 1);
  pass('UPSERT RETURNING, FK rejection and rollback of preceding version mutation');
} catch (error) {
  report.checks.push({ name: 'probe execution', status: 'failed', error: safeError(error) });
  process.exitCode = 1;
} finally {
  if (remote) {
    try {
      const tx = await remote.transaction('write');
      try {
        await tx.execute(`DROP TABLE IF EXISTS ${child}`);
        await tx.execute(`DROP TABLE IF EXISTS ${parent}`);
        await tx.commit();
      } finally { if (!tx.closed) await tx.rollback(); tx.close(); }
      const count = (await (peer ?? remote).execute({ sql: 'SELECT 1 FROM sqlite_master WHERE name IN (?,?)', args: [parent, child] })).rows.length;
      assert.equal(count, 0);
      pass('scratch cleanup verified');
    } catch (error) { report.checks.push({ name: 'scratch cleanup', status: 'failed', error: safeError(error) }); process.exitCode = 1; }
  }
  peer?.close(); remote?.close(); local?.close();
  report.finishedAt = new Date().toISOString();
  if (report.checks.some(check => check.status === 'failed')
    || report.featureQueries?.some(query => query.status !== 'passed')) process.exitCode = 1;
  console.log(JSON.stringify(report, null, 2));
}
