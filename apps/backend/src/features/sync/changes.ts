import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requirePermission } from '../../common/authorization.js';
import { ApiError } from '../../common/errors.js';
import { parseInput } from '../../common/validation.js';

/** A record type missing here is hidden from every caller, so a new feature cannot leak by default. */
const readPermissions: Readonly<Record<string, string>> = {
  'jenis-inventaris': 'inventaris:read',
  obat: 'inventaris:read',
  inventaris: 'inventaris:read',
  stok: 'inventaris:read',
  penyemaian: 'penyemaian:read',
  'meja-tanam': 'budidaya:read',
  pemindahan: 'budidaya:read',
  kerusakan_tanaman: 'budidaya:read',
  panen: 'panen:read',
  penjualan: 'penjualan:read',
};

const querySchema = z.strictObject({
  cursor: z.string().regex(/^(?:0|[1-9][0-9]{0,18})$(?![\s\S])/).default('0'),
  limit: z.string().regex(/^[1-9][0-9]{0,2}$(?![\s\S])/).default('100').transform(Number)
    .refine((value) => value <= 200),
});

export function registerSyncChanges(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/sync/changes', { preHandler: requirePermission(db, undefined, clock) }, async (request) => {
    const { cursor, limit } = parseInput(querySchema, request.query);
    const visible = Object.keys(readPermissions)
      .filter((type) => request.principal!.permissions.includes(readPermissions[type]));
    const tx = await db.transaction('read');
    try {
      const latest = (await tx.execute('SELECT CAST(COALESCE(MAX(id_change),0) AS TEXT) AS id FROM sync_changes')).rows[0].id;
      if (BigInt(cursor) > BigInt(String(latest))) {
        throw new ApiError(409, 'SYNC_CURSOR_RESET', 'Data server berubah. Muat ulang seluruh data.');
      }
      // One row per record, at its newest change. A record edited after a page was served
      // simply appears again in a later page, so no change can be skipped.
      const rows = (await tx.execute({
        sql: `SELECT CAST(c.id_change AS TEXT) AS cursor, c.resource_type, c.domain_id, c.changed_at, l.public_id,
            CAST(v.version AS TEXT) AS version
          FROM (
            SELECT MAX(id_change) AS id_change, resource_type, domain_id, changed_at FROM sync_changes
            WHERE id_change>? AND resource_type IN (${visible.map(() => '?').join(',')})
            GROUP BY resource_type, domain_id
          ) c
          LEFT JOIN sync_resource_links l ON l.resource_type=c.resource_type AND l.domain_id=c.domain_id
          LEFT JOIN sync_resource_versions v ON v.resource_type=l.resource_type AND v.public_id=l.public_id
          ORDER BY c.id_change LIMIT ?`,
        args: [cursor, ...visible, limit + 1],
      })).rows;
      const page = rows.slice(0, limit);
      return {
        data: page.map((row) => ({
          cursor: String(row.cursor),
          resource_type: String(row.resource_type),
          domain_id: String(row.domain_id),
          public_id: row.public_id == null ? null : String(row.public_id),
          version: row.version == null ? null : String(row.version),
          changed_at: new Date(Number(row.changed_at)).toISOString(),
        })),
        meta: { next_cursor: page.length ? String(page.at(-1)!.cursor) : cursor, has_more: rows.length > limit },
      };
    } finally { tx.close(); }
  });
}
