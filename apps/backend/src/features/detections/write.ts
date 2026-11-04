import type { Client } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { ApiError } from '../../common/errors.js';
import { executeDomainMutation, type Json } from '../../common/sync.js';
import { clientUuidSchema, requireIdempotencyKey } from '../../common/validation.js';
import type { CreateDetectionInput, UpdateDetectionInput } from './contracts.js';
import { createDetection, updateDetection } from './service.js';

type Command =
  | { action: 'create'; input: CreateDetectionInput }
  | { action: 'update'; id: string; input: UpdateDetectionInput };

export function detectionWrite(db: Client, request: FastifyRequest, clock: () => number, command: Command) {
  const operationKey = requireIdempotencyKey(request.headers);
  const clientId = request.headers['x-client-id'];
  const parsed = clientUuidSchema.safeParse(clientId);
  if (clientId !== undefined && (!parsed.success || command.action !== 'create')) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Header sinkronisasi tidak valid.');
  }
  const payload = JSON.parse(JSON.stringify(command)) as Json;
  return authenticatedWrite(db, request.headers.authorization, 'deteksi:write', clock, (tx, actor) =>
    executeDomainMutation(tx, actor.id_user, {
      operation_key: operationKey,
      operation_type: `deteksi.${command.action}`,
      payload,
      ...(parsed.success ? { resource_type: 'deteksi', client_id: parsed.data } : {}),
    }, clock(), {
      resourceType: 'deteksi',
      domainId: command.action === 'update' ? command.id : undefined,
      expectedVersion: command.action === 'update' ? command.input.expected_version : undefined,
      idField: 'id_deteksi',
      effect: () => (command.action === 'create'
        ? createDetection(tx, command.input, actor.id_user, clock())
        : updateDetection(tx, command.id, command.input)),
    }));
}
