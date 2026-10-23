import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { executeDomainMutation, type Json } from '../../common/sync.js';
import { clientUuidSchema, uuidSchema } from '../../common/validation.js';
import { ApiError } from '../../common/errors.js';
import { createSale, updateSale } from './service.js';
import type { CreateSaleInput, UpdateSaleInput } from './contracts.js';

type Command =
  | { action: 'create'; input: CreateSaleInput }
  | { action: 'update'; id: string; input: UpdateSaleInput };

export function salesWrite(
  db: Client,
  request: FastifyRequest,
  clock: () => number,
  command: Command,
) {
  const operationKey = request.headers['idempotency-key'] ?? randomUUID();
  const clientId = request.headers['x-client-id'];
  const parsed = clientUuidSchema.safeParse(clientId);

  if (
    !uuidSchema.safeParse(operationKey).success
    || (clientId !== undefined && (!parsed.success || command.action !== 'create'))
  ) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Header sinkronisasi tidak valid.');
  }

  const payload = JSON.parse(JSON.stringify(command)) as Json;

  return authenticatedWrite(
    db,
    request.headers.authorization,
    'penjualan:write',
    clock,
    (tx, actor) =>
      executeDomainMutation(
        tx,
        actor.id_user,
        {
          operation_key: String(operationKey),
          operation_type: `penjualan.${command.action}`,
          payload,
          ...(parsed.success ? { resource_type: 'penjualan', client_id: parsed.data } : {}),
        },
        clock(),
        {
          resourceType: 'penjualan',
          domainId: command.action === 'update' ? command.id : undefined,
          idField: 'id_penjualan',
          effect: () =>
            command.action === 'create'
              ? createSale(tx, command.input, actor.id_user, clock())
              : updateSale(tx, command.id, command.input, clock()),
        },
      ),
  );
}
