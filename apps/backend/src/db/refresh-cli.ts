import { isRemoteUrl, openDatabase } from './client.js';
import { loadMigrations } from './migrate.js';
import { refreshDatabase } from './refresh.js';
import { seed, SEED_CREDENTIALS } from './seed.js';

const args = process.argv.slice(2);
const allowed = args.length === 1 && args[0] === '--allow-data-loss';

let db: Awaited<ReturnType<typeof openDatabase>> | undefined;

try {
  if (!allowed) {
    throw new Error(
      'Perintah ini menghapus semua tabel dan data. Jalankan: npm run db:refresh -- --allow-data-loss',
    );
  }

  // Same guard as the seeder: a remote Turso URL or production mode must opt in
  // explicitly, because this command destroys every row.
  const remote = isRemoteUrl(process.env.DATABASE_URL);
  if ((remote || process.env.NODE_ENV === 'production') && process.env.ALLOW_PROD_SEED !== '1') {
    throw new Error('Refresh database remote/production dicegah tanpa ALLOW_PROD_SEED=1.');
  }

  console.log(`Refresh target: ${process.env.DATABASE_URL ?? 'file:./data/hidrosense.db'}`);
  db = await openDatabase();
  const migrations = await loadMigrations();
  const { dropped, applied } = await refreshDatabase(db, migrations);
  const result = await seed(db);

  console.log(`OK: ${dropped.length} tabel lama dihapus, ${applied.length} migrasi diterapkan ulang.`);
  console.log('OK: database berhasil diseed ulang dengan data uji B000-B009.\n');
  console.log('Akun pengujian tersedia:');
  for (const role of [SEED_CREDENTIALS.petani, SEED_CREDENTIALS.pegawai]) {
    console.log(`- ${role.role}: ${role.username} / ${role.password}`);
  }
  console.log('Data domain siap: 4 jenis, 3 obat, 5 barang inventaris, 1 transaksi stok masuk, 2 penyemaian, 4 meja tanam NFT, 1 pemindahan batch.');
  const created = result.seededUsers.filter((user) => !result.keptExisting.includes(user));
  console.log(`Info: akun dibuat ulang: ${created.length ? created.join(', ') : '(akun lama dipertahankan)'}.`);
} catch (error) {
  console.error('Refresh gagal:', error instanceof Error ? error.message : error);
  process.exitCode = 1;
} finally {
  db?.close();
}