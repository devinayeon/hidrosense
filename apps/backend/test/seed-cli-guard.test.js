import assert from 'node:assert/strict';
import { test } from 'node:test';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { isRemoteUrl } from '../src/db/client.js';

const backendRoot = fileURLToPath(new URL('..', import.meta.url));

test('isRemoteUrl classifies every accepted database scheme', () => {
  const cases = [
    ['libsql://farm-example.turso.io', true],
    ['https://farm-example.turso.io', true],
    ['LIBSQL://farm-example.turso.io', false],
    ['file:./data/hidrosense.db', false],
    [':memory:', false],
    ['https:/broken', false],
    ['', false],
    [undefined, false],
    [null, false],
  ];
  for (const [url, expected] of cases) assert.equal(isRemoteUrl(url), expected, String(url));
});

test('seeding a remote database stops before opening a connection', () => {
  const env = { ...process.env, DATABASE_URL: 'libsql://contoh.invalid', NODE_ENV: 'development' };
  delete env.ALLOW_PROD_SEED;
  const result = spawnSync(process.execPath, ['--import', 'tsx', 'src/db/seed-cli.ts'], {
    cwd: backendRoot, env, encoding: 'utf8', timeout: 60000,
  });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /dicegah/);
  assert.equal(result.stdout.includes('berhasil diseed'), false);
});
