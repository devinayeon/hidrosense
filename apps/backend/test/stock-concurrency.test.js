import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fork } from 'node:child_process';

const now = Date.parse('2026-10-03T03:00:00Z');
const password = 'Concurrent fixture password 2026!';

async function fileFixture(t) {
  const dir = await mkdtemp(join(tmpdir(), 'hidro-stock-concurrent-'));
  const url = `file:${join(dir, 'stock.db').replaceAll('\\', '/')}`;
  t.after(async () => {
    await rm(dir, { recursive: true, force: true, maxRetries: 50, retryDelay: 100 });
  });
  // Keep native handles out of the parent process, including setup and verification.
  const [{ headers }] = await runWriters(t, [{ mode: 'prepare', url, password, now }]);
  return { url, headers };
}

async function runWriters(t, tasks) {
  const writers = tasks.map((task) => {
    const child = fork(new URL('../test-support/stock-worker.js', import.meta.url), [], {
      execArgv: ['--import', 'tsx'], windowsHide: true, stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
    });
    let readyResolve; let readyReject; let resultResolve; let resultReject;
    const ready = new Promise((resolve, reject) => { readyResolve = resolve; readyReject = reject; });
    const result = new Promise((resolve, reject) => { resultResolve = resolve; resultReject = reject; });
    // A boot failure can reject the result before the parent has awaited readiness.
    result.catch(() => {});
    child.on('message', (message) => {
      if (message.ready) readyResolve();
      else if (message.failure) {
        const error = new Error(message.failure); readyReject(error); resultReject(error);
      } else resultResolve(message);
    });
    child.on('error', (error) => { readyReject(error); resultReject(error); });
    const closed = new Promise((resolve) => child.once('close', (code, signal) => {
      const error = new Error(`Stock writer exited before completing IPC: code=${code}, signal=${signal}`);
      readyReject(error); resultReject(error); resolve({ code, signal });
    }));
    child.send(task);
    return { child, ready, result, closed };
  });
  const stop = async () => {
    for (const { child } of writers) if (child.exitCode === null && child.signalCode === null) child.kill();
    await Promise.all(writers.map((writer) => writer.closed));
  };
  t.signal.addEventListener('abort', () => { void stop(); }, { once: true });
  try {
    await Promise.all(writers.map((writer) => writer.ready));
    for (const { child } of writers) child.send('start');
    const responses = await Promise.all(writers.map((writer) => writer.result));
    const exits = await Promise.all(writers.map((writer) => writer.closed));
    for (const exit of exits) assert.equal(exit.code, 0);
    return responses;
  } finally { await stop(); }
}

const competingRequests = (t, url, requests) => runWriters(t, requests.map((request) => ({ url, request, now })));
const inspect = async (t, url) => (await runWriters(t, [{ mode: 'inspect', url, now }]))[0];

test('two independent file-backed writer clients cannot double-deduct available stock', { timeout: 60000 }, async (t) => {
  const { url, headers } = await fileFixture(t);
  const requests = Array.from({ length: 2 }, () => ({ method: 'POST', url: '/api/v1/stok',
    headers: { ...headers, 'idempotency-key': randomUUID() },
    payload: { jenis_stok: 'keluar', details: [{ id_inventaris: '1', jumlah: '0.75', satuan: 'ml' }] } }));
  const outcomes = await competingRequests(t, url, requests);
  assert.deepEqual(outcomes.map((r) => r.status).sort(), [201, 409]);
  assert.equal(outcomes.find((r) => r.status === 409).result.error.code, 'INSUFFICIENT_STOCK');
  assert.deepEqual(await inspect(t, url), { saldo_minor: 25, movements: 2, journal_mode: 'wal' });
});

test('concurrent identical operation keys commit one deduction and replay one stored receipt', { timeout: 60000 }, async (t) => {
  const { url, headers } = await fileFixture(t);
  const request = { method: 'POST', url: '/api/v1/stok',
    headers: { ...headers, 'idempotency-key': randomUUID() },
    payload: { jenis_stok: 'keluar', details: [{ id_inventaris: '1', jumlah: '0.25', satuan: 'ml' }] } };
  const outcomes = await competingRequests(t, url, [request, request]);
  assert.deepEqual(outcomes.map((r) => r.status).sort(), [200, 201]);
  assert.deepEqual(outcomes[0].result.data, outcomes[1].result.data);
  assert.deepEqual(outcomes[0].result.operation, outcomes[1].result.operation);
  assert.deepEqual(await inspect(t, url), { saldo_minor: 75, movements: 2, journal_mode: 'wal' });
});
