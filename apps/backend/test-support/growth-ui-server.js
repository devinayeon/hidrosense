import { writeFile } from 'node:fs/promises';
import { fixture } from './fixture.js';

const cleanups = [];
const f = await fixture({ after: (fn) => cleanups.push(fn) });
f.advance(Date.now() - f.clock());
const today = new Date(f.clock() + 7 * 3600000).toISOString().slice(0, 10);
const sowingDate = new Date(Date.parse(`${today}T00:00:00Z`) - 20 * 86400000).toISOString().slice(0, 10);
await f.db.execute({
  sql: "INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih,status_penyemaian,keterangan) VALUES(1,?,600,'aktif','QA pertumbuhan')",
  args: [sowingDate],
});
const requests = [];
f.app.addHook('onResponse', async (request, reply) => {
  if (/\/api\/v1\/(meja-tanam|pemindahan|kerusakan)/.test(request.url)) {
    requests.push({ method: request.method, url: request.url, status: reply.statusCode,
      key: request.headers['idempotency-key'] ?? null, body: request.body ?? null });
  }
});
f.app.get('/__fixture/state', async () => ({ today, sowingDate, requests,
  tables: (await f.db.execute('SELECT * FROM meja_tanam')).rows,
  transfers: (await f.db.execute('SELECT * FROM pemindahan')).rows,
  damages: (await f.db.execute('SELECT * FROM kerusakan_tanaman')).rows,
  receipts: (await f.db.execute('SELECT operation_key,operation_type FROM sync_operations')).rows,
}));
const url = await f.app.listen({ host: '127.0.0.1', port: 0 });
const info = { url, today, sowingDate, pid: process.pid };
if (process.argv[2]) await writeFile(process.argv[2], JSON.stringify(info));
console.log(JSON.stringify(info));
process.on('SIGTERM', async () => {
  for (const cleanup of cleanups.reverse()) await cleanup();
  process.exit(0);
});
