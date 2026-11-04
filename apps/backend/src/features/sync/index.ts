import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { registerSyncChanges } from './changes.js';
import { registerSyncOperations } from './operations.js';

export function registerSync(app: FastifyInstance, db: Client, clock: () => number) {
  registerSyncOperations(app, db, clock);
  registerSyncChanges(app, db, clock);
}
