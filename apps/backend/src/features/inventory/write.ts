import { randomUUID } from 'node:crypto';
import type { Client, Transaction } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { clientUuidSchema, uuidSchema } from '../../common/validation.js';
import { ApiError } from '../../common/errors.js';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { executeDomainMutation, type Json } from '../../common/sync.js';

const resources = {
  'jenis-inventaris': 'id_jenis_inventaris', obat: 'id_obat', inventaris: 'id_inventaris',
} as const;

export function inventoryWrite<T extends Json & Record<string, Json>>(
  db: Client, request: FastifyRequest, clock: () => number,
  operationType: string, payload: unknown, effect: (tx: Transaction) => Promise<T>,
) {
  const operationKey = request.headers['idempotency-key'] ?? randomUUID();
  const clientId = request.headers['x-client-id'];
  const parsedClientId = clientUuidSchema.safeParse(clientId);
  const [resourceType, action] = operationType.split('.') as [keyof typeof resources, string];
  if (!uuidSchema.safeParse(operationKey).success || (clientId !== undefined
    && (!parsedClientId.success || action !== 'create'))) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Header sinkronisasi tidak valid.');
  }
  const normalizedPayload = JSON.parse(JSON.stringify(payload)) as Json & { id?: string };
  return authenticatedWrite(db, request.headers.authorization, 'inventaris:write', clock, (tx, actor) =>
    executeDomainMutation(tx, actor.id_user, {
      operation_key: String(operationKey), operation_type: operationType, payload: normalizedPayload,
      ...(parsedClientId.success ? { resource_type: resourceType, client_id: parsedClientId.data } : {}),
    }, clock(), {
      resourceType, domainId: action === 'create' ? undefined : normalizedPayload.id,
      idField: resources[resourceType], effect: () => effect(tx),
    }));
}
