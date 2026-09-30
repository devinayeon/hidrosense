import { buildApp } from '../src/app.ts';
import { readConfig } from '../src/config.ts';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { hashPassword } from '../src/common/passwords.ts';

export const password = 'Fixture password 2026!';
const passwordHash = await hashPassword(password);

export async function fixture(t, options = {}) {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, await loadMigrations());
  await db.execute("INSERT INTO roles (nama_role) VALUES ('petani'), ('pegawai')");
  for (const [role, username] of [[1, 'petani'], [2, 'pegawai']]) {
    await db.execute({
      sql: 'INSERT INTO users (id_role,nama,username,password) VALUES (?,?,?,?)',
      args: [role, username, username, passwordHash],
    });
  }
  let now = Date.parse('2026-09-30T00:00:00Z');
  const clock = () => now;
  const config = readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent', ...options.env });
  const app = buildApp({ db, config, clock });
  t.after(async () => { await app.close(); db.close(); });
  return {
    app, db, config, clock,
    advance: (ms) => { now += ms; },
    login: async (username = 'petani') => app.inject({
      method: 'POST', url: '/api/v1/auth/login', payload: { username, password },
    }),
  };
}

export const bearer = (token) => ({ authorization: `Bearer ${token}` });
