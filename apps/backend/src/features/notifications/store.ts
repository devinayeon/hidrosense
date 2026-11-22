import type { Client, Row } from '@libsql/client';
import { jakartaDate } from '../../common/dates.js';
import { GROWTH_DAYS_ON_TABLE, MIN_TRANSFER_AGE_DAYS } from '../../common/growth-rules.js';
import { fromMinor } from '../../common/quantities.js';

type Executor = Pick<Client, 'execute'>;

export interface NotificationItem {
  id: string;
  category: 'nursery' | 'inventory' | 'harvest';
  title: string;
  subtitle: string;
  resource_id: string;
  read: boolean;
}

const dayMs = 24 * 60 * 60 * 1000;

const batchActive = `p.jumlah_tanaman
  - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan=p.id_pemindahan), 0)
  - COALESCE((SELECT SUM(d.jumlah_tanaman) FROM detail_panen d WHERE d.id_pemindahan=p.id_pemindahan), 0)`;

function daysBetween(fromIso: string, todayIso: string): number | null {
  const fromMs = Date.parse(`${fromIso}T00:00:00Z`);
  const todayMs = Date.parse(`${todayIso}T00:00:00Z`);
  if (!Number.isFinite(fromMs) || !Number.isFinite(todayMs)) return null;
  return Math.floor((todayMs - fromMs) / dayMs);
}

async function readKeysForUser(db: Executor, userId: string): Promise<Set<string>> {
  const rows = (
    await db.execute({
      sql: 'SELECT notification_key FROM notification_reads WHERE id_user=?',
      args: [userId],
    })
  ).rows;
  return new Set(rows.map((row) => String(row.notification_key)));
}

function buildNurseryItems(rows: Row[], today: string, readKeys: Set<string>): NotificationItem[] {
  const items: NotificationItem[] = [];
  for (const row of rows) {
    const sisa = Math.max(0, Number(row.jumlah_benih) - Number(row.jumlah_dipindahkan));
    if (sisa <= 0) continue;
    const hss = daysBetween(String(row.tanggal_semai), today);
    if (hss === null || hss < MIN_TRANSFER_AGE_DAYS) continue;
    const id = `nursery-ready:${String(row.id_penyemaian)}`;
    items.push({
      id,
      category: 'nursery',
      title: `Semaian HSS ${hss}`,
      subtitle: `${sisa} bibit siap pindah ke meja`,
      resource_id: String(row.id_penyemaian),
      read: readKeys.has(id),
    });
  }
  return items;
}

function buildInventoryItems(rows: Row[], readKeys: Set<string>): NotificationItem[] {
  return rows.map((row) => {
    const saldoMinor = BigInt(String(row.saldo_minor));
    const saldo = fromMinor(String(row.saldo_minor));
    const id = `inventory-low:${String(row.id_inventaris)}`;
    return {
      id,
      category: 'inventory',
      title: saldoMinor <= 0n ? 'Stok habis' : 'Stok menipis',
      subtitle: `${String(row.nama_barang)} sisa ${saldo} ${String(row.satuan)}`,
      resource_id: String(row.id_inventaris),
      read: readKeys.has(id),
    };
  });
}

function buildHarvestItems(rows: Row[], today: string, readKeys: Set<string>): NotificationItem[] {
  const items: NotificationItem[] = [];
  for (const row of rows) {
    const active = Number(row.tanaman_aktif);
    if (active <= 0) continue;
    const hst = daysBetween(String(row.tanggal_pemindahan), today);
    if (hst === null || hst < GROWTH_DAYS_ON_TABLE) continue;
    const id = `harvest-ready:${String(row.id_pemindahan)}`;
    items.push({
      id,
      category: 'harvest',
      title: `Siap panen (${String(row.kode_meja)})`,
      subtitle: `${active} tanaman, HST ${hst}`,
      resource_id: String(row.id_meja),
      read: readKeys.has(id),
    });
  }
  return items;
}

export async function listNotifications(db: Executor, userId: string, now: number) {
  const today = jakartaDate(now);
  const [readKeys, nurseryRes, inventoryRes, harvestRes] = await Promise.all([
    readKeysForUser(db, userId),
    db.execute({
      sql: `SELECT CAST(p.id_penyemaian AS TEXT) AS id_penyemaian, p.tanggal_semai, p.jumlah_benih,
          (SELECT COALESCE(SUM(pm.jumlah_tanaman), 0) FROM pemindahan pm WHERE pm.id_penyemaian=p.id_penyemaian) AS jumlah_dipindahkan
        FROM penyemaian p
        WHERE COALESCE(p.status_penyemaian, 'aktif') <> 'selesai'
        ORDER BY p.tanggal_semai ASC, p.id_penyemaian ASC`,
    }),
    db.execute({
      sql: `SELECT CAST(i.id_inventaris AS TEXT) AS id_inventaris, i.nama_barang, i.satuan,
          CAST(COALESCE(b.saldo_minor, 0) AS TEXT) AS saldo_minor
        FROM inventaris i
        LEFT JOIN stok_saldo b ON b.id_inventaris=i.id_inventaris
        WHERE i.status_aktif=1 AND i.stok_minimum_minor IS NOT NULL
          AND COALESCE(b.saldo_minor, 0) < i.stok_minimum_minor
        ORDER BY COALESCE(b.saldo_minor, 0) ASC, i.nama_barang ASC`,
    }),
    db.execute({
      sql: `SELECT CAST(p.id_pemindahan AS TEXT) AS id_pemindahan, CAST(p.id_meja AS TEXT) AS id_meja,
          m.kode_meja, p.tanggal_pemindahan, (${batchActive}) AS tanaman_aktif
        FROM pemindahan p
        JOIN meja_tanam m ON m.id_meja=p.id_meja
        WHERE m.status_meja <> 'nonaktif'
        ORDER BY p.tanggal_pemindahan ASC, p.id_pemindahan ASC`,
    }),
  ]);

  const items = [
    ...buildNurseryItems(nurseryRes.rows, today, readKeys),
    ...buildInventoryItems(inventoryRes.rows, readKeys),
    ...buildHarvestItems(harvestRes.rows, today, readKeys),
  ];
  items.sort((a, b) => Number(a.read) - Number(b.read));
  const unread_count = items.filter((item) => !item.read).length;
  return { unread_count, items };
}

export async function markAllNotificationsRead(db: Executor, userId: string, now: number) {
  const { items } = await listNotifications(db, userId, now);
  const unread = items.filter((item) => !item.read);
  for (const item of unread) {
    await db.execute({
      sql: `INSERT INTO notification_reads (id_user, notification_key, read_at)
        VALUES (?, ?, ?)
        ON CONFLICT(id_user, notification_key) DO UPDATE SET read_at=excluded.read_at`,
      args: [userId, item.id, now],
    });
  }
  return { marked_count: unread.length, unread_count: 0 };
}
