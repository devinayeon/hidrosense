import { randomUUID } from 'node:crypto';
import type { Client, Transaction } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { ApiError } from '../../common/errors.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { executeDomainMutation, type Json } from '../../common/sync.js';
import { clientUuidSchema, uuidSchema } from '../../common/validation.js';

/**
 * Idempotent write wrapper for nursery operations.
 * Mirrors stock/write.ts: mandatory Idempotency-Key for create; optional X-Client-Id.
 * Update operations do not issue a new public UUID — they bump resource_version only.
 */
export async function nurseryWrite<T extends Json & Record<string, Json>>(
  db: Client,
  request: FastifyRequest,
  clock: () => number,
  operationType: 'penyemaian.create' | 'penyemaian.update',
  payload: Json,
  effect: (tx: Transaction, actorId: string, now: number) => Promise<T>,
) {
  const rawKey = request.headers['idempotency-key'];
  const operationKey = operationType === 'penyemaian.create'
    ? rawKey
    : (rawKey ?? randomUUID());

  if (!uuidSchema.safeParse(operationKey).success) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Header sinkronisasi tidak valid.');
  }

  const rawClientId = request.headers['x-client-id'];
  const parsedClientId = clientUuidSchema.safeParse(rawClientId);
  if (rawClientId !== undefined && !parsedClientId.success) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'X-Client-Id tidak valid.');
  }

  // Only create operations may carry a client UUID for public ID reservation.
  const withClient = parsedClientId.success && operationType === 'penyemaian.create';

  return authenticatedWrite(db, request.headers.authorization, 'penyemaian:write', clock,
    (tx, actor) => {
      const now = clock();
      return executeDomainMutation(tx, actor.id_user, {
        operation_key: String(operationKey),
        operation_type: operationType,
        payload,
        ...(withClient ? { resource_type: 'penyemaian', client_id: parsedClientId.data } : {}),
      }, now, {
        resourceType: 'penyemaian',
        idField: 'id_penyemaian',
        effect: () => effect(tx, actor.id_user, now),
      });
    },
  );
}
