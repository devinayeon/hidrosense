import type { FastifyInstance } from 'fastify';
import type { Client, InValue } from '@libsql/client';
import { requirePermission } from '../../common/authorization.js';
import { createInventarisSchema, updateInventarisSchema, emptyQuerySchema, idParamSchema, listQuerySchema, parseInput } from './contracts.js';
import { assertInventarisActive, inventarisArchived, assertJenisExists, assertNamaBarangAvailable, assertObatExists, getInventaris, getKatalogNama, inventarisResponse, inventarisColumns } from './store.js';
import { inventoryWrite } from './write.js';
import { ApiError } from '../../common/errors.js';
import { toMinor } from '../../common/quantities.js';
import { keepVersionIfSame } from '../../common/sync.js';

export function registerInventaris(app: FastifyInstance, db: Client, clock: () => number) {
  const readGuard = requirePermission(db, 'inventaris:read', clock);
  const writeGuard = requirePermission(db, 'inventaris:write', clock);

  app.post('/api/v1/inventaris', { preHandler: writeGuard }, async (request, reply) => {
    parseInput(emptyQuerySchema, request.query);
    const input = parseInput(createInventarisSchema, request.body);
    const result = await inventoryWrite(db, request, clock, 'inventaris.create', input, async (tx) => {
      await assertJenisExists(tx, input.id_jenis_inventaris);
      if (input.id_obat != null) await assertObatExists(tx, input.id_obat);
      // Barang jenis Obat mengambil namanya dari katalog; kolom "Nama barang"
      // tidak perlu diisi klien dan nilai kiriman diabaikan.
      const namaBarang = input.id_katalog != null
        ? await getKatalogNama(tx, input.id_katalog)
        : input.nama_barang;
      if (namaBarang === undefined) {
        throw new ApiError(400, 'VALIDATION_ERROR', 'Nama barang wajib diisi.');
      }
      await assertNamaBarangAvailable(tx, namaBarang);
      const inserted = await tx.execute({
        sql: `INSERT INTO inventaris (id_jenis_inventaris,id_obat,id_katalog,nama_barang,satuan,stok_minimum,stok_minimum_minor)
          VALUES (?,?,?,?,?,?,?) RETURNING CAST(id_inventaris AS TEXT) AS id_inventaris`,
        args: [input.id_jenis_inventaris, input.id_obat ?? null, input.id_katalog ?? null, namaBarang, input.satuan,
          input.stok_minimum ?? null, input.stok_minimum == null ? null : toMinor(input.stok_minimum)],
      });
      return getInventaris(tx, String(inserted.rows[0].id_inventaris));
    });
    return reply.code(result.replayed ? 200 : 201)
      .header('location', `/api/v1/inventaris/${result.data.id_inventaris}`).send(result);
  });

  app.get('/api/v1/inventaris', { preHandler: readGuard }, async (request) => {
    const { page, limit, status_aktif } = parseInput(listQuerySchema, request.query);
    const filter = status_aktif === undefined ? null : Number(status_aktif);
    const [count, records] = await db.batch([
      { sql: `SELECT COUNT(*) AS total FROM inventaris i WHERE (? IS NULL OR i.status_aktif=?)`, args: [filter, filter] },
      { sql: `SELECT ${inventarisColumns} FROM inventaris i
          JOIN jenis_inventaris j ON j.id_jenis_inventaris=i.id_jenis_inventaris LEFT JOIN obat o ON o.id_obat=i.id_obat
          LEFT JOIN obat_katalog k ON k.id_katalog=i.id_katalog
          LEFT JOIN stok_saldo b ON b.id_inventaris=i.id_inventaris
          WHERE (? IS NULL OR i.status_aktif=?) ORDER BY COALESCE(updated_at,0) DESC, i.id_inventaris DESC LIMIT ? OFFSET ?`,
        args: [filter, filter, limit, (page - 1) * limit] },
    ], 'read');
    const total = Number(count.rows[0].total);
    return { data: records.rows.map(inventarisResponse), meta: { page, limit, total, total_pages: Math.ceil(total / limit) } };
  });

  app.get('/api/v1/inventaris/:id', { preHandler: readGuard }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(idParamSchema, request.params);
    return { data: await getInventaris(db, id) };
  });

  app.patch('/api/v1/inventaris/:id', { preHandler: writeGuard }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(idParamSchema, request.params);
    const input = parseInput(updateInventarisSchema, request.body);
    return inventoryWrite(db, request, clock, 'inventaris.update', { id, input }, async (tx) => {
      const current = await getInventaris(tx, id);
      // Barang arsip hanya boleh dilihat atau diaktifkan kembali; perubahan
      // data ditolak supaya tidak ada ubahan setelah arsip (balapan arsip vs
      // ubah oleh dua pegawai).
      assertInventarisActive(current);
      const normalizeUnit = (value: string) => value.trim().toLowerCase();
      const unitChanged = input.satuan !== undefined
        && normalizeUnit(input.satuan) !== normalizeUnit(current.satuan);
      if (unitChanged) {
        const history = await tx.execute({ sql: 'SELECT 1 FROM detail_stok WHERE id_inventaris=? LIMIT 1', args: [id] });
        if (history.rows.length) throw new ApiError(409, 'UNIT_LOCKED', 'Satuan barang sudah digunakan dalam histori stok.');
      }
      if (input.id_jenis_inventaris !== undefined) await assertJenisExists(tx, input.id_jenis_inventaris);
      if (input.id_obat != null) await assertObatExists(tx, input.id_obat);
      const derivedName = input.id_katalog != null
        ? await getKatalogNama(tx, input.id_katalog)
        : undefined;
      const nextName = derivedName ?? input.nama_barang ?? current.nama_barang;
      if (nextName !== current.nama_barang) await assertNamaBarangAvailable(tx, nextName, id);
      const assignments: string[] = [];
      const args: InValue[] = [];
      for (const field of ['id_jenis_inventaris', 'id_obat', 'id_katalog', 'nama_barang', 'satuan', 'stok_minimum'] as const) {
        if (field === 'satuan' && !unitChanged) continue;
        if (field === 'nama_barang' && derivedName !== undefined) continue;
        if (field in input) { assignments.push(`${field}=?`); args.push(input[field] ?? null); }
      }
      if (derivedName !== undefined) {
        assignments.push('nama_barang=?');
        args.push(derivedName);
      }
      // Dua tautan obat tidak boleh terisi bersamaan; tautan yang baru dipilih
      // menang dan tautan lama dilepas, supaya klien tidak perlu mengirim null
      // untuk kolom yang tidak dipakainya.
      if (input.id_katalog != null) { assignments.push('id_obat=?'); args.push(null); }
      if (input.id_obat != null) { assignments.push('id_katalog=?'); args.push(null); }
      if ('stok_minimum' in input) {
        assignments.push('stok_minimum_minor=?');
        args.push(input.stok_minimum == null ? null : toMinor(input.stok_minimum));
      }
      if (assignments.length) {
        args.push(id);
        const updated = await tx.execute({
          // Syarat `status_aktif=1` menutup balapan baca-lalu-tulis: bila
          // pegawai lain mengarsipkan di antara baca dan tulis, tidak ada baris
          // yang berubah dan permintaan ditolak, bukan menimpa data arsip.
          sql: `UPDATE inventaris SET ${assignments.join(',')} WHERE id_inventaris=? AND status_aktif=1`, args,
        });
        if (updated.rowsAffected !== 1) inventarisArchived();
      }
      return keepVersionIfSame(current, await getInventaris(tx, id));
    }, input.expected_version);
  });

  app.post('/api/v1/inventaris/:id/deactivate', { preHandler: writeGuard }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(idParamSchema, request.params);
    return inventoryWrite(db, request, clock, 'inventaris.deactivate', { id }, async (tx) => {
      const current = await getInventaris(tx, id);
      // Mengarsipkan barang yang sudah arsip adalah manipulasi tanpa tujuan;
      // tolak dengan pesan yang jelas. Panggilan ulang dengan kunci idempotensi
      // yang sama tetap di-replay sebelum efek ini berjalan.
      assertInventarisActive(current);
      await tx.execute({ sql: 'UPDATE inventaris SET status_aktif=0 WHERE id_inventaris=?', args: [id] });
      return keepVersionIfSame(current, await getInventaris(tx, id));
    });
  });

  // Mengaktifkan kembali barang yang diarsipkan. Nama barang tetap dipesan
  // selama arsip, jadi tidak ada bentrok nama saat dipulihkan.
  app.post('/api/v1/inventaris/:id/activate', { preHandler: writeGuard }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    const { id } = parseInput(idParamSchema, request.params);
    return inventoryWrite(db, request, clock, 'inventaris.activate', { id }, async (tx) => {
      const current = await getInventaris(tx, id);
      await tx.execute({ sql: 'UPDATE inventaris SET status_aktif=1 WHERE id_inventaris=?', args: [id] });
      return keepVersionIfSame(current, await getInventaris(tx, id));
    });
  });
}
