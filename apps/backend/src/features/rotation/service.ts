import type { Transaction } from '@libsql/client';
import { jakartaDate } from '../../common/dates.js';
import { toMinor } from '../../common/quantities.js';
import { recordMovement } from '../stock/service.js';
import { ApiError } from '../../common/errors.js';
import type { AcceptInput, CreateRecommendationInput, RejectInput } from './contracts.js';
import { melampauiJatah, recommendRotation, type Tingkat } from './engine.js';
import { assertMaterialsMatch } from './material.js';
import {
  daysToHarvest, findPending, getRecommendation, loadCatalog, loadHistory, loadUnavailableRejections,
  type RecommendationRow,
} from './store.js';

/** Penolakan karena tidak tersedia atau harga berlaku selama ini (R4 mesin rotasi). */
const REJECTION_MEMORY_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Alasan saran tidak boleh lagi dipakai pada `date`, atau null bila masih sah. Riwayat semprot dan
 * jadwal panen bisa berubah setelah saran dibuat.
 */
/** Saran hama lain dari foto yang sama dengan obat yang sama sudah diterima: ini semprotan yang sama. */
async function sharedAccepted(tx: Transaction, rec: RecommendationRow) {
  return rec.id_hasil_deteksi !== null && (await tx.execute({
    sql: `SELECT 1 FROM rekomendasi_perawatan WHERE id_hasil_deteksi = ? AND id_katalog = ?
      AND status_rekomendasi = 'diterima' AND id_rekomendasi <> ?`,
    args: [rec.id_hasil_deteksi, rec.obat.id_katalog, rec.id_rekomendasi],
  })).rows.length > 0;
}

async function staleReason(tx: Transaction, rec: RecommendationRow, date: string) {
  const shared = await sharedAccepted(tx, rec);
  if (!shared && melampauiJatah(await loadHistory(tx, rec.id_meja), rec.obat.kode_moa, rec.hama, date)) {
    return new ApiError(409, 'ROTATION_LIMIT',
      'Cara kerja obat ini sudah 2 kali dalam 30 hari di meja ini. Minta saran baru.');
  }
  if (rec.obat.jenis === 'kimia') {
    const left = await daysToHarvest(tx, rec.id_meja, date);
    if (left !== null && (rec.obat.phi_hari === null || rec.obat.phi_hari > left)) {
      return new ApiError(409, 'HARVEST_TOO_SOON',
        'Masa tunggu panen obat ini tidak muat sebelum panen. Minta saran baru.');
    }
  }
  return null;
}

/**
 * Membuat rekomendasi rotasi untuk satu meja dan hama. Tetap satu saran menunggu per meja dan hama:
 * penilaian yang sama dikembalikan apa adanya (replayed, aman untuk ketuk ganda), sedangkan tingkat
 * atau foto yang baru menghitung ulang saran yang menunggu itu, karena penilaian terbaru yang berlaku.
 */
export async function createRecommendation(
  tx: Transaction,
  actorId: string,
  input: CreateRecommendationInput,
  now: number,
) {
  const meja = (await tx.execute({ sql: 'SELECT 1 FROM meja_tanam WHERE id_meja = ?', args: [input.id_meja] })).rows[0];
  if (!meja) throw new ApiError(422, 'TABLE_NOT_FOUND', 'Meja tanam tidak ditemukan.');
  let tingkatModel: Tingkat | null = null;
  if (input.id_hasil_deteksi !== undefined) {
    const scan = (await tx.execute({
      sql: `SELECT CAST(p.id_meja AS TEXT) AS id_meja FROM hasil_deteksi h
        JOIN pemindahan p ON p.id_pemindahan = h.id_pemindahan WHERE h.id_hasil_deteksi = ?`,
      args: [input.id_hasil_deteksi],
    })).rows[0];
    if (!scan) throw new ApiError(422, 'DETECTION_NOT_FOUND', 'Hasil deteksi tidak ditemukan.');
    if (String(scan.id_meja) !== input.id_meja) {
      throw new ApiError(422, 'DETECTION_TABLE_MISMATCH', 'Hasil deteksi berasal dari meja yang berbeda.');
    }
    // Saran dari foto harus untuk hama yang memang terdeteksi di foto itu.
    const found = (await tx.execute({
      sql: `SELECT d.jumlah, h.ambang_sedang, h.ambang_berat FROM deteksi_hama d
        JOIN hama h ON h.kode_hama = d.kode_hama WHERE d.id_hasil_deteksi = ? AND d.kode_hama = ?`,
      args: [input.id_hasil_deteksi, input.hama],
    })).rows[0];
    if (!found) throw new ApiError(422, 'DETECTION_PEST_MISMATCH', 'Hama ini tidak terdeteksi pada foto tersebut.');
    const jumlah = Number(found.jumlah);
    tingkatModel = jumlah >= Number(found.ambang_berat) ? 'berat' : jumlah >= Number(found.ambang_sedang) ? 'sedang' : 'ringan';
  }

  const pendingId = await findPending(tx, input.id_meja, input.hama);
  const pending = pendingId ? await getRecommendation(tx, pendingId) : null;
  const scanChanged = input.id_hasil_deteksi !== undefined && input.id_hasil_deteksi !== pending?.id_hasil_deteksi;
  if (pending && pending.tingkat === input.tingkat && !scanChanged
    && !(await staleReason(tx, pending, jakartaDate(now)))) {
    return { replayed: true, created: false, data: pending };
  }

  // Obat yang sudah disarankan untuk hama lain dari foto yang sama (R9: satu semprotan untuk keduanya).
  const siblings = input.id_hasil_deteksi === undefined ? [] : (await tx.execute({
    sql: `SELECT CAST(r.id_katalog AS TEXT) AS id_katalog, h.nama FROM rekomendasi_perawatan r
      JOIN hama h ON h.kode_hama = r.kode_hama
      WHERE r.id_hasil_deteksi = ? AND r.kode_hama <> ? AND r.status_rekomendasi IN ('menunggu', 'diterima')`,
    args: [input.id_hasil_deteksi, input.hama],
  })).rows.map((r) => ({ id: String(r.id_katalog), nama: String(r.nama) }));

  const result = recommendRotation({
    tingkat: input.tingkat,
    katalog: await loadCatalog(tx, input.hama),
    riwayat: await loadHistory(tx, input.id_meja),
    dikecualikan: await loadUnavailableRejections(tx, new Date(now - REJECTION_MEMORY_MS).toISOString()),
    hama: input.hama,
    hariIni: jakartaDate(now),
    sisaHariPanen: await daysToHarvest(tx, input.id_meja, jakartaDate(now)),
    pendamping: siblings.map((s) => s.id),
  });
  if (!result) {
    throw new ApiError(409, 'NO_RECOMMENDATION', 'Tidak ada obat yang bisa direkomendasikan untuk hama ini.');
  }
  // Catatan "satu semprotan" diturunkan saat dibaca (store.ts), supaya kedua saran selalu sepakat.
  const alasan = [
    tingkatModel && tingkatModel !== input.tingkat ? `Tingkat diubah petani (dari foto: ${tingkatModel}).` : null,
    result.alasan,
  ].filter(Boolean).join(' ').slice(0, 450);

  if (pending) {
    await tx.execute({
      sql: `UPDATE rekomendasi_perawatan SET tingkat = ?, id_hasil_deteksi = COALESCE(?, id_hasil_deteksi),
          tingkat_model = CASE WHEN ? IS NULL THEN tingkat_model ELSE ? END,
          id_katalog = ?, kode_moa = ?, rule_id = ?, alasan = ?, rencana = ?,
          tanggal_rekomendasi = ?
        WHERE id_rekomendasi = ? AND status_rekomendasi = 'menunggu'`,
      args: [
        // Foto tetap (COALESCE di atas) berarti tingkat dari foto itu juga tetap.
        input.tingkat, input.id_hasil_deteksi ?? null, tingkatModel, tingkatModel, result.obat.id, result.obat.kode_moa,
        result.rule_id, alasan, JSON.stringify(result.rencana), new Date(now).toISOString(),
        pending.id_rekomendasi,
      ],
    });
    return { replayed: false, created: false, data: await getRecommendation(tx, pending.id_rekomendasi) };
  }

  const inserted = (await tx.execute({
    sql: `INSERT INTO rekomendasi_perawatan
      (id_meja, id_hasil_deteksi, kode_hama, tingkat, tingkat_model, id_katalog, kode_moa, rule_id, alasan,
        rencana, id_user, tanggal_rekomendasi)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING CAST(id_rekomendasi AS TEXT) AS id`,
    args: [
      input.id_meja, input.id_hasil_deteksi ?? null, input.hama, input.tingkat, tingkatModel, result.obat.id,
      result.obat.kode_moa, result.rule_id, alasan, JSON.stringify(result.rencana), actorId,
      new Date(now).toISOString(),
    ],
  })).rows[0];
  return { replayed: false, created: true, data: await getRecommendation(tx, String(inserted.id)) };
}

const alreadyDecided = () => new ApiError(
  409,
  'RECOMMENDATION_ALREADY_DECIDED',
  'Rekomendasi ini sudah diputuskan dengan jawaban lain.',
);

/** Bahan sama bila barang dan jumlahnya sama, tanpa memandang urutan atau penulisan angka (10 vs 10.00). */
function sameMaterials(sent: NonNullable<AcceptInput['bahan']>, stored: { id_inventaris: string; jumlah: string }[]) {
  const key = (rows: { id_inventaris: string; jumlah: string }[]) =>
    rows.map((r) => `${r.id_inventaris}:${toMinor(r.jumlah)}`).sort().join('|');
  return key(sent) === key(stored);
}

/**
 * Menerima = pengguna memakai obat itu. Membuat `perawatan` (tindakan nyata) yang menjadi sumber
 * riwayat rotasi, memotong stok bahan yang dipakai (bila dikirim), dan memperbarui status, semuanya
 * dalam satu transaksi: stok kurang atau satuan salah membatalkan seluruh penerimaan.
 */
export async function acceptRecommendation(
  tx: Transaction,
  actorId: string,
  id: string,
  input: AcceptInput,
  now: number,
) {
  const current = await getRecommendation(tx, id);
  const date = input.tanggal_aplikasi ?? jakartaDate(now);
  if (date > jakartaDate(now)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Tanggal aplikasi tidak boleh di masa depan.');
  }
  if (current.status === 'diterima') {
    // Ulangan aman hanya bila isinya sama; field yang tidak dikirim dianggap sama.
    const differentDate = input.tanggal_aplikasi !== undefined && input.tanggal_aplikasi !== current.tanggal_aplikasi;
    const differentNote = input.catatan !== null && input.catatan !== current.catatan_perawatan;
    const differentMaterials = input.bahan !== undefined && !sameMaterials(input.bahan, current.bahan_terpakai);
    if (differentDate || differentNote || differentMaterials) throw alreadyDecided();
    return { replayed: true, data: current };
  }
  if (current.status === 'ditolak') throw alreadyDecided();
  const stale = await staleReason(tx, current, date);
  if (stale) throw stale;
  if (input.bahan) {
    if (await sharedAccepted(tx, current)) {
      throw new ApiError(409, 'SHARED_SPRAY_STOCK',
        'Semprotan ini sudah dicatat lewat saran hama lain dari foto yang sama. Terima tanpa memotong stok lagi.');
    }
    await assertMaterialsMatch(tx, current.obat, input.bahan);
  }

  const changed = (await tx.execute({
    sql: `UPDATE rekomendasi_perawatan SET status_rekomendasi = 'diterima', tanggal_keputusan = ?
      WHERE id_rekomendasi = ? AND status_rekomendasi = 'menunggu'`,
    args: [new Date(now).toISOString(), id],
  })).rowsAffected;
  if (changed !== 1) throw alreadyDecided();
  const care = (await tx.execute({
    sql: `INSERT INTO perawatan (id_rekomendasi, id_user, tanggal_perawatan, catatan) VALUES (?, ?, ?, ?)
      RETURNING CAST(id_perawatan AS TEXT) AS id`,
    args: [id, actorId, date, input.catatan],
  })).rows[0];
  if (input.bahan) {
    const careId = String(care.id);
    await recordMovement(tx, actorId, now, {
      jenis_stok: 'keluar',
      details: input.bahan,
      keterangan: `Perawatan #${careId} (${current.obat.bahan_aktif})`,
    }, { id_perawatan: careId });
  }
  return { replayed: false, data: await getRecommendation(tx, id) };
}

/** Alasan menolak opsional. Penolakan bukan tindakan, jadi tidak memakai jatah MoA. */
export async function rejectRecommendation(tx: Transaction, id: string, input: RejectInput, now: number) {
  const current = await getRecommendation(tx, id);
  if (current.status === 'ditolak') {
    if (current.alasan_penolakan !== input.alasan || current.catatan_penolakan !== input.catatan) throw alreadyDecided();
    return { replayed: true, data: current };
  }
  if (current.status === 'diterima') throw alreadyDecided();

  const changed = (await tx.execute({
    sql: `UPDATE rekomendasi_perawatan
      SET status_rekomendasi = 'ditolak', alasan_penolakan = ?, catatan_penolakan = ?, alasan_diisi = ?,
        tanggal_keputusan = ?
      WHERE id_rekomendasi = ? AND status_rekomendasi = 'menunggu'`,
    // Tanpa alasan: nilai pengisi memenuhi CHECK database dan dibaca kembali sebagai kosong.
    args: [
      input.alasan ?? 'lainnya', input.alasan === null ? '-' : input.catatan,
      input.alasan === null ? 0 : 1, new Date(now).toISOString(), id,
    ],
  })).rowsAffected;
  if (changed !== 1) throw alreadyDecided();
  return { replayed: false, data: await getRecommendation(tx, id) };
}
