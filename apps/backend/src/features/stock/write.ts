import type { Client, Transaction } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { executeDomainMutation, type Json } from '../../common/sync.js';
import { clientUuidSchema, parseInput, uuidSchema } from '../../common/validation.js';
import { ApiError } from '../../common/errors.js';
import { stockUnavailable } from './errors.js';

export async function stockWrite<T extends Json & Record<string, Json>>(
  db: Client, request: FastifyRequest, clock: () => number,
  operationType: 'stok.create' | 'stok.reverse', payload: Json,
  effect: (tx: Transaction, actorId: string, now: number) => Promise<T>,
) {
  const operationKey = parseInput(uuidSchema, request.headers['idempotency-key']);
  const rawClientId = request.headers['x-client-id'];
  const clientId = rawClientId === undefined ? undefined : parseInput(clientUuidSchema, rawClientId);
  try {
    return await authenticatedWrite(db, request.headers.authorization, 'inventaris:write', clock, (tx, actor) => {
      const now = clock();
      return executeDomainMutation(tx, actor.id_user, {
        operation_key: operationKey, operation_type: operationType, payload,
        ...(clientId ? { resource_type: 'stok', client_id: clientId } : {}),
      }, now, { resourceType: 'stok', idField: 'id_stok', effect: () => effect(tx, actor.id_user, now) });
    });
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (stockUnavailable(error)) throw new ApiError(503, 'STOCK_WRITE_UNAVAILABLE',
      'Hasil operasi belum dapat dipastikan. Coba kembali dengan kunci dan isi operasi yang sama.');
    throw error;
  }
}
