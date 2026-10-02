import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

test('inventory reads and writes preserve signed64 own and reference IDs', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  // Includes the audit boundary and the larger ID explicitly supplied for remediation.
  const ids = ['9007199254740993', '90071990254740993'];
  for (const id of ids) {
    await db.execute({ sql: 'INSERT INTO jenis_inventaris(id_jenis_inventaris,nama_jenis) VALUES (?,?)', args: [id, `Kind ${id}`] });
    await db.execute({ sql: 'INSERT INTO obat(id_obat,nama_obat) VALUES (?,?)', args: [id, `Medicine ${id}`] });
    const created = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers,
      payload: { id_jenis_inventaris: id, id_obat: id, nama_barang: 'Large references', satuan: 'kg' } });
    assert.equal(created.statusCode, 201, created.body);
    assert.equal(created.json().data.id_jenis_inventaris, id);
    assert.equal(created.json().data.id_obat, id);
    for (const [path, field, payload] of [
      ['jenis-inventaris', 'id_jenis_inventaris', { nama_jenis: `Updated ${id}` }],
      ['obat', 'id_obat', { nama_obat: `Updated ${id}` }],
    ]) {
      const detail = await app.inject({ url: `/api/v1/${path}/${id}`, headers });
      assert.equal(detail.statusCode, 200, detail.body);
      assert.equal(detail.json().data[field], id);
      const edit = await app.inject({ method: 'PATCH', url: `/api/v1/${path}/${id}`, headers, payload });
      assert.equal(edit.statusCode, 200, edit.body);
      assert.equal(edit.json().data[field], id);
      const list = await app.inject({ url: `/api/v1/${path}`, headers });
      assert.equal(list.statusCode, 200, list.body);
      assert.ok(list.json().data.some((row) => row[field] === id));
      const listedIds = list.json().data.map((row) => row[field]);
      assert.deepEqual(listedIds, [...listedIds].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1));
    }
    const list = await app.inject({ url: '/api/v1/inventaris', headers });
    assert.equal(list.statusCode, 200, list.body);
    assert.ok(list.json().data.some((row) => row.id_jenis_inventaris === id && row.id_obat === id));
  }
});

test('all inventory creates and lifecycle operations work after a large sequence', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  const id = '9007199254740993';
  for (const table of ['jenis_inventaris', 'obat', 'inventaris']) {
    await db.execute({ sql: 'INSERT INTO sqlite_sequence(name,seq) VALUES (?,?)', args: [table, '9007199254740992'] });
  }
  for (const [path, field, payload, patch] of [
    ['jenis-inventaris', 'id_jenis_inventaris', { nama_jenis: 'Large' }, { nama_jenis: 'Edited' }],
    ['obat', 'id_obat', { nama_obat: 'Large' }, { nama_obat: 'Edited' }],
    ['inventaris', 'id_inventaris', { id_jenis_inventaris: id, id_obat: id, nama_barang: 'Large', satuan: 'kg' }, { nama_barang: 'Edited' }],
  ]) {
    const create = await app.inject({ method: 'POST', url: `/api/v1/${path}`, headers, payload });
    assert.equal(create.statusCode, 201, create.body);
    assert.equal(create.json().data[field], id);
    const edited = await app.inject({ method: 'PATCH', url: create.headers.location, headers, payload: patch });
    assert.equal(edited.statusCode, 200, edited.body);
    assert.equal(edited.json().data[field], id);
    assert.equal(edited.json().data.public_id, create.json().data.public_id);
  }
  for (const path of ['inventaris', 'obat', 'jenis-inventaris']) {
    const response = await app.inject({ method: 'POST', url: `/api/v1/${path}/${id}/deactivate`, headers });
    assert.equal(response.statusCode, 200, response.body);
    assert.equal(response.json().data.status_aktif, 0);
    const list = await app.inject({ url: `/api/v1/${path}`, headers });
    assert.equal(list.statusCode, 200, list.body);
  }
});
