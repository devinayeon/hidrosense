// Tes perbaikan kecil dari audit backend (laporan-review-kode-backend.md bagian 8).
// Semua memakai database :memory: atau berkas sementara, tidak pernah database dev atau Turso.
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { connect, createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { fixture, bearer, password } from '../test-support/fixture.js';
import { reserveClientId } from '../src/common/sync.ts';
import * as validation from '../src/common/validation.ts';
import { emptyQuerySchema as harvest } from '../src/features/harvest/contracts.ts';
import { emptyQuerySchema as sales } from '../src/features/sales/contracts.ts';

const backendRoot = fileURLToPath(new URL('../', import.meta.url));

/** Mengirim baris permintaan mentah, karena app.inject menormalkan bentuk absolut. */
async function rawStatus(app, requestLine) {
  const { port } = new URL(await app.listen({ host: '127.0.0.1', port: 0 }));
  return new Promise((resolve, reject) => {
    const socket = connect(port, '127.0.0.1', () => {
      socket.write(`${requestLine} HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n`);
    });
    let response = '';
    socket.on('data', (chunk) => { response += chunk; });
    socket.on('end', () => resolve(Number(response.split(' ')[1])));
    socket.on('error', reject);
  });
}

// Nama bucket disimpan sebagai hash, jadi hitung semua baris. Tes ini belum login, sehingga
// satu-satunya baris yang mungkin muncul berasal dari kuota IP.
const ipBuckets = async (db) => Number((await db.execute(
  'SELECT COUNT(*) AS n FROM auth_rate_limits',
)).rows[0].n);

test('A1: target absolut tetap kena kuota IP', async (t) => {
  const { app, db } = await fixture(t);
  assert.equal(await rawStatus(app, 'GET http://x/api/v1/auth/me'), 401);
  assert.equal(await ipBuckets(db), 1);
});

test('A1: target absolut tetap kena aturan HTTPS di produksi', async (t) => {
  const { app } = await fixture(t, { env: { NODE_ENV: 'production' } });
  assert.equal(await rawStatus(app, 'GET http://x/api/v1/auth/me'), 426);
});

test('A1: target absolut di luar API tidak kena kuota', async (t) => {
  const { app, db } = await fixture(t);
  assert.equal(await rawStatus(app, 'GET http://x/health/live'), 200);
  assert.equal(await ipBuckets(db), 0);
});

test('A2/B3: pencarian tiket dan mapping memakai indeks penuh, bukan memindai milik pengguna', async (t) => {
  const { db } = await fixture(t);
  const tx = await db.transaction('write');
  t.after(() => tx.close());
  const statements = [];
  const recording = new Proxy(tx, {
    get(target, property) {
      if (property === 'execute') {
        return (statement) => { statements.push(statement); return target.execute(statement); };
      }
      const value = target[property];
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  await reserveClientId(recording, '1', {
    operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {},
    resource_type: 'meja-tanam', client_id: randomUUID(),
  }, 1000);
  const plan = async ({ sql, args }) => (await tx.execute({ sql: `EXPLAIN QUERY PLAN ${sql}`, args }))
    .rows.map((row) => String(row.detail)).join(' | ');
  const reads = statements.filter(({ sql }) => /^\s*SELECT/.test(sql));
  const receipts = reads.filter(({ sql }) => sql.includes('FROM sync_operations'));
  const mappings = reads.filter(({ sql }) => sql.includes('FROM sync_id_maps'));
  assert.equal(mappings.length, 1);
  assert.ok(receipts.length >= 1);
  assert.match(await plan(mappings[0]), /id_user=\? AND resource_type=\? AND <expr>=\?/);
  for (const receipt of receipts) {
    const detail = await plan(receipt);
    assert.match(detail, /id_user=\? AND (operation_key|<expr>)=\?/, detail);
    assert.doesNotMatch(detail, /TEMP B-TREE/, detail);
  }
  await tx.rollback();
});

async function inventoryFixture(t) {
  const context = await fixture(t);
  const token = (await context.login()).json().data.access_token;
  const headers = bearer(token);
  const write = (method, url, payload) => context.app.inject({ method, url: `/api/v1/${url}`, headers, payload });
  const jenis = (await write('POST', 'jenis-inventaris', { nama_jenis: 'Pupuk' })).json().data;
  const obat = (await write('POST', 'obat', { nama_obat: 'Fungisida' })).json().data;
  const item = (await write('POST', 'inventaris', {
    id_jenis_inventaris: jenis.id_jenis_inventaris, nama_barang: 'AB Mix', satuan: 'kg',
  })).json().data;
  return { ...context, headers, write, jenis, obat, item };
}

const changeCount = async (db) => Number((await db.execute('SELECT COUNT(*) AS n FROM sync_changes')).rows[0].n);

test('C3/A7: PATCH tanpa perubahan tidak menaikkan versi dan tidak mengumumkan perubahan', async (t) => {
  const { db, write, jenis, obat, item } = await inventoryFixture(t);
  const cases = [
    ['inventaris', item.id_inventaris, item.version, { satuan: 'KG' }],
    ['inventaris', item.id_inventaris, item.version, { nama_barang: 'AB Mix' }],
    ['jenis-inventaris', jenis.id_jenis_inventaris, jenis.version, { nama_jenis: 'Pupuk' }],
    ['obat', obat.id_obat, obat.version, { nama_obat: 'Fungisida' }],
  ];
  for (const [resource, id, version, body] of cases) {
    const before = await changeCount(db);
    // Versi lama tetap berlaku: klien lain yang memegangnya tidak boleh dapat konflik palsu.
    const response = await write('PATCH', `${resource}/${id}`, { ...body, expected_version: version });
    assert.equal(response.statusCode, 200, resource);
    assert.equal(response.json().data.version, version, resource);
    assert.equal(response.json().operation.version, version, resource);
    assert.equal(await changeCount(db), before, resource);
  }
});

test('C3/A7: PATCH yang benar-benar mengubah tetap menaikkan versi', async (t) => {
  const { db, write, item } = await inventoryFixture(t);
  const before = await changeCount(db);
  const response = await write('PATCH', `inventaris/${item.id_inventaris}`, { nama_barang: 'AB Mix Baru' });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().data.version, String(Number(item.version) + 1));
  assert.equal(response.json().data.nama_barang, 'AB Mix Baru');
  assert.equal(await changeCount(db), before + 1);
});

test('C3/A7: menonaktifkan dua kali hanya menaikkan versi sekali', async (t) => {
  const { db, write, item } = await inventoryFixture(t);
  const first = await write('POST', `inventaris/${item.id_inventaris}/deactivate`);
  assert.equal(first.json().data.version, String(Number(item.version) + 1));
  const before = await changeCount(db);
  const second = await write('POST', `inventaris/${item.id_inventaris}/deactivate`);
  assert.equal(second.statusCode, 200);
  assert.equal(second.json().data.version, first.json().data.version);
  assert.equal(await changeCount(db), before);
});

/** Rantai budidaya penuh lewat API, untuk menguji PATCH di semua fitur. */
async function growthFixture(t) {
  const context = await fixture(t);
  const headers = bearer((await context.login()).json().data.access_token);
  const write = (method, url, payload) => context.app.inject({ method, url: `/api/v1/${url}`, headers, payload });
  await context.db.execute("INSERT INTO penyemaian (id_user,tanggal_semai,jumlah_benih,status_penyemaian) VALUES (1,'2026-09-01',50,'aktif')");
  const sowing = (await write('PATCH', 'penyemaian/1', { keterangan: 'awal' })).json().data;
  const table = (await write('POST', 'meja-tanam', { kode_meja: 'M-1', jumlah_lubang: 40, status_meja: 'tersedia' })).json().data;
  const transfer = (await write('POST', 'pemindahan', {
    id_penyemaian: '1', id_meja: table.id_meja, tanggal_pemindahan: '2026-09-16', jumlah_tanaman: 20, keterangan: 'awal',
  })).json().data;
  const damage = (await write('POST', 'kerusakan', {
    id_pemindahan: transfer.id_pemindahan, tanggal_kejadian: '2026-09-17', jumlah_tanaman: 1, jenis_kerusakan: 'hama', keterangan: 'awal',
  })).json().data;
  const harvest = (await write('POST', 'panen', {
    tanggal_panen: '2026-09-20', keterangan: 'awal',
    details: [{ id_pemindahan: transfer.id_pemindahan, jumlah_tanaman: 5, berat_total: '10.00', berat_reject: '1.00' }],
  })).json().data;
  const sale = (await write('POST', 'penjualan', {
    tanggal_penjualan: '2026-09-21', pembeli: 'Toko', status_pembayaran: 'lunas', keterangan: 'awal',
    id_panen: harvest.id_panen, jumlah_kg: '2.00', harga_per_kg: '20000.00',
  })).json().data;
  return { ...context, write, sowing, table, transfer, damage, harvest, sale };
}

test('C3/A7: PATCH tanpa perubahan tidak menaikkan versi di semua fitur', async (t) => {
  const { db, write, sowing, table, transfer, damage, harvest, sale } = await growthFixture(t);
  const cases = [
    ['penyemaian/1', sowing.version, { keterangan: 'awal', expected_version: sowing.version }],
    [`meja-tanam/${table.id_meja}`, table.version, { kode_meja: 'M-1', expected_version: table.version }],
    [`pemindahan/${transfer.id_pemindahan}`, transfer.version, { keterangan: 'awal', expected_version: transfer.version }],
    [`kerusakan/${damage.id_kerusakan}`, damage.version, { jumlah_tanaman: 1, expected_version: damage.version }],
    [`panen/${harvest.id_panen}`, harvest.version, { keterangan: 'awal', expected_version: harvest.version }],
    [`panen/${harvest.id_panen}`, harvest.version, {
      expected_version: harvest.version,
      details: [{ id_detail_panen: harvest.details[0].id_detail_panen, berat_total: '10.00', berat_reject: '1.00' }],
    }],
    [`penjualan/${sale.id_penjualan}`, sale.version, { pembeli: 'Toko', expected_version: sale.version }],
    [`penjualan/${sale.id_penjualan}`, sale.version, {
      expected_version: sale.version, id_panen: harvest.id_panen, jumlah_kg: '2.00', harga_per_kg: '20000.00',
    }],
  ];
  for (const [url, version, body] of cases) {
    const before = await changeCount(db);
    const response = await write('PATCH', url, body);
    assert.equal(response.statusCode, 200, `${url} ${response.body}`);
    assert.equal(response.json().data.version, version, `${url} ${JSON.stringify(body)}`);
    assert.equal(await changeCount(db), before, `${url} mengumumkan perubahan palsu`);
  }
});

test('C3/A7: PATCH yang benar-benar mengubah tetap menaikkan versi di semua fitur', async (t) => {
  const { write, sowing, table, transfer, damage, harvest, sale } = await growthFixture(t);
  const cases = [
    ['penyemaian/1', sowing.version, { keterangan: 'baru' }, 'keterangan', 'baru'],
    [`meja-tanam/${table.id_meja}`, table.version, { kode_meja: 'M-2' }, 'kode_meja', 'M-2'],
    [`pemindahan/${transfer.id_pemindahan}`, transfer.version, { keterangan: 'baru' }, 'keterangan', 'baru'],
    [`kerusakan/${damage.id_kerusakan}`, damage.version, { jumlah_tanaman: 2 }, 'jumlah_tanaman', 2],
    [`panen/${harvest.id_panen}`, harvest.version, { keterangan: 'baru', expected_version: harvest.version }, 'keterangan', 'baru'],
    [`penjualan/${sale.id_penjualan}`, sale.version, { pembeli: 'Toko Baru', expected_version: sale.version }, 'pembeli', 'Toko Baru'],
  ];
  for (const [url, version, body, field, value] of cases) {
    const response = await write('PATCH', url, body);
    assert.equal(response.statusCode, 200, `${url} ${response.body}`);
    assert.equal(response.json().data[field], value, url);
    assert.equal(response.json().data.version, String(Number(version) + 1), url);
  }
  // Rincian penjualan yang berbeda tetap tersimpan, bukan terlewat oleh pemeriksaan "sama".
  const line = await write('PATCH', `penjualan/${sale.id_penjualan}`, {
    expected_version: String(Number(sale.version) + 1), id_panen: harvest.id_panen, jumlah_kg: '3.00', harga_per_kg: '20000.00',
  });
  assert.equal(line.statusCode, 200, line.body);
  assert.equal(line.json().data.details[0].jumlah_kg, '3.00');
});

test('Panen: estimasi panen 45 hari dari tanggal pindah', async (t) => {
  const { db, write, table, transfer } = await growthFixture(t);
  // Pindah tepat hari ke-15: 2026-09-16 + 45 hari.
  assert.equal(transfer.estimasi_panen, '2026-10-31');
  // Hari ini 2026-09-30 pada fixture, jadi masih 31 hari lagi.
  assert.equal(transfer.sisa_hari_panen, 31);
  // Pindah lebih lambat ikut menggeser estimasi, walau tanggal semainya sama.
  await db.execute('UPDATE penyemaian SET status_penyemaian=\'aktif\' WHERE id_penyemaian=1');
  const late = (await write('POST', 'pemindahan', {
    id_penyemaian: '1', id_meja: table.id_meja, tanggal_pemindahan: '2026-09-25', jumlah_tanaman: 5,
  })).json().data;
  assert.equal(late.tanggal_semai, '2026-09-01');
  assert.equal(late.estimasi_panen, '2026-11-09');
  assert.equal(late.sisa_hari_panen, 40);
});

test('C5: username yang sama tidak mengeluarkan pengguna', async (t) => {
  const { app, login } = await fixture(t);
  const owner = bearer((await login()).json().data.access_token);
  const worker = bearer((await login('pegawai')).json().data.access_token);
  const me = (headers) => app.inject({ url: '/api/v1/auth/me', headers });
  const patch = (url, headers, payload) => app.inject({ method: 'PATCH', url: `/api/v1/${url}`, headers, payload });

  assert.equal((await patch('employees/2', owner, { username: 'pegawai' })).statusCode, 200);
  assert.equal((await me(worker)).statusCode, 200);

  const profile = await patch('profile', owner, { username: 'petani', current_password: password });
  assert.equal(profile.statusCode, 200);
  assert.equal((await me(owner)).statusCode, 200);
});

test('C5: username yang benar-benar berubah tetap mencabut sesi', async (t) => {
  const { app, login } = await fixture(t);
  const owner = bearer((await login()).json().data.access_token);
  const worker = bearer((await login('pegawai')).json().data.access_token);
  const changed = await app.inject({
    method: 'PATCH', url: '/api/v1/employees/2', headers: owner, payload: { username: 'pegawai_baru' },
  });
  assert.equal(changed.statusCode, 200);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: worker })).statusCode, 401);
});

test('E13: skema query kosong hanya ada satu', () => {
  assert.equal(harvest, validation.emptyQuerySchema);
  assert.equal(sales, validation.emptyQuerySchema);
});

test('E13: parameter tak dikenal ditolak di inventaris dan akun', async (t) => {
  const { app, headers, jenis, obat, item } = await inventoryFixture(t);
  const cases = [
    ['GET', `inventaris/${item.id_inventaris}`],
    ['PATCH', `inventaris/${item.id_inventaris}`, { nama_barang: 'Baru' }],
    ['POST', `inventaris/${item.id_inventaris}/deactivate`],
    ['POST', 'inventaris', { id_jenis_inventaris: jenis.id_jenis_inventaris, nama_barang: 'B', satuan: 'kg' }],
    ['GET', `jenis-inventaris/${jenis.id_jenis_inventaris}`],
    ['PATCH', `jenis-inventaris/${jenis.id_jenis_inventaris}`, { nama_jenis: 'Baru' }],
    ['POST', `jenis-inventaris/${jenis.id_jenis_inventaris}/deactivate`],
    ['POST', 'jenis-inventaris', { nama_jenis: 'Lain' }],
    ['GET', `obat/${obat.id_obat}`],
    ['PATCH', `obat/${obat.id_obat}`, { nama_obat: 'Baru' }],
    ['POST', `obat/${obat.id_obat}/deactivate`],
    ['POST', 'obat', { nama_obat: 'Lain' }],
    ['GET', 'employees/2'],
    ['PATCH', 'employees/2', { nama: 'Baru' }],
    ['POST', 'employees/2/deactivate'],
    ['POST', 'employees/2/activate'],
    ['POST', 'employees', { nama: 'A', username: 'a_baru', password: 'Password baru 2026!' }],
    ['GET', 'profile'],
    ['PATCH', 'profile', { nama: 'Baru' }],
  ];
  for (const [method, url, payload] of cases) {
    const response = await app.inject({ method, url: `/api/v1/${url}?junk=1`, headers, payload });
    assert.equal(response.statusCode, 400, `${method} ${url}`);
    assert.equal(response.json().error.code, 'VALIDATION_ERROR', `${method} ${url}`);
  }
  // Tanpa parameter tak dikenal, rute yang sama tetap jalan.
  assert.equal((await app.inject({ url: `/api/v1/inventaris/${item.id_inventaris}`, headers })).statusCode, 200);
  assert.equal((await app.inject({ url: '/api/v1/profile', headers })).statusCode, 200);
});

test('E13: parameter tak dikenal ditolak di auth dan sync, tanpa efek samping', async (t) => {
  const { app, db, login } = await fixture(t);
  const session = (await login()).json().data;
  const headers = bearer(session.access_token);
  const cases = [
    ['POST', 'auth/login', { username: 'petani', password }, {}],
    ['POST', 'auth/refresh', { refresh_token: session.refresh_token }, {}],
    ['GET', 'auth/me', undefined, headers],
    ['POST', 'auth/logout', undefined, headers],
    ['POST', 'sync/operations', {
      operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {},
      resource_type: 'meja-tanam', client_id: randomUUID(),
    }, headers],
  ];
  for (const [method, url, payload, requestHeaders] of cases) {
    const response = await app.inject({ method, url: `/api/v1/${url}?junk=1`, headers: requestHeaders, payload });
    assert.equal(response.statusCode, 400, `${method} ${url}`);
    assert.equal(response.json().error.code, 'VALIDATION_ERROR', `${method} ${url}`);
  }
  // Sesi tetap utuh: refresh dan logout yang ditolak tidak boleh merotasi atau menghapusnya.
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions')).rows[0].n, 1);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers })).statusCode, 200);
});

const freePort = () => new Promise((resolve, reject) => {
  const server = createServer();
  server.on('error', reject);
  server.listen(0, '127.0.0.1', () => {
    const { port } = server.address();
    server.close(() => resolve(port));
  });
});

test('A17: kegagalan pembersihan sesi tidak menggagalkan start server', { timeout: 60000 }, async (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'hidrosense-a17-'));
  let child;
  // Satu hook dengan urutan tetap: server harus mati dulu, baru berkas database bisa dihapus.
  t.after(async () => {
    if (child && child.exitCode === null) {
      const exited = new Promise((resolve) => child.once('exit', resolve));
      child.kill();
      await exited;
    }
    rmSync(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  });
  const url = `file:${join(directory, 'a17.db').replaceAll('\\', '/')}`;
  // Disiapkan di proses terpisah: di Windows koneksi libSQL menahan berkas sampai prosesnya keluar.
  // Tabel hilang membuat pembersihan gagal, meniru database yang sedang bermasalah saat start.
  execFileSync(process.execPath, ['--import', 'tsx', '--input-type=module', '-e', `
    import { openDatabase } from './src/db/client.ts';
    import { loadMigrations, migrate } from './src/db/migrate.ts';
    const db = await openDatabase({ url: process.env.DATABASE_URL });
    await migrate(db, await loadMigrations());
    await db.execute('DROP TABLE auth_rate_limits');
    db.close();
  `], { cwd: backendRoot, env: { ...process.env, DATABASE_URL: url } });

  child = spawn(process.execPath, ['--import', 'tsx', 'src/server.ts'], {
    cwd: backendRoot,
    env: { ...process.env, DATABASE_URL: url, HOST: '127.0.0.1', PORT: String(await freePort()), NODE_ENV: 'test', LOG_LEVEL: 'info' },
  });
  let output = '';
  const outcome = await new Promise((resolve) => {
    const read = (chunk) => {
      output += chunk;
      if (output.includes('Server listening')) resolve('listening');
    };
    child.stdout.on('data', read);
    child.stderr.on('data', read);
    child.on('exit', (code) => resolve(`exit ${code}`));
  });
  assert.equal(outcome, 'listening', output);
  assert.match(output, /AUTH_PURGE_FAILED/);
});
