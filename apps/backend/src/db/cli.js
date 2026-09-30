import { openDatabase, backupDatabase } from './client.js';
import { loadMigrations, migrate, migrationStatus } from './migrate.js';

const [command, ...args] = process.argv.slice(2);
let client;
try {
  if (!['up', 'down', 'status', 'backup'].includes(command)) throw new Error('Usage: cli.js up|status|down --allow-data-loss|backup <destination>');
  if (command === 'down' && (args.length !== 1 || args[0] !== '--allow-data-loss')) throw new Error('Rollback removes schema/data. Back up first, then explicitly pass --allow-data-loss.');
  if (['up', 'status'].includes(command) && args.length) throw new Error('This command takes no arguments.');
  if (command === 'backup' && args.length !== 1) throw new Error('Usage: npm run db:backup -- <new-backup-file>');
  const migrations = await loadMigrations();
  client = await openDatabase();
  if (command === 'status') {
    console.table(await migrationStatus(client, migrations));
  } else if (command === 'backup') {
    console.log(`Backup created: ${await backupDatabase(client, args[0])}`);
  } else {
    const changed = await migrate(client, migrations, { direction: command, allowDataLoss: command === 'down' });
    console.log(changed.length ? `${command}: ${changed.join(', ')}` : 'No pending changes.');
  }
} catch (error) {
  // CLI diagnostics only: do not print credentials, connection strings or stack traces.
  const message = String(error.message)
    .replace(/(?:libsql|https?):\/\/[^\s]+/g, '[remote database]');
  console.error(message);
  process.exitCode = 1;
} finally {
  client?.close();
}
