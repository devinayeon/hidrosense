import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requirePermission } from '../../common/authorization.js';
import { clientUuidSchema, parseInput } from '../../common/validation.js';

const querySchema = z.strictObject({ device_id: clientUuidSchema });
const bodySchema = z.strictObject({ device_id: clientUuidSchema });

async function readCheckpoint(db: Client, userId: unknown, deviceId: string) {
  const row = (await db.execute({
    sql: 'SELECT last_synced_at FROM sync_checkpoints WHERE id_user=? AND device_id=?',
    args: [String(userId), deviceId],
  })).rows[0];
  return { last_synced_at: row ? new Date(Number(row.last_synced_at)).toISOString() : null };
}

/**
 * Kapan perangkat ini terakhir selesai sinkron. Jam diambil dari server, bukan dari perangkat,
 * dan tidak pernah mundur: dua perangkat dengan jam berbeda tidak bisa menggeser waktu ke belakang.
 * Menulisnya berulang aman (satu baris per pengguna dan perangkat), jadi tidak butuh kunci idempoten.
 */
export function registerSyncStatus(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/sync/status', { preHandler: requirePermission(db, undefined, clock) }, async (request) => {
    const { device_id } = parseInput(querySchema, request.query);
    return { data: await readCheckpoint(db, request.principal!.id_user, device_id) };
  });

  app.post('/api/v1/sync/status', { preHandler: requirePermission(db, undefined, clock) }, async (request) => {
    const { device_id } = parseInput(bodySchema, request.body);
    const userId = request.principal!.id_user;
    await db.execute({
      sql: `INSERT INTO sync_checkpoints (id_user, device_id, last_synced_at) VALUES (?,?,?)
        ON CONFLICT (id_user, device_id) DO UPDATE SET
          last_synced_at = MAX(sync_checkpoints.last_synced_at, excluded.last_synced_at)`,
      args: [String(userId), device_id, clock()],
    });
    return { data: await readCheckpoint(db, userId, device_id) };
  });
}
