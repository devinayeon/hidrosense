import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

const all = await loadMigrations();

test('sales migration adds buyer/status/amount columns and rolls back cleanly', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, all.slice(0, 12));
  await db.executeMultiple(`
    INSERT INTO roles(nama_role) VALUES('petani');
    INSERT INTO users(id_role,nama,username,password) VALUES(1,'Petani','petani','hash');
    INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(1,'2026-09-01',10);
    INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M1',10);
    INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-16',10);
    INSERT INTO panen(id_user,tanggal_panen) VALUES(1,'2026-09-20');
    INSERT INTO detail_panen(id_panen,id_pemindahan,jumlah_tanaman,berat,berat_minor) VALUES(1,1,5,1.80,180);
    INSERT INTO penjualan(id_user,tanggal_penjualan) VALUES(1,'2026-09-25');
    INSERT INTO detail_penjualan(id_penjualan,id_panen,jumlah_kg,harga_per_kg) VALUES(1,1,1.00,20000);
  `);
  await migrate(db, all);

  const sale = (await db.execute('SELECT pembeli,status_pembayaran FROM penjualan WHERE id_penjualan=1')).rows[0];
  assert.equal(sale.pembeli, '');
  assert.equal(sale.status_pembayaran, 'lunas');
  const legacy = (await db.execute('SELECT jumlah_kg_minor,harga_per_kg_minor FROM detail_penjualan WHERE id_detail_penjualan=1')).rows[0];
  assert.equal(legacy.jumlah_kg_minor, null);
  assert.equal(legacy.harga_per_kg_minor, null);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM sqlite_master WHERE type='index' AND name='idx_penjualan_date_id'")).rows[0].n, 1);

  await db.executeMultiple(`
    INSERT INTO penjualan(id_user,tanggal_penjualan,pembeli,status_pembayaran) VALUES(1,'2026-09-26','Toko','belum_lunas');
    INSERT INTO detail_penjualan(id_penjualan,id_panen,jumlah_kg,harga_per_kg,jumlah_kg_minor,harga_per_kg_minor) VALUES(2,1,0.50,21000,50,2100000);
  `);
  assert.equal((await db.execute('SELECT jumlah_kg_minor FROM detail_penjualan WHERE id_detail_penjualan=2')).rows[0].jumlah_kg_minor, 50);

  await migrate(db, all, { direction: 'down', allowDataLoss: true });
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM penjualan')).rows[0].n, 2);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM pragma_table_info('penjualan') WHERE name IN ('pembeli','status_pembayaran')")).rows[0].n, 0);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM pragma_table_info('detail_penjualan') WHERE name IN ('jumlah_kg_minor','harga_per_kg_minor')")).rows[0].n, 0);

  await migrate(db, all);
  assert.equal((await db.execute('SELECT pembeli FROM penjualan WHERE id_penjualan=2')).rows[0].pembeli, '');
  assert.equal((await db.execute('SELECT status_pembayaran FROM penjualan WHERE id_penjualan=2')).rows[0].status_pembayaran, 'lunas');
});
