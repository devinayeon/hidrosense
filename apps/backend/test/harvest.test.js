import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from '../test-support/fixture.js';
function check(r, status, code) { assert.equal(r.statusCode, status, r.body); if(code) assert.equal(r.json().error.code,code,r.body); }
async function setup(t) {
 const f=await fixture(t); const headers=bearer((await f.login('pegawai')).json().data.access_token);
 await f.db.executeMultiple(`INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(2,'2026-09-01',1000); INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M1',1000); INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-16',200),(1,1,'2026-09-16',200);`);
 const detail=(id='1',count=10,total='1.20',reject='0.20')=>({id_pemindahan:id,jumlah_tanaman:count,berat_total:total,berat_reject:reject});
 const payload=(details=[detail()])=>({tanggal_panen:'2026-09-20',keterangan:' catatan ',details});
 const send=(method,path='',body,extra={})=>f.app.inject({method,url:'/api/v1/panen'+path,payload:body,headers:{...headers,...extra}});
 const post=(body=payload(),extra={})=>send('POST','',body,extra);
 return {...f,headers,detail,payload,send,post};
}
test('harvest snapshots, both roles, stable pagination and strict limits',async t=>{
 const f=await setup(t); const a=await f.post();check(a,201); const d=a.json().data;
 assert.equal(d.id_panen,'1');assert.equal(d.id_user,'2');assert.equal(d.version,'1');assert.equal(d.berat_layak,'1.00');assert.equal(d.berat_total,'1.20');assert.equal(d.berat_reject,'0.20');assert.equal(d.keterangan,'catatan');
 assert.equal(d.details[0].id_meja,'1');assert.equal(d.details[0].id_detail_panen,'1');
 const farmer=bearer((await f.login('petani')).json().data.access_token);check(await f.post(f.payload(),farmer),201);
 const list=await f.send('GET','?limit=1');check(list,200);assert.equal(list.json().data[0].id_panen,'2');assert.equal(list.json().meta.total,2);
 for(const limit of ['101','0','1.5','999999999999'])check(await f.send('GET','?limit='+limit),400);
 check(await f.app.inject({url:'/api/v1/panen'}),401); await f.db.execute("UPDATE users SET status_aktif=0 WHERE username='pegawai'");check(await f.post(),401);
});
test('harvest validates calendar, bounds, strict payload, duplicate batches and decimals',async t=>{
 const f=await setup(t);
 for(const date of ['2026-02-30','2026-10-01','2026-09-15'])check(await f.post({...f.payload(),tanggal_panen:date}),400);
 for(const value of [' 1','1 ','1e2','NaN','Infinity','1.001','100000000','-1','1\n'])check(await f.post(f.payload([f.detail('1',10,value)])),400);
 for(const d of [f.detail('1',0),f.detail('1',1000001),f.detail('1',1,'0','0'),f.detail('1',1,'1','2'),{...f.detail(),extra:true},{...f.detail(),id_pemindahan:1}])check(await f.post(f.payload([d])),400);
 check(await f.post({...f.payload(),extra:true}),400);check(await f.post(f.payload([f.detail(),f.detail()])),400);check(await f.post(f.payload([])),400);
 check(await f.post(f.payload([f.detail('999')])),404);check(await f.post(f.payload([f.detail('1',1,'1','1')])),201);
});
test('Jakarta today accepts tomorrow UTC at midnight boundary',async t=>{
 const f=await setup(t);f.advance(17*3600000);Object.assign(f.headers,bearer((await f.login('pegawai')).json().data.access_token));check(await f.post({...f.payload(),tanggal_panen:'2026-10-01'}),201);check(await f.post({...f.payload(),tanggal_panen:'2026-10-02'}),400);
});
test('atomic multi-detail rollback, active counts, concurrent damage and replay',async t=>{
 const f=await setup(t);const key=randomUUID(), client=randomUUID();
 check(await f.post(f.payload([f.detail(),f.detail('2',201)]),{'idempotency-key':key,'x-client-id':client}),409,'HARVEST_EXCEEDS_ACTIVE_PLANTS');
 for(const table of ['panen','detail_panen','sync_operations','sync_resource_versions','sync_id_maps'])assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM '+table)).rows[0].n,0,table);
 const responses=await Promise.all([f.post(f.payload([f.detail('1',150)]),{'idempotency-key':key}),f.app.inject({method:'POST',url:'/api/v1/kerusakan',headers:f.headers,payload:{id_pemindahan:'1',tanggal_kejadian:'2026-09-20',jumlah_tanaman:150,jenis_kerusakan:'Layu'}})]);
 assert.deepEqual(responses.map(r=>r.statusCode).sort(),[201,409]);
 const body=f.payload([f.detail('2',200)]);check(await f.post(body,{'idempotency-key':client}),201);const replay=await f.post(body,{'idempotency-key':client});check(replay,200);assert.equal(replay.json().replayed,true);
 check(await f.post(f.payload([f.detail('2',1)]),{'idempotency-key':client}),409,'OPERATION_CONFLICT');check(await f.post(f.payload([f.detail('2',1)])),409,'HARVEST_EXCEEDS_ACTIVE_PLANTS');
});
test('PATCH exact sold floor, version conflict, receipt replay, rollback and immutable fields',async t=>{
 const f=await setup(t);const d=(await f.post()).json().data;
 await f.db.executeMultiple(`INSERT INTO penjualan(id_user,tanggal_penjualan) VALUES(1,'2026-09-20');INSERT INTO detail_penjualan(id_penjualan,id_panen,jumlah_kg,harga_per_kg) VALUES(1,1,0.1,10),(1,1,0.2,10);`);
 const key=randomUUID();const body={expected_version:'1',keterangan:null,details:[{id_detail_panen:d.details[0].id_detail_panen,berat_total:'0.30',berat_reject:'0'}]};
 const result=await f.send('PATCH','/1',body,{'idempotency-key':key});check(result,200);assert.equal(result.json().data.version,'2');assert.equal(result.json().data.berat_layak,'0.30');assert.equal(result.json().data.keterangan,null);
 check(await f.send('PATCH','/1',body,{'idempotency-key':key}),200);check(await f.send('PATCH','/1',body),409,'HARVEST_VERSION_CONFLICT');
 check(await f.send('PATCH','/1',{...body,expected_version:'2',details:[{...body.details[0],berat_total:'0.29'}]}),409,'HARVEST_WEIGHT_BELOW_SOLD');
 const get=await f.send('GET','/1');assert.equal(get.json().data.version,'2');assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM sync_operations')).rows[0].n,2);
 for(const b of [{expected_version:'2'},{expected_version:'2',tanggal_panen:'2026-09-21'},{expected_version:2,keterangan:'a'},{expected_version:'2',details:[body.details[0],body.details[0]]}])check(await f.send('PATCH','/1',b),400);
 check(await f.send('PATCH','/1',{expected_version:'2',details:[{...body.details[0],id_detail_panen:'999'}]}),404);
 check(await f.send('GET','/999'),404);
});
test('100 details accepted above global 16KB limit and counts stay immutable',async t=>{
 const f=await setup(t);for(let i=3;i<=100;i++)await f.db.execute("INSERT INTO pemindahan(id_pemindahan,id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(?,1,1,'2026-09-16',1)",[String(i)]);
 const details=Array.from({length:100},(_,i)=>f.detail(String(i+1),1,'99999999.99','99999999.99'));const body={...f.payload(details),keterangan:'x'.repeat(1000)};
 const raw=JSON.stringify(body,null,4);assert.ok(Buffer.byteLength(raw)>16384);const result=await f.app.inject({method:'POST',url:'/api/v1/panen',headers:{...f.headers,'content-type':'application/json'},payload:raw});check(result,201);assert.equal(result.json().data.details.length,100);assert.equal(result.json().data.berat_layak,'0.00');
});

test('detail insert failure rolls back header, details and receipt identity; retry succeeds',async t=>{
 const f=await setup(t);await f.db.execute("CREATE TRIGGER reject_second BEFORE INSERT ON detail_panen WHEN NEW.id_pemindahan=2 BEGIN SELECT RAISE(ABORT,'test failure'); END");
 const body=f.payload([f.detail(),f.detail('2')]), key=randomUUID(),client=randomUUID();const headers={'idempotency-key':key,'x-client-id':client};check(await f.post(body,headers),500);
 for(const table of ['panen','detail_panen','sync_operations','sync_resource_versions','sync_resource_links','sync_id_maps'])assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM '+table)).rows[0].n,0,table);
 await f.db.execute('DROP TRIGGER reject_second');check(await f.post(body,headers),201);
});
test('receipt insert failure rolls back PATCH weight, note and resource version',async t=>{
 const f=await setup(t);await f.post();await f.db.execute("CREATE TRIGGER reject_receipt BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'test failure'); END");
 const body={expected_version:'1',keterangan:'changed',details:[{id_detail_panen:'1',berat_total:'2',berat_reject:'0'}]};check(await f.send('PATCH','/1',body),500);
 const d=(await f.send('GET','/1')).json().data;assert.equal(d.version,'1');assert.equal(d.berat_layak,'1.00');assert.equal(d.keterangan,'catatan');
 assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM sync_operations')).rows[0].n,1);
});

test('signed64 IDs remain strings across create and snapshot transport',async t=>{
 const f=await setup(t);await f.db.execute("INSERT INTO pemindahan(id_pemindahan,id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(9223372036854775807,1,1,'2026-09-16',1)");
 await f.db.execute("INSERT INTO sqlite_sequence(name,seq) VALUES('panen',9007199254740992),('detail_panen',9007199254740992)");
 const r=await f.post(f.payload([f.detail('9223372036854775807',1)]));check(r,201);const d=r.json().data;assert.equal(d.id_panen,'9007199254740993');assert.equal(d.details[0].id_detail_panen,'9007199254740993');assert.equal(d.details[0].id_pemindahan,'9223372036854775807');
 assert.deepEqual((await f.send('GET','/'+d.id_panen)).json().data,d);
});
test('ambiguous legacy sold values block correction without changing version',async t=>{
 const f=await setup(t);await f.post();await f.db.executeMultiple("INSERT INTO penjualan(id_user,tanggal_penjualan) VALUES(1,'2026-09-20');INSERT INTO detail_penjualan(id_penjualan,id_panen,jumlah_kg,harga_per_kg) VALUES(1,1,0.30000000000000004,1)");
 check(await f.send('PATCH','/1',{expected_version:'1',keterangan:'updated'}),409,'HARVEST_SOLD_WEIGHT_INVALID');assert.equal((await f.send('GET','/1')).json().data.version,'1');
});
