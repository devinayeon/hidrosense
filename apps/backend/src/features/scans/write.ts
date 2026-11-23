import type { Client } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { authenticatedWrite } from '../../common/authenticated-write.js';
import { executeDomainMutation, type Json } from '../../common/sync.js';
import { requireIdempotencyKey } from '../../common/validation.js';
import type { AppConfig } from '../../config.js';
import type { CreateScanInput } from './contracts.js';
import { createScan } from './service.js';

export function scanWrite(
  db: Client,
  request: FastifyRequest,
  clock: () => number,
  config: AppConfig,
  input: CreateScanInput,
) {
  const operationKey = requireIdempotencyKey(request.headers);
  const payload = JSON.parse(JSON.stringify(input)) as Json;
  return authenticatedWrite(db, request.headers.authorization, 'deteksi:write', clock, (tx, actor) =>
    executeDomainMutation(
      tx,
      actor.id_user,
      { operation_key: operationKey, operation_type: 'pindaian.create', payload },
      clock(),
      {
        resourceType: 'hasil_deteksi',
        idField: 'id_hasil_deteksi',
        effect: () => createScan(tx, actor.id_user, input, config, clock()),
      },
    ));
}
