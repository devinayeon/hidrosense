import type { Client } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { executeDomainMutation, keepVersionIfSame, type Json } from '../../common/sync.js';
import { ApiError } from '../../common/errors.js';
import { requireIdempotencyKey } from '../../common/validation.js';
import type { AcceptInput, CreateRecommendationInput, RejectInput } from './contracts.js';
import { acceptRecommendation, createRecommendation, rejectRecommendation } from './service.js';

type Command =
  | { action: 'create'; input: CreateRecommendationInput }
  | { action: 'accept'; id: string; input: AcceptInput }
  | { action: 'reject'; id: string; input: RejectInput };

/**
 * `replayed` ada dua arti: struk operasi yang sama diulang (hasil tersimpan dikembalikan), atau
 * keputusan yang sama diulang dengan kunci baru. Dua-duanya aman dan tidak mengubah apa pun.
 */
export async function rotationWrite(
  db: Client,
  request: FastifyRequest,
  clock: () => number,
  command: Command,
) {
  const operationKey = requireIdempotencyKey(request.headers);
  const payload = JSON.parse(JSON.stringify(command)) as Json;
  let domainReplay = false;
  let created = false;

  // Membuat saran = hasil pemindaian (deteksi:write); memutuskan = rekomendasi:decide.
  const permission = command.action === 'create' ? 'deteksi:write' : 'rekomendasi:decide';
  const result = await authenticatedWrite(
    db,
    request.headers.authorization,
    permission,
    clock,
    (tx, actor) => {
      // Menerima mencatat tindakan nyata, jadi butuh izin perawatan juga.
      if (command.action === 'accept' && !actor.permissions.includes('perawatan:write')) {
        throw new ApiError(403, 'FORBIDDEN', 'Akses tidak diizinkan untuk akun ini.');
      }
      // Memotong stok adalah tulis inventaris: butuh izinnya juga.
      if (command.action === 'accept' && command.input.bahan && !actor.permissions.includes('inventaris:write')) {
        throw new ApiError(403, 'FORBIDDEN', 'Akses tidak diizinkan untuk akun ini.');
      }
      return executeDomainMutation(
        tx,
        actor.id_user,
        { operation_key: operationKey, operation_type: `rekomendasi-obat.${command.action}`, payload },
        clock(),
        {
          resourceType: 'rekomendasi_perawatan',
          domainId: command.action === 'create' ? undefined : command.id,
          idField: 'id_rekomendasi',
          effect: async () => {
            const done = command.action === 'create'
              ? await createRecommendation(tx, actor.id_user, command.input, clock())
              : command.action === 'accept'
                ? await acceptRecommendation(tx, actor.id_user, command.id, command.input, clock())
                : await rejectRecommendation(tx, command.id, command.input, clock());
            domainReplay = done.replayed;
            created = 'created' in done && done.created === true;
            // Keputusan yang diulang tidak mengubah baris, jadi versinya jangan naik.
            return domainReplay ? keepVersionIfSame(done.data, done.data) : done.data;
          },
        },
      );
    },
  );
  // `created` hanya benar untuk baris baru pada kiriman pertama; dipakai rute untuk 201 vs 200.
  return { ...result, replayed: result.replayed || domainReplay, created: created && !result.replayed };
}
