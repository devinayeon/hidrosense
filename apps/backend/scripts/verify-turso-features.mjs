import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { openDatabase } from '../src/db/client.js';
import { hashPassword } from '../src/common/passwords.ts';
import { authenticate, createSession } from '../src/common/sessions.ts';
import { getAccount, updateAccount } from '../src/features/accounts/store.ts';
import { reserveClientId, executeDomainMutation } from '../src/common/sync.ts';
import { getJenis, getObat, getInventaris, assertObatExists } from '../src/features/inventory/store.ts';

if (process.env.TURSO_LIVE_VERIFY !== '1' || !/^(libsql|https):/.test(process.env.DATABASE_URL ?? '')) {
  throw new Error('Requires TURSO_LIVE_VERIFY=1 and a remote DATABASE_URL.');
}
const username = `verify_${randomUUID().replaceAll('-', '')}`;
const password = await hashPassword(randomUUID());
const now = Date.now();
const report = { startedAt: new Date().toISOString(), checks: [] };
let db, peer;
async function seed(tx) {
  await tx.execute("INSERT INTO roles(nama_role) VALUES ('petani') ON CONFLICT(nama_role) DO NOTHING");
  const row = (await tx.execute({
    sql: `INSERT INTO users(id_role,nama,username,password) SELECT id_role,?,?,? FROM roles WHERE nama_role='petani'
      RETURNING CAST(id_user AS TEXT) AS id_user,username,password,status_aktif`,
    args: [username, username, password],
  })).rows[0];
  return row;
}
async function rollbackProbe(effect) {
  const tx = await db.transaction('write');
  try { await effect(tx); }
  finally { if (!tx.closed) await tx.rollback(); tx.close(); }
  assert.equal((await peer.execute({ sql: 'SELECT 1 FROM users WHERE username IN (?,?)', args: [username, `${username}_new`] })).rows.length, 0);
  const leftovers = await peer.execute({
    sql: `SELECT 1 FROM obat WHERE nama_obat=? UNION ALL
      SELECT 1 FROM jenis_inventaris WHERE nama_jenis=? UNION ALL
      SELECT 1 FROM inventaris WHERE nama_barang=?`, args: [username, username, username],
  });
  assert.equal(leftovers.rows.length, 0);
}
function pass(name) { report.checks.push({ name, status: 'passed' }); }
try {
  db = await openDatabase(); peer = await openDatabase();
  await rollbackProbe(async tx => {
    const user = await seed(tx);
    const session = await createSession(tx, user, now);
    const bearer = `Bearer ${session.access_token}`;
    const principal = await authenticate(tx, bearer, now);
    assert.equal(principal.id_user, user.id_user);
    assert.equal(principal.role, 'petani');
    pass('B002 session creation and authenticated principal on Turso');
    assert.equal((await getAccount(tx, user.id_user, 'petani')).username, username);
    await updateAccount(tx, user.id_user, { username: `${username}_new` });
    assert.equal((await getAccount(tx, user.id_user, 'petani')).username, `${username}_new`);
    await assert.rejects(authenticate(tx, bearer, now), error => error.statusCode === 401 || error.status === 401);
    pass('B003 account update revokes sessions atomically');
  });
  pass('auth/account probe rollback visible to independent client');
  await rollbackProbe(async tx => {
    const user = await seed(tx);
    const clientId = randomUUID();
    const operation = { operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {}, resource_type: 'obat', client_id: clientId };
    const reserved = await reserveClientId(tx, user.id_user, operation, now);
    const replay = await reserveClientId(tx, user.id_user, { ...operation, client_id: clientId.toUpperCase() }, now);
    assert.equal(replay.replayed, true);
    assert.equal(replay.data.public_id, reserved.data.public_id);
    await assert.rejects(reserveClientId(tx, user.id_user, { ...operation, resource_type: 'inventaris' }, now), error => error.statusCode === 409 || error.status === 409);
    pass('B004 reservation replay, UUID casing and conflict');
    const create = { operation_key: randomUUID(), operation_type: 'obat.create', payload: { nama_obat: username }, resource_type: 'obat', client_id: clientId };
    let effects = 0;
    const mutation = { resourceType: 'obat', idField: 'id_obat', effect: async () => {
      effects++;
      const row = (await tx.execute({ sql: 'INSERT INTO obat(nama_obat) VALUES (?) RETURNING CAST(id_obat AS TEXT) AS id', args: [username] })).rows[0];
      return getObat(tx, row.id);
    } };
    const created = await executeDomainMutation(tx, user.id_user, create, now, mutation);
    assert.equal(created.data.public_id, reserved.data.public_id);
    assert.equal(created.data.version, '1');
    const createdReplay = await executeDomainMutation(tx, user.id_user, create, now, mutation);
    assert.equal(createdReplay.replayed, true); assert.equal(effects, 1);
    const type = (await tx.execute({ sql: 'INSERT INTO jenis_inventaris(nama_jenis) VALUES (?) RETURNING CAST(id_jenis_inventaris AS TEXT) AS id', args: [username] })).rows[0];
    assert.equal((await getJenis(tx, type.id)).status_aktif, 1);
    const item = (await tx.execute({
      sql: 'INSERT INTO inventaris(id_jenis_inventaris,id_obat,nama_barang,satuan,stok_minimum) VALUES (?,?,?,?,?) RETURNING CAST(id_inventaris AS TEXT) AS id',
      args: [type.id, created.data.id_obat, username, 'unit', '0.25'],
    })).rows[0];
    const itemData = await getInventaris(tx, item.id);
    assert.equal(itemData.id_obat, created.data.id_obat); assert.equal(itemData.stok_minimum, '0.25');
    const deactivated = await executeDomainMutation(tx, user.id_user,
      { operation_key: randomUUID(), operation_type: 'obat.deactivate', payload: { id: created.data.id_obat } }, now,
      { resourceType: 'obat', domainId: created.data.id_obat, idField: 'id_obat', effect: async () => {
        await tx.execute({ sql: 'UPDATE obat SET status_aktif=0 WHERE id_obat=?', args: [created.data.id_obat] });
        return getObat(tx, created.data.id_obat);
      } });
    assert.equal(deactivated.data.version, '2');
    await assert.rejects(assertObatExists(tx, created.data.id_obat), error => error.statusCode === 422 || error.status === 422);
    assert.equal((await getInventaris(tx, item.id)).id_obat, created.data.id_obat);
    pass('B005 domain mutation, receipt replay, version, references, decimals and history');
  });
  pass('sync/inventory probe rollback visible to independent client');
  report.status = 'passed';
} catch (error) {
  report.status = 'failed'; report.error = { name: error.name, code: error.code ?? null };
  process.exitCode = 1;
} finally {
  db?.close(); peer?.close(); report.finishedAt = new Date().toISOString();
  console.log(JSON.stringify(report, null, 2));
}
