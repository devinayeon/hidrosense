import { createClient } from '@libsql/client';
import { chmod, mkdir, stat } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const backendRoot = fileURLToPath(new URL('../../', import.meta.url));

export async function openDatabase({
  url = process.env.DATABASE_URL ?? 'file:./data/hidrosense.db',
  authToken = process.env.DATABASE_AUTH_TOKEN,
} = {}) {
  if (!url || !/^(file:|libsql:\/\/|https:\/\/|:memory:$)/.test(url)) {
    throw new Error('DATABASE_URL must use file:, :memory:, libsql:// or https://.');
  }
  const local = url.startsWith('file:') || url === ':memory:';
  if (!local && !authToken?.trim()) throw new Error('DATABASE_AUTH_TOKEN is required for remote databases.');
  let filePath;
  if (url.startsWith('file:')) {
    if (url.includes('?') || url.includes('#')) throw new Error('Local database URLs must not contain query parameters or fragments.');
    filePath = url.startsWith('file://') ? fileURLToPath(url) : resolve(backendRoot, decodeURIComponent(url.slice(5)));
    await mkdir(dirname(filePath), { recursive: true, mode: 0o700 });
    url = `file:${filePath.replaceAll('\\', '/').split('/').map(encodeURIComponent).join('/')}`;
  }
  // One local connection ensures connection-specific PRAGMAs also apply to transactions.
  const client = createClient({ url, authToken: local ? undefined : authToken, concurrency: 1 });
  try {
    await client.execute('PRAGMA foreign_keys = ON');
    if (local) {
      await client.execute('PRAGMA busy_timeout = 5000');
      if (filePath) await client.execute('PRAGMA journal_mode = WAL');
      if (filePath && process.platform !== 'win32') await chmod(filePath, 0o600);
    }
    if (Number((await client.execute('PRAGMA foreign_keys')).rows[0].foreign_keys) !== 1) {
      throw new Error('Database connection must enforce foreign keys.');
    }
    return client;
  } catch (error) {
    client.close();
    throw error;
  }
}

export async function backupDatabase(client, destination) {
  if (client.protocol !== 'file') throw new Error('This backup command supports local SQLite only. Use Turso backups for remote databases.');
  const path = resolve(destination);
  try {
    await stat(path);
    throw new Error('Backup destination already exists; choose a new path.');
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  // VACUUM INTO creates a consistent snapshot, including committed WAL contents.
  await client.execute({ sql: 'VACUUM INTO ?', args: [path] });
  if (process.platform !== 'win32') await chmod(path, 0o600);
  return path;
}
