import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { katalogCsv } from '../test-support/catalog-csv.js';

async function migrated(t) {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, await loadMigrations());
  return db;
}

test('dataset docs/data/obat-selada.csv sama persis dengan katalog hasil migrasi', async (t) => {
  const db = await migrated(t);
  const file = await readFile(new URL('../../../docs/data/obat-selada.csv', import.meta.url), 'utf8');
  assert.equal(file.replaceAll('\r\n', '\n'), await katalogCsv(db));
});

test('mutu data: setiap obat punya sumber dan hama, kimia yang disarankan punya masa tunggu panen', async (t) => {
  const db = await migrated(t);
  const rows = (await db.execute(`SELECT k.bahan_aktif, k.jenis, k.phi_hari, k.sumber, k.boleh_direkomendasikan AS boleh,
      k.status_registrasi, k.terverifikasi,
      (SELECT COUNT(*) FROM katalog_hama h WHERE h.id_katalog = k.id_katalog) AS hama
    FROM obat_katalog k`)).rows;
  assert.equal(rows.length, 29);
  for (const r of rows) {
    assert.ok(String(r.sumber).length > 0, r.bahan_aktif);
    assert.ok(Number(r.hama) > 0, `${r.bahan_aktif} tanpa hama`);
    assert.equal(Number(r.terverifikasi), 0, 'belum ada verifikasi pakar');
    if (r.jenis === 'kimia' && Number(r.boleh) === 1) assert.notEqual(r.phi_hari, null, r.bahan_aktif);
  }
});

test('data registri: tanpa entri selada, setiap baris bernomor pendaftaran', async () => {
  const file = await readFile(new URL('../../../docs/data/produk-indonesia-kutu.csv', import.meta.url), 'utf8');
  const [head, ...rows] = file.trim().split(/\r?\n/);
  assert.equal(head, 'merk_dagang,nomor_pendaftaran,jenis_pestisida,bahan_aktif,komoditas,hama,hama_latin,'
    + 'dosis,satuan_dosis,tanggal_terbit,tanggal_berakhir,asal_data');
  assert.ok(rows.length > 400);
  for (const row of rows) {
    // Nomor pendaftaran di registri ditulis dengan atau tanpa titik.
    assert.match(row, /^("[^"]+"|[^,]+),(RI\.)?[\d./]{8,}/, row);
    assert.match(row, /,(utama|perluasan)$/, row);
    assert.doesNotMatch(row, /selada|lactuca/i, 'bila selada ditemukan, perbarui klaim di docs/obat-selada-nft.md');
  }
});

test('0025: up lalu down mengembalikan skema dan katalog seperti sebelumnya', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  const at = all.findIndex((m) => m.id === '0025_obat_selada_rotasi');
  const upTo = all.slice(0, at + 1);
  const snapshot = async () => ({
    schema: (await db.execute(`SELECT type, name, sql FROM sqlite_master
      WHERE name NOT LIKE 'sqlite_%' AND name <> '_schema_migrations' ORDER BY type, name`)).rows
      .map((r) => `${r.type} ${r.name} ${String(r.sql ?? '').replace(/\s+/g, ' ')}`),
    catalog: (await db.execute('SELECT bahan_aktif, phi_hari, phi_sumber FROM obat_katalog ORDER BY bahan_aktif')).rows
      .map((r) => `${r.bahan_aktif}|${r.phi_hari}|${r.phi_sumber}`),
  });
  await migrate(db, all.slice(0, at));
  const before = await snapshot();
  await migrate(db, upTo);
  await migrate(db, upTo, { direction: 'down', allowDataLoss: true });
  assert.deepEqual(await snapshot(), before);
  await migrate(db, upTo);
});
