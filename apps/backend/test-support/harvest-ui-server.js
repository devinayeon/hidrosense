import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { bearer, fixture } from './fixture.js';

const cleanups = [];
const f = await fixture({ after: (cleanup) => cleanups.push(cleanup) });
f.advance(Date.now() - f.clock());
const today = new Date(f.clock() + 7 * 3600000).toISOString().slice(0, 10);
const dateOffset = (days) => new Date(Date.parse(`${today}T00:00:00Z`) + days * 86400000).toISOString().slice(0, 10);
const sowingDate = dateOffset(-20);
const transferDate = dateOffset(-5);
const estimateDate = dateOffset(25);
await f.db.execute({
  sql: "INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih,status_penyemaian,keterangan) VALUES(1,?,500,'aktif','Fixture panen')",
  args: [sowingDate],
});
await f.db.executeMultiple("INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M-PANEN-1',100),('M-PANEN-2',80)");
let headers;
const requests = [];
const control = { delayMs: 0, failReads: false };
f.app.addHook('onRequest', async (request, reply) => {
  if (request.method !== 'GET' || !/^\/api\/v1\/panen(?:\/|\?|$)/.test(request.url)) return;
  if (control.delayMs) await new Promise((resolve) => setTimeout(resolve, control.delayMs));
  if (control.failReads) return reply.code(503).send({ error: { code: 'FIXTURE_READ_FAILURE', message: 'Laporan panen gagal dimuat. Coba lagi.' } });
});
f.app.addHook('onResponse', async (request, reply) => {
  if (/^\/api\/v1\/panen(?:\/|\?|$)/.test(request.url)) requests.push({
    method: request.method, url: request.url, status: reply.statusCode,
    key: request.headers['idempotency-key'] ?? null, body: request.body ?? null,
  });
});
f.app.post('/__fixture/control', async (request, reply) => {
  const body = request.body;
  if (!body || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).some((key) => !['delayMs', 'failReads'].includes(key)) ||
      (body.delayMs !== undefined && (!Number.isInteger(body.delayMs) || body.delayMs < 0 || body.delayMs > 3000)) ||
      (body.failReads !== undefined && typeof body.failReads !== 'boolean')) return reply.code(400).send({ error: 'Invalid fixture control' });
  Object.assign(control, body);
  return { ...control };
});
f.app.get('/__fixture/state', async () => {
  const read = async (path) => {
    const response = await f.app.inject({ url: `/api/v1/${path}`, headers });
    assert.equal(response.statusCode, 200, response.body);
    return response.json().data;
  };
  return { today, sowingDate, transferDate, estimateDate, control: { ...control }, requests,
    tables: await read('meja-tanam'), transfers: await read('pemindahan'),
    harvests: (await f.db.execute('SELECT * FROM panen')).rows,
    details: (await f.db.execute('SELECT * FROM detail_panen')).rows,
    receipts: (await f.db.execute("SELECT operation_key,operation_type,result_json FROM sync_operations WHERE operation_type LIKE 'panen.%' ORDER BY id_change")).rows,
  };
});
headers = bearer((await f.login('petani')).json().data.access_token);
for (const [tableId, count] of [['1', 100], ['2', 80]]) {
  const result = await f.app.inject({ method: 'POST', url: '/api/v1/pemindahan',
    headers: { ...headers, 'idempotency-key': randomUUID() },
    payload: { id_penyemaian: '1', id_meja: tableId, tanggal_pemindahan: transferDate, jumlah_tanaman: count },
  });
  assert.equal(result.statusCode, 201, result.body);
}
const url = await f.app.listen({ host: '127.0.0.1', port: 0 });
const info = { url, today, sowingDate, transferDate, estimateDate, pid: process.pid };
if (process.argv[2]) await writeFile(process.argv[2], JSON.stringify(info));
console.log(JSON.stringify(info));
let closing = false;
async function close() {
  if (closing) return;
  closing = true;
  for (const cleanup of cleanups.reverse()) await cleanup();
}
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, async () => { await close(); process.exit(0); });
process.on('beforeExit', close);
