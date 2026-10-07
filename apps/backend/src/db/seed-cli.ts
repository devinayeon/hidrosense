import { openDatabase } from './client.js';
import { loadMigrations, migrationStatus } from './migrate.js';
import { seed, SEED_CREDENTIALS } from './seed.js';

let db: Awaited<ReturnType<typeof openDatabase>> | undefined;

try {
  if (process.env.NODE_ENV === 'production' && process.env.ALLOW_PROD_SEED !== '1') {
    console.error('ERROR: Seeding di lingkungan production dicegah tanpa ALLOW_PROD_SEED=1.');
    process.exit(1);
  }

  db = await openDatabase();
  const status = await migrationStatus(db, await loadMigrations());
  if (status.some((item: { status: string }) => item.status !== 'applied')) {
    throw new Error('Migrasi database belum lengkap. Jalankan "npm run db:migrate" terlebih dahulu.');
  }

  const result = await seed(db);
  console.log('✅ Database berhasil diseed dengan data uji B000–B009!\n');
  console.log('📋 Akun Pengujian Tersedia:');
  console.log(`1. Petani (Admin/Owner):`);
  console.log(`   - Username: ${SEED_CREDENTIALS.petani.username}`);
  console.log(`   - Password: ${SEED_CREDENTIALS.petani.password}`);
  console.log(`   - Role    : ${SEED_CREDENTIALS.petani.role}\n`);
  console.log(`2. Pegawai (Staf Kebun):`);
  console.log(`   - Username: ${SEED_CREDENTIALS.pegawai.username}`);
  console.log(`   - Password: ${SEED_CREDENTIALS.pegawai.password}`);
  console.log(`   - Role    : ${SEED_CREDENTIALS.pegawai.role}\n`);
  console.log('🌱 Data domain siap: 4 jenis, 3 obat, 5 barang inventaris, 1 transaksi stok masuk, 2 penyemaian, 4 meja tanam NFT, 1 pemindahan batch.');
} catch (error) {
  console.error('Seeder gagal:', error instanceof Error ? error.message : error);
  process.exitCode = 1;
} finally {
  db?.close();
}
