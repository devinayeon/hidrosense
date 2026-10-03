import assert from 'node:assert/strict';
import { test } from 'node:test';
import { stockFixture } from '../test-support/stock-fixture.js';
import { reconcileStock } from '../src/features/stock/reconcile.ts';

test('read-only BigInt reconciliation agrees after movement, reversal and zero balance', async (t) => {
  const f = await stockFixture(t);
  const incoming = await f.post(f.movement('masuk', '0.3'));
  assert.equal(incoming.statusCode, 201);
  assert.equal((await f.post(f.movement('keluar', '0.1'))).statusCode, 201);
  assert.equal((await f.post(f.movement('masuk', '0.1'))).statusCode, 201);
  assert.equal((await f.post({ keterangan: 'Zero balance' }, {}, `${incoming.headers.location}/reverse`)).statusCode, 201);
  const before = (await f.db.execute('SELECT * FROM stok_saldo')).rows;
  assert.deepEqual(await reconcileStock(f.db), { consistent: true, checked_details: '4',
    checked_balances: '1', unsealed_headers: '0', mismatches: [] });
  assert.deepEqual((await f.db.execute('SELECT * FROM stok_saldo')).rows, before);
});

test('reconciliation reports projection drift, missing zero rows and unsealed headers without repair', async (t) => {
  const f = await stockFixture(t);
  assert.equal((await f.post(f.movement('masuk', '0.1'))).statusCode, 201);
  await f.db.execute('UPDATE stok_saldo SET saldo_minor=9');
  const drift = await reconcileStock(f.db);
  assert.equal(drift.consistent, false);
  assert.deepEqual(drift.mismatches, [{ id_inventaris: '1', reason: 'PROJECTION_MISMATCH',
    ledger_minor: '10', projection_minor: '9' }]);
  assert.equal((await f.db.execute('SELECT saldo_minor FROM stok_saldo')).rows[0].saldo_minor, 9);
  await f.db.execute('DELETE FROM stok_saldo');
  assert.equal((await reconcileStock(f.db)).mismatches[0].reason, 'PROJECTION_MISSING');
  await f.db.execute("INSERT INTO stok(id_user,jenis_stok) VALUES(2,'masuk')");
  assert.equal((await reconcileStock(f.db)).unsealed_headers, '1');
});
