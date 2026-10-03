import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { stockFixture, expectError, stockState } from '../test-support/stock-fixture.js';
import { stockWrite } from '../src/features/stock/write.ts';
import { recordMovement } from '../src/features/stock/service.ts';
import { createStockSchema } from '../src/features/stock/contracts.ts';

function unavailable(code) { return Object.assign(new Error('private driver failure'), { code }); }

test('supported transaction availability errors return same-key retry contract and no effect', async (t) => {
  const f = await stockFixture(t);
  const transaction = f.db.transaction.bind(f.db);
  const state = await stockState(f.db);
  const headers = { 'idempotency-key': randomUUID() };
  for (const code of ['SQLITE_BUSY', 'TRANSACTION_ACTIVE', 'HRANA_CLOSED_ERROR', 'SERVER_ERROR']) {
    f.db.transaction = async () => { throw unavailable(code); };
    const response = await f.post(f.movement(), headers);
    expectError(response, 503, 'STOCK_WRITE_UNAVAILABLE');
    assert.equal(response.headers['retry-after'], '1');
    assert.doesNotMatch(response.body, /private driver|SQLITE_BUSY|TRANSACTION_ACTIVE/);
  }
  f.db.transaction = transaction;
  assert.deepEqual(await stockState(f.db), state);
  assert.equal((await f.post(f.movement(), headers)).statusCode, 201);
});

test('unexpected programming, constraint and closed-transaction errors remain generic 500', async (t) => {
  const f = await stockFixture(t);
  const transaction = f.db.transaction.bind(f.db);
  for (const error of [new TypeError('private code bug'), unavailable('SQLITE_CONSTRAINT'), unavailable('TRANSACTION_CLOSED')]) {
    f.db.transaction = async () => { throw error; };
    expectError(await f.post(f.movement()), 500, 'INTERNAL_ERROR');
  }
  f.db.transaction = transaction;
});

test('actual fetch response loss through Undici cause chain produces retryable 503', async (t) => {
  const f = await stockFixture(t);
  const server = createServer((request) => request.socket.destroy());
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  let transportError;
  try { await fetch(`http://127.0.0.1:${server.address().port}`); }
  catch (error) { transportError = error; }
  assert.equal(transportError.cause.code, 'UND_ERR_SOCKET');
  const transaction = f.db.transaction.bind(f.db);
  f.db.transaction = async () => { throw transportError; };
  const headers = { 'idempotency-key': randomUUID() };
  const response = await f.post(f.movement(), headers);
  expectError(response, 503, 'STOCK_WRITE_UNAVAILABLE');
  assert.equal(response.headers['retry-after'], '1');
  f.db.transaction = transaction;
  assert.equal((await f.post(f.movement(), headers)).statusCode, 201);
});

test('ambiguous commit after durable success resolves through original receipt on retry', async (t) => {
  const f = await stockFixture(t);
  const transaction = f.db.transaction.bind(f.db);
  f.db.transaction = async (mode) => {
    const tx = await transaction(mode);
    return new Proxy(tx, { get(target, property) {
      if (property === 'commit') return async () => {
        await target.commit();
        throw unavailable('ECONNRESET');
      };
      const value = Reflect.get(target, property);
      return typeof value === 'function' ? value.bind(target) : value;
    } });
  };
  const headers = { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() };
  const payload = f.movement('masuk', '0.25');
  const uncertain = await f.post(payload, headers);
  expectError(uncertain, 503, 'STOCK_WRITE_UNAVAILABLE');
  f.db.transaction = transaction;
  assert.equal((await f.balance()).saldo, '0.25');
  const saved = await stockState(f.db);
  const replay = await f.post(payload, headers);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.equal(replay.json().replayed, true);
  assert.equal(replay.json().data.details[0].jumlah, '0.25');
  assert.deepEqual(await stockState(f.db), saved);
});

test('rollback failure preserves the original retryable write failure', async (t) => {
  const f = await stockFixture(t);
  const transaction = f.db.transaction.bind(f.db);
  const before = await stockState(f.db);
  f.db.transaction = async (mode) => {
    const tx = await transaction(mode);
    return new Proxy(tx, { get(target, property) {
      if (property === 'commit') return async () => { throw unavailable('ECONNRESET'); };
      if (property === 'rollback') return async () => {
        await target.rollback();
        throw unavailable('TRANSACTION_CLOSED');
      };
      const value = Reflect.get(target, property);
      return typeof value === 'function' ? value.bind(target) : value;
    } });
  };
  const headers = { 'idempotency-key': randomUUID() };
  const response = await f.post(f.movement(), headers);
  expectError(response, 503, 'STOCK_WRITE_UNAVAILABLE');
  assert.equal(response.headers['retry-after'], '1');
  f.db.transaction = transaction;
  assert.deepEqual(await stockState(f.db), before);
  assert.equal((await f.post(f.movement(), headers)).statusCode, 201);
});

test('stock boundary handles real local connection contention without a successful receipt', async (t) => {
  const f = await stockFixture(t);
  const tx = await f.db.transaction('write');
  const payload = createStockSchema.parse(f.movement());
  const request = { headers: { ...f.headers, 'idempotency-key': randomUUID() } };
  try {
    await assert.rejects(stockWrite(f.db, request, f.clock, 'stok.create', payload,
      (active, actorId, now) => recordMovement(active, actorId, now, payload)),
    (error) => error.statusCode === 503 && error.code === 'STOCK_WRITE_UNAVAILABLE');
  } finally { await tx.rollback(); tx.close(); }
  assert.equal((await f.balance()).saldo, '0');
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM stok')).rows[0].n, 0);
});

test('movement detail ordering is numeric and exact ID/query grammars reject final newline', async (t) => {
  const f = await stockFixture(t);
  await f.db.execute({ sql: `INSERT INTO inventaris(id_inventaris,id_jenis_inventaris,nama_barang,satuan)
    SELECT 10,id_jenis_inventaris,'Ten','kg' FROM inventaris WHERE id_inventaris=?`, args: [f.items[0].id_inventaris] });
  const response = await f.post({ jenis_stok: 'masuk', details: [
    { id_inventaris: '10', jumlah: '0.1', satuan: 'kg' }, ...f.movement('masuk', '0.2', f.items[1]).details,
  ] });
  assert.equal(response.statusCode, 201, response.body);
  assert.deepEqual(response.json().data.details.map((line) => line.id_inventaris), ['2', '10']);
  const detail = await f.app.inject({ url: response.headers.location, headers: f.headers });
  assert.deepEqual(detail.json().data.details, response.json().data.details);
  expectError(await f.post({ jenis_stok: 'masuk', details: [{ id_inventaris: '1\n', jumlah: '1', satuan: 'kg' }] }),
    400, 'VALIDATION_ERROR');
  for (const suffix of ['?page=1%0A', '?limit=2%0A', '?id_inventaris=1%0A']) {
    expectError(await f.app.inject({ url: `/api/v1/stok${suffix}`, headers: f.headers }), 400, 'VALIDATION_ERROR');
  }
});
