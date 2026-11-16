// My own check of slice-A claim A1 over a raw TCP socket. In-memory database only.
import { createServer } from 'node:http';
import { connect } from 'node:net';
const src = 'file:///D:/Dev/Projects/hidrosense/apps/backend/src/';
const { buildApp } = await import(src + 'app.ts');
const { readConfig } = await import(src + 'config.ts');
const { openDatabase } = await import(src + 'db/client.ts');
const { loadMigrations, migrate } = await import(src + 'db/migrate.ts');

async function run(env, target, count, headers = '') {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, await loadMigrations());
  const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent', ...env }) });
  await app.ready();
  const server = createServer((req, res) => app.server.emit('request', req, res));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  const counts = {};
  for (let i = 0; i < count; i += 1) {
    const status = await new Promise((resolve) => {
      const socket = connect(port, '127.0.0.1', () => socket.write(`GET ${target} HTTP/1.1\r\nHost: x\r\n${headers}Connection: close\r\n\r\n`));
      let data = '';
      socket.on('data', (d) => { data += d; });
      socket.on('close', () => resolve(data.split(' ')[1]));
    });
    counts[status] = (counts[status] ?? 0) + 1;
  }
  const rows = Number((await db.execute('SELECT COUNT(*) AS n FROM auth_rate_limits')).rows[0].n);
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
  await app.close();
  return { counts, rate_limit_rows: rows };
}

const out = {};
out.normal_target_125 = await run({}, '/api/v1/auth/me', 125);
out.absolute_target_125 = await run({}, 'http://x/api/v1/auth/me', 125);
out.production_normal = await run({ NODE_ENV: 'production', TRUST_PROXY_HOPS: '1' }, '/api/v1/auth/me', 1);
out.production_absolute = await run({ NODE_ENV: 'production', TRUST_PROXY_HOPS: '1' }, 'http://x/api/v1/auth/me', 1);
console.log(JSON.stringify(out, null, 1));
