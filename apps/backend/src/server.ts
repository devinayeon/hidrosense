import { buildApp } from './app.js';
import { readConfig } from './config.js';
import { openDatabase } from './db/client.js';
import { loadMigrations, migrationStatus } from './db/migrate.js';

let app: ReturnType<typeof buildApp> | undefined;
let db: Awaited<ReturnType<typeof openDatabase>> | undefined;
try {
  const config = readConfig();
  db = await openDatabase();
  const status = await migrationStatus(db, await loadMigrations());
  if (status.some((item: { status: string }) => item.status !== 'applied')) throw new Error('Run db:migrate before starting the API.');
  // Remove only expired infrastructure records, never domain data.
  await db.execute({ sql: 'DELETE FROM auth_sessions WHERE refresh_expires_at<=?', args: [Date.now()] });
  await db.execute({ sql: 'DELETE FROM auth_rate_limits WHERE resets_at<=?', args: [Date.now()] });
  app = buildApp({ db, config });
  let stopping = false;
  const shutdown = async () => {
    if (stopping) return;
    stopping = true;
    const deadline = setTimeout(() => process.exit(1), 10000).unref();
    try { await app!.close(); } catch { process.exitCode = 1; }
    finally { clearTimeout(deadline); }
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
  await app.listen({ host: config.host, port: config.port });
} catch {
  console.error('API startup failed. Check configuration, database connectivity, and run npm run db:migrate.');
  if (app) await app.close(); else db?.close();
  process.exitCode = 1;
}
