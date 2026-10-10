import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { migrate,loadMigrations } from '../src/db/migrate.js';
import { getHarvest } from '../src/features/harvest/store.ts';
const all=await loadMigrations();
async function legacy(t,weight) {
 const db=await openDatabase({url:':memory:'});t.after(()=>db.close());await migrate(db,all.slice(0,10));
 await db.executeMultiple(`INSERT INTO roles(nama_role) VALUES('petani');INSERT INTO users(id_role,nama,username,password) VALUES(1,'a','a','x');INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(1,'2026-09-01',100);INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M',100);INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-10',100);INSERT INTO panen(id_user,tanggal_panen) VALUES(1,'2026-09-20');`);
 await db.execute({sql:'INSERT INTO detail_panen(id_panen,id_pemindahan,jumlah_tanaman,berat) VALUES(1,1,10,?)',args:[weight]});return db;
}
test('legacy exact weights become layak, reject remains unknown and rollback preserves legacy',async t=>{
 const db=await legacy(t,'12.25');await migrate(db,all);const d=await getHarvest(db,'1');assert.equal(d.berat_layak,'12.25');assert.equal(d.berat_total,null);assert.equal(d.berat_reject,null);assert.equal(d.details[0].berat_total,null);assert.equal(d.version,'1');assert.ok(d.public_id);
 await migrate(db,all,{direction:'down',allowDataLoss:true});assert.equal((await db.execute('SELECT CAST(berat AS TEXT) AS weight FROM detail_panen')).rows[0].weight,'12.25');assert.equal((await db.execute("SELECT COUNT(*) AS n FROM pragma_table_info('detail_panen') WHERE name='berat_minor'")).rows[0].n,0);await migrate(db,all);
});
for(const weight of ['1.001','invalid','-1','100000000','0.30000000000000004'])test('invalid legacy backfill aborts entire migration: '+weight,async t=>{
 const db=await legacy(t,weight);await assert.rejects(migrate(db,all),/Invalid legacy harvest weight/);assert.equal((await db.execute("SELECT COUNT(*) AS n FROM pragma_table_info('detail_panen') WHERE name='berat_minor'")).rows[0].n,0);assert.equal((await db.execute('SELECT COUNT(*) AS n FROM _schema_migrations')).rows[0].n,10);assert.equal((await db.execute("SELECT COUNT(*) AS n FROM sync_resource_links WHERE resource_type='panen'")).rows[0].n,0);assert.equal((await db.execute('SELECT COUNT(*) AS n FROM detail_panen')).rows[0].n,1);
});
