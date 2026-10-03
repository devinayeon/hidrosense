import { once } from 'node:events';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { hashPassword } from '../src/common/passwords.ts';
import { randomUUID } from 'node:crypto';
import { readConfig } from '../src/config.ts';
import { buildApp } from '../src/app.ts';

// Independent OS processes release every native SQLite/WAL handle on exit.
const [task] = await once(process, 'message');
let app;
let db;
let result;
try {
  db = await openDatabase({ url: task.url });
  app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' }),
    clock: () => task.now });
  await app.ready();
  const started = once(process, 'message');
  process.send({ ready: true });
  await started;
  if (task.mode === 'prepare') {
    await migrate(db, await loadMigrations());
    await db.execute("INSERT INTO roles(nama_role) VALUES ('pegawai')");
    await db.execute({ sql: 'INSERT INTO users(id_role,nama,username,password) VALUES(1,?,?,?)',
      args: ['Writer', 'writer', await hashPassword(task.password)] });
    const login = await app.inject({ method: 'POST', url: '/api/v1/auth/login',
      payload: { username: 'writer', password: task.password } });
    if (login.statusCode !== 200) throw new Error(`Fixture login status ${login.statusCode}`);
    const headers = { authorization: `Bearer ${login.json().data.access_token}` };
    await db.execute("INSERT INTO jenis_inventaris(nama_jenis) VALUES ('Bahan')");
    await db.execute("INSERT INTO inventaris(id_jenis_inventaris,nama_barang,satuan) VALUES(1,'Bahan','ml')");
    const incoming = await app.inject({ method: 'POST', url: '/api/v1/stok',
      headers: { ...headers, 'idempotency-key': randomUUID() },
      payload: { jenis_stok: 'masuk', details: [{ id_inventaris: '1', jumlah: '1', satuan: 'ml' }] } });
    if (incoming.statusCode !== 201) throw new Error(`Fixture incoming status ${incoming.statusCode}`);
    result = { headers };
  } else if (task.mode === 'inspect') {
    result = {
      saldo_minor: (await db.execute('SELECT saldo_minor FROM stok_saldo')).rows[0].saldo_minor,
      movements: (await db.execute('SELECT COUNT(*) AS n FROM stok')).rows[0].n,
      journal_mode: (await db.execute('PRAGMA journal_mode')).rows[0].journal_mode,
    };
  } else {
    let response = await app.inject(task.request);
    // Retry contention with the identical persisted operation key and payload.
    if (response.statusCode === 503 && response.json().error.code === 'STOCK_WRITE_UNAVAILABLE') {
      response = await app.inject(task.request);
    }
    result = { status: response.statusCode, result: response.json() };
  }
} catch (error) {
  result = { failure: String(error) };
} finally {
  try { if (app) await app.close(); else db?.close(); }
  catch (error) { result = { failure: String(error) }; }
}
// Flush the result before disconnecting IPC. Parent waits for OS close before deleting files.
await new Promise((resolve, reject) => process.send(result, (error) => error ? reject(error) : resolve()));
process.disconnect();
