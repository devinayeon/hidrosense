// HidroSense QA — fuzz invarian domain (§5.8).
//
// Menjalankan urutan operasi acak terhadap aplikasi Fastify di database
// in-memory (lewat fixture repo), lalu memeriksa invarian domain setelah
// setiap operasi. Tidak menyentuh data asli dan tidak memakai jaringan.
//
// Jalankan dari apps/backend:
//   node --import tsx qa/fuzz-invariants.mjs
//   FUZZ_STOCK_OPS=1000 FUZZ_CYCLES=60 node --import tsx qa/fuzz-invariants.mjs
//
// Keluar dengan kode bukan-nol bila ada invarian dilanggar. Semua hasil nyata.

import assert from 'node:assert/strict';
import { randomInt, randomUUID } from 'node:crypto';
import { fixture, bearer } from '../test-support/fixture.js';
import { reconcileStock } from '../src/features/stock/reconcile.ts';
import { jakartaDate } from '../src/common/dates.ts';

const STOCK_OPS = Number(process.env.FUZZ_STOCK_OPS ?? 400);
const CYCLES = Number(process.env.FUZZ_CYCLES ?? 40);
const DAY = 86_400_000;

const cleanups = [];
const t = { after: (fn) => cleanups.push(fn) };
const ctx = await fixture(t);
const db = ctx.db;
const login = (await ctx.login('petani')).json().data;
let petani = bearer(login.access_token);
let refreshToken = login.refresh_token;

// Token akses berumur 15 menit; jam simulasi maju untuk menggeser jendela rate
// limit, jadi token diperbarui lewat refresh (bukan login ulang, yang punya
// batas 10 percobaan/15 menit).
async function renew() {
  const response = await ctx.app.inject({
    method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: refreshToken },
  });
  assert.equal(response.statusCode, 200, response.body);
  const data = response.json().data;
  petani = bearer(data.access_token);
  refreshToken = data.refresh_token;
}

const inject = (opts) => ctx.app.inject(opts);
let requests = 0;
async function call(method, url, payload) {
  requests++;
  return inject({ method, url, headers: petani, payload });
}
const uuid = () => randomUUID();
const money2 = (n) => n.toFixed(2);

// --- Kueri invarian; masing-masing harus mengembalikan 0 baris. ------------
const INVARIANTS = [
  ['AQ-02 saldo cache = buku besar', `WITH ledger AS (
     SELECT d.id_inventaris, SUM(CASE WHEN s.jenis_stok='masuk' THEN d.jumlah_minor ELSE -d.jumlah_minor END) hitung
     FROM detail_stok d JOIN stok s ON s.id_stok=d.id_stok GROUP BY d.id_inventaris)
     SELECT l.id_inventaris FROM ledger l JOIN stok_saldo s ON s.id_inventaris=l.id_inventaris WHERE l.hitung<>s.saldo_minor`],
  ['AQ-01 saldo di rentang [0,max]', 'SELECT id_inventaris FROM stok_saldo WHERE saldo_minor<0 OR saldo_minor>999999999999'],
  ['AQ-03 semua stok tersegel', 'SELECT id_stok FROM stok WHERE sealed<>1'],
  ['AQ-04 tanaman aktif meja di [0,lubang]', `WITH h AS (
     SELECT m.id_meja,m.jumlah_lubang,COALESCE((SELECT SUM(p.jumlah_tanaman
       - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan=p.id_pemindahan),0)
       - COALESCE((SELECT SUM(dp.jumlah_tanaman) FROM detail_panen dp WHERE dp.id_pemindahan=p.id_pemindahan),0))
       FROM pemindahan p WHERE p.id_meja=m.id_meja),0) aktif FROM meja_tanam m)
     SELECT id_meja FROM h WHERE aktif<0 OR aktif>jumlah_lubang`],
  ['AQ-06 pindah <= benih per semai', `SELECT p.id_penyemaian FROM pemindahan p
     JOIN penyemaian s ON s.id_penyemaian=p.id_penyemaian
     GROUP BY p.id_penyemaian,s.jumlah_benih HAVING SUM(p.jumlah_tanaman)>s.jumlah_benih`],
  ['AQ-07 panen <= pindah', `SELECT dp.id_detail_panen FROM detail_panen dp
     JOIN pemindahan p ON p.id_pemindahan=dp.id_pemindahan WHERE dp.jumlah_tanaman>p.jumlah_tanaman`],
  ['AQ-08 rusak+panen <= pindah', `SELECT p.id_pemindahan FROM pemindahan p
     LEFT JOIN (SELECT id_pemindahan,SUM(jumlah_tanaman) rusak FROM kerusakan_tanaman GROUP BY id_pemindahan) d ON d.id_pemindahan=p.id_pemindahan
     LEFT JOIN (SELECT id_pemindahan,SUM(jumlah_tanaman) panen FROM detail_panen GROUP BY id_pemindahan) h ON h.id_pemindahan=p.id_pemindahan
     WHERE COALESCE(d.rusak,0)+COALESCE(h.panen,0)>p.jumlah_tanaman`],
  ['AQ-09 reject <= total', 'SELECT id_detail_panen FROM detail_panen WHERE berat_reject_minor>berat_minor'],
  ['AQ-10 terjual <= layak per panen', `WITH layak AS (SELECT id_panen,SUM(berat_minor-berat_reject_minor) layak FROM detail_panen GROUP BY id_panen),
     jual AS (SELECT id_panen,SUM(jumlah_kg_minor) dijual FROM detail_penjualan GROUP BY id_panen)
     SELECT l.id_panen FROM layak l LEFT JOIN jual j ON j.id_panen=l.id_panen WHERE COALESCE(j.dijual,0)>l.layak`],
  ['AQ-11(t) tiap pembalik menunjuk asli', `SELECT r.id_stok FROM stok r LEFT JOIN stok o ON o.id_stok=r.reversal_of
     WHERE r.reversal_of IS NOT NULL AND o.id_stok IS NULL`],
  ['AQ-13 saldo yatim', `SELECT s.id_inventaris FROM stok_saldo s LEFT JOIN inventaris i ON i.id_inventaris=s.id_inventaris WHERE i.id_inventaris IS NULL`],
];

let checks = 0;
async function audit(context) {
  for (const [label, sql] of INVARIANTS) {
    const rows = (await db.execute(sql)).rows;
    checks++;
    assert.equal(rows.length, 0, `INVARIAN DILANGGAR (${label}) pada ${context}: ${JSON.stringify(rows)}`);
  }
  const reconcile = await reconcileStock(db);
  assert.equal(reconcile.consistent, true, `reconcile tidak konsisten pada ${context}: ${JSON.stringify(reconcile.mismatches)}`);
}

// --- Fuzz buku besar stok: masuk/keluar/retry/pembalik. --------------------
const jenis = await call('POST', '/api/v1/jenis-inventaris', { nama_jenis: `Fuzz ${uuid()}` });
assert.equal(jenis.statusCode, 201, jenis.body);
const item = await call('POST', '/api/v1/inventaris', {
  id_jenis_inventaris: jenis.json().data.id_jenis_inventaris,
  nama_barang: 'Benih Fuzz', satuan: 'pak', stok_minimum: '5',
});
assert.equal(item.statusCode, 201, item.body);
const idItem = item.json().data.id_inventaris;
const satuan = item.json().data.satuan;

const stockPost = (jenis_stok, jumlah, key = uuid()) => inject({
  method: 'POST', url: '/api/v1/stok', headers: { ...petani, 'idempotency-key': key },
  payload: { jenis_stok, details: [{ id_inventaris: idItem, jumlah, satuan }] },
});

const seeded = await stockPost('masuk', '500.00');
assert.equal(seeded.statusCode, 201, seeded.body);

let accepted = [];
let stockRejected = 0;
let stockAccepted = 0;
let replayed = 0;
for (let i = 0; i < STOCK_OPS; i++) {
  if (i % 40 === 0) ctx.advance(61_000); // geser jendela rate limit
  const roll = randomInt(0, 100);
  const amount = (randomInt(1, 500) / 100).toFixed(2); // 0.01..5.00
  if (roll < 8 && accepted.length) {
    // Retry kunci+isi sama: harus replay, bukan duplikat.
    const prior = accepted[randomInt(0, accepted.length)];
    const again = await inject({
      method: 'POST', url: '/api/v1/stok',
      headers: { ...petani, 'idempotency-key': prior.key },
      payload: prior.payload,
    });
    assert.equal(again.statusCode, 200, again.body);
    assert.equal(again.json().replayed, true);
    replayed++;
  } else if (roll < 16 && accepted.length) {
    // Balik satu transaksi yang belum dibalik.
    const candidates = accepted.filter((entry) => !entry.reversed);
    if (!candidates.length) continue;
    const target = candidates[randomInt(0, candidates.length)];
    const key = uuid();
    const reversal = await inject({
      method: 'POST', url: `/api/v1/stok/${target.id}/reverse`,
      headers: { ...petani, 'idempotency-key': key }, payload: {},
    });
    if (reversal.statusCode === 201) {
      target.reversed = true;
      stockAccepted++;
    } else {
      stockRejected++;
    }
  } else {
    // Kadang minta keluar melebihi saldo untuk memicu penolakan.
    const overdraft = roll > 90;
    const qty = overdraft ? '999999.00' : amount;
    const key = uuid();
    const jenis_stok = roll < 58 ? 'masuk' : 'keluar';
    const response = await stockPost(jenis_stok, qty, key);
    if (response.statusCode === 201) {
      const data = response.json().data;
      accepted.push({ key, id: data.id_stok, reversed: false, payload: { jenis_stok, details: [{ id_inventaris: idItem, jumlah: qty, satuan }] } });
      stockAccepted++;
    } else {
      stockRejected++;
      assert.ok([409, 400, 422].includes(response.statusCode), `status tak terduga: ${response.statusCode} ${response.body}`);
    }
  }
  if (i % 25 === 0) await audit(`stok op #${i}`);
}
await audit('akhir fuzz stok');
await renew();

const saldo = await call('GET', `/api/v1/inventaris/${idItem}/saldo`);
assert.equal(saldo.statusCode, 200, saldo.body);
assert.ok(Number(saldo.json().data.saldo) >= 0, 'saldo tidak boleh negatif');
console.log(`[stok] ops=${STOCK_OPS} diterima=${stockAccepted} ditolak=${stockRejected} replay=${replayed} saldo_akhir=${saldo.json().data.saldo}`);

// --- Fuzz rantai semai -> pindah -> rusak -> panen -> jual. ----------------
const benihJenis = await call('POST', '/api/v1/jenis-inventaris', { nama_jenis: `Benih ${uuid()}` });
const benih = await call('POST', '/api/v1/inventaris', {
  id_jenis_inventaris: benihJenis.json().data.id_jenis_inventaris,
  nama_barang: 'Benih Selada Fuzz', satuan: 'pak', stok_minimum: null,
});
const idBenih = benih.json().data.id_inventaris;
const masuk = await stockPostFor(idBenih, 'pak', '1000.00');
assert.equal(masuk.statusCode, 201, masuk.body);

async function stockPostFor(inv, sat, jumlah) {
  return inject({ method: 'POST', url: '/api/v1/stok',
    headers: { ...petani, 'idempotency-key': uuid() },
    payload: { jenis_stok: 'masuk', details: [{ id_inventaris: inv, jumlah, satuan: sat }] } });
}

let cycleStats = { sowing: 0, transfer: 0, damage: 0, harvest: 0, sale: 0, rejected: 0 };
for (let cycle = 0; cycle < CYCLES; cycle++) {
  ctx.advance(61_000);
  if (cycle > 0 && cycle % 10 === 0) await renew();
  const today = jakartaDate(ctx.clock());
  const sowDate = jakartaDate(ctx.clock() - 20 * DAY);
  const seeds = randomInt(20, 250);

  const sowing = await call('POST', '/api/v1/penyemaian', {
    tanggal_semai: sowDate, jumlah_benih: seeds,
    materials: [{ id_inventaris: idBenih, jumlah: '1.00', satuan: 'pak' }],
  });
  assert.equal(sowing.statusCode, 201, sowing.body);
  cycleStats.sowing++;
  const idSowing = sowing.json().data.id_penyemaian;

  const table = await call('POST', '/api/v1/meja-tanam', {
    kode_meja: `FZ-${cycle}-${randomInt(1000, 9999)}`, jumlah_lubang: 250,
  });
  assert.equal(table.statusCode, 201, table.body);
  const idTable = table.json().data.id_meja;

  const transferQty = randomInt(1, seeds + 1);
  const transfer = await call('POST', '/api/v1/pemindahan', {
    id_penyemaian: idSowing, id_meja: idTable, tanggal_pemindahan: today, jumlah_tanaman: transferQty,
  });
  assert.equal(transfer.statusCode, 201, transfer.body);
  cycleStats.transfer++;
  const idTransfer = transfer.json().data.id_pemindahan;

  const damaged = randomInt(0, transferQty + 1);
  if (damaged > 0) {
    const damage = await call('POST', '/api/v1/kerusakan', {
      id_pemindahan: idTransfer, tanggal_kejadian: today, jumlah_tanaman: damaged, jenis_kerusakan: 'busuk',
    });
    assert.equal(damage.statusCode, 201, damage.body);
    cycleStats.damage++;
  }

  const activeBeforeHarvest = transferQty - damaged;
  const harvested = randomInt(0, activeBeforeHarvest + 1);
  let idHarvest = null;
  let layakMinor = 0n;
  if (harvested > 0) {
    const total = (harvested * 0.05).toFixed(2);
    const reject = (Math.min(harvested, randomInt(0, 3)) * 0.01).toFixed(2);
    const harvest = await call('POST', '/api/v1/panen', {
      tanggal_panen: today,
      details: [{ id_pemindahan: idTransfer, jumlah_tanaman: harvested, berat_total: total, berat_reject: reject }],
    });
    assert.equal(harvest.statusCode, 201, harvest.body);
    cycleStats.harvest++;
    idHarvest = harvest.json().data.id_panen;
    layakMinor = BigInt(Math.round(Number(total) * 100) - Math.round(Number(reject) * 100));
  }

  if (idHarvest && layakMinor > 0n) {
    const sellMinor = BigInt(randomInt(1, Number(layakMinor) + 1));
    const kg = (Number(sellMinor) / 100).toFixed(2);
    const sale = await call('POST', '/api/v1/penjualan', {
      tanggal_penjualan: today, pembeli: `Pembeli ${cycle}`, status_pembayaran: 'lunas',
      id_panen: idHarvest, jumlah_kg: kg, harga_per_kg: '15000.00',
    });
    assert.equal(sale.statusCode, 201, sale.body);
    cycleStats.sale++;
  }

  await audit(`siklus #${cycle}`);
}
await audit('akhir fuzz rantai');

// Invarian idempotensi: kunci sama tidak menambah baris.
const before = (await db.execute('SELECT COUNT(*) n FROM detail_stok')).rows[0].n;
const probe = accepted[0];
if (probe) {
  const payload = { jenis_stok: 'masuk', details: [{ id_inventaris: idItem, jumlah: '1.00', satuan }] };
  const key = uuid();
  await inject({ method: 'POST', url: '/api/v1/stok', headers: { ...petani, 'idempotency-key': key }, payload });
  const mid = (await db.execute('SELECT COUNT(*) n FROM detail_stok')).rows[0].n;
  await inject({ method: 'POST', url: '/api/v1/stok', headers: { ...petani, 'idempotency-key': key }, payload });
  const after = (await db.execute('SELECT COUNT(*) n FROM detail_stok')).rows[0].n;
  assert.equal(mid, after, 'kirim ulang kunci sama tidak boleh menambah baris');
  assert.equal(after, before + 1, 'kiriman pertama harus menambah tepat satu baris');
}

for (const fn of cleanups) await fn();

console.log(`[rantai] ${JSON.stringify(cycleStats)}`);
console.log(`[ok] ${checks} pemeriksaan invarian lulus, ${requests} request, tanpa pelanggaran.`);