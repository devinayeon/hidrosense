import type { Client } from '@libsql/client';
import { MAX_QUANTITY_MINOR } from '../../common/quantities.js';

// Read-only verification for deployment/maintenance; never repairs balances implicitly.
export async function reconcileStock(db: Client) {
  const tx = await db.transaction('read');
  const ledger = new Map<string, bigint>();
  const mismatches: { id_inventaris: string; reason: string; ledger_minor: string; projection_minor: string | null }[] = [];
  let headerId = '0';
  let detailId = '0';
  let checkedDetails = 0n;
  let checkedBalances = 0n;
  try {
    for (;;) {
      const rows = (await tx.execute({ sql: `SELECT CAST(s.id_stok AS TEXT) AS header_id,
        CAST(d.id_detail_stok AS TEXT) AS detail_id,CAST(d.id_inventaris AS TEXT) AS item_id,
        CAST(d.jumlah_minor AS TEXT) AS minor,s.jenis_stok FROM stok s
        JOIN detail_stok d ON d.id_stok=s.id_stok WHERE s.sealed=1
        AND (s.id_stok>? OR (s.id_stok=? AND d.id_detail_stok>?))
        ORDER BY s.id_stok,d.id_detail_stok LIMIT 100`, args: [headerId, headerId, detailId] })).rows;
      if (!rows.length) break;
      for (const row of rows) {
        const id = String(row.item_id);
        const minor = BigInt(String(row.minor));
        const balance = (ledger.get(id) ?? 0n) + (row.jenis_stok === 'masuk' ? minor : -minor);
        ledger.set(id, balance);
        if (balance < 0n || balance > MAX_QUANTITY_MINOR) mismatches.push({ id_inventaris: id,
          reason: 'LEDGER_PREFIX_OUT_OF_BOUNDS', ledger_minor: balance.toString(), projection_minor: null });
        headerId = String(row.header_id); detailId = String(row.detail_id); checkedDetails++;
      }
    }
    let itemId = '0';
    for (;;) {
      const rows = (await tx.execute({ sql: `SELECT CAST(id_inventaris AS TEXT) AS item_id,
        CAST(saldo_minor AS TEXT) AS minor FROM stok_saldo WHERE id_inventaris>?
        ORDER BY stok_saldo.id_inventaris LIMIT 100`, args: [itemId] })).rows;
      if (!rows.length) break;
      for (const row of rows) {
        const id = String(row.item_id);
        const expected = ledger.get(id) ?? 0n;
        if (BigInt(String(row.minor)) !== expected) mismatches.push({ id_inventaris: id,
          reason: 'PROJECTION_MISMATCH', ledger_minor: expected.toString(), projection_minor: String(row.minor) });
        ledger.delete(id); itemId = id; checkedBalances++;
      }
    }
    for (const [id, balance] of ledger) mismatches.push({ id_inventaris: id,
      reason: 'PROJECTION_MISSING', ledger_minor: balance.toString(), projection_minor: null });
    const unsealed = (await tx.execute('SELECT CAST(COUNT(*) AS TEXT) AS n FROM stok WHERE sealed=0')).rows[0].n;
    return { consistent: mismatches.length === 0 && String(unsealed) === '0',
      checked_details: checkedDetails.toString(), checked_balances: checkedBalances.toString(),
      unsealed_headers: String(unsealed), mismatches };
  } finally { tx.close(); }
}
