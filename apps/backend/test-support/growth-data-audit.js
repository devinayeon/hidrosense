import { createClient } from '@libsql/client';
import { stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { backendRoot } from '../src/db/client.js';

let url = process.env.DATABASE_URL ?? 'file:./data/hidrosense.db';
if (url.startsWith('file:')) {
  const path = url.startsWith('file://') ? fileURLToPath(url) : resolve(backendRoot, url.slice(5));
  await stat(path);
  url = `file:${path.replaceAll('\\', '/')}`;
}
const db = createClient({ url, authToken: process.env.DATABASE_AUTH_TOKEN });
try {
  await db.execute('PRAGMA query_only = ON');
  const today = new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10);
  const future = await db.execute({
    sql: 'SELECT CAST(id_pemindahan AS TEXT) AS id_pemindahan,tanggal_pemindahan FROM pemindahan WHERE tanggal_pemindahan > ?',
    args: [today],
  });
  const capacity = await db.execute(`WITH balances AS (
    SELECT m.id_meja,m.kode_meja,m.jumlah_lubang,
    COALESCE((SELECT SUM(p.jumlah_tanaman) FROM pemindahan p WHERE p.id_meja=m.id_meja),0)
    - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k JOIN pemindahan p ON p.id_pemindahan=k.id_pemindahan WHERE p.id_meja=m.id_meja),0)
    - COALESCE((SELECT SUM(d.jumlah_tanaman) FROM detail_panen d JOIN pemindahan p ON p.id_pemindahan=d.id_pemindahan WHERE p.id_meja=m.id_meja),0) AS tanaman_aktif
    FROM meja_tanam m)
    SELECT CAST(id_meja AS TEXT) AS id_meja,kode_meja,jumlah_lubang,tanaman_aktif
    FROM balances WHERE tanaman_aktif<0 OR tanaman_aktif>jumlah_lubang`);
  console.log(JSON.stringify({ auditedAt: new Date().toISOString(), today,
    readOnly: true, futureTransfers: future.rows, inconsistentCapacity: capacity.rows }, null, 2));
} finally { db.close(); }
