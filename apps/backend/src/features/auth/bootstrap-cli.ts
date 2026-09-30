import { openDatabase } from '../../db/client.js';
import { loadMigrations, migrationStatus } from '../../db/migrate.js';
import { ApiError } from '../../common/errors.js';
import { bootstrapPetani } from './bootstrap.js';

let db: Awaited<ReturnType<typeof openDatabase>> | undefined;
try {
  const input = {
    username: process.env.BOOTSTRAP_USERNAME,
    nama: process.env.BOOTSTRAP_NAME,
    password: process.env.BOOTSTRAP_PASSWORD,
  };
  delete process.env.BOOTSTRAP_PASSWORD;
  db = await openDatabase();
  const status = await migrationStatus(db, await loadMigrations());
  if (status.some((item: { status: string }) => item.status !== 'applied')) throw new Error('Pending migrations');
  await bootstrapPetani(db, input);
  console.log('Akun petani dibuat. Password tidak ditampilkan.');
} catch (error) {
  console.error(error instanceof ApiError ? error.message : 'Bootstrap gagal. Periksa konfigurasi dan migrasi database.');
  process.exitCode = 1;
} finally { db?.close(); }
