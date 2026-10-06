import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrationStatus } from '../src/db/migrate.js';
import { reconcileStock } from '../src/features/stock/reconcile.ts';

let db;
try {
  db = await openDatabase();
  const status = await migrationStatus(db, await loadMigrations());
  if (status.some(item => item.status === 'pending')) throw new Error('All migrations must be applied before stock reconciliation.');
  const result = await reconcileStock(db);
  console.log(JSON.stringify(result, null, 2));
  if (!result.consistent) process.exitCode = 1;
} catch (error) {
  const message = String(error.message).replace(/(?:libsql|https?):\/\/[^\s]+/g, '[remote database]');
  console.error(`Stock reconciliation failed: ${message}`);
  process.exitCode = 1;
} finally {
  db?.close();
}
