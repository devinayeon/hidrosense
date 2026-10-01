import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { registerSyncOperations } from './operations.js';

export function registerSync(app: FastifyInstance, db: Client, clock: () => number) {
  registerSyncOperations(app, db, clock);
}
