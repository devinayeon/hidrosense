import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { requirePermission } from '../../common/authorization.js';
import { emptyQuerySchema, parseInput } from '../../common/validation.js';
import { listNotifications, markAllNotificationsRead } from './store.js';

export function registerNotifications(app: FastifyInstance, db: Client, clock: () => number) {
  app.get('/api/v1/notifications', { preHandler: requirePermission(db, undefined, clock) }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    return { data: await listNotifications(db, request.principal!.id_user, clock()) };
  });

  app.post('/api/v1/notifications/read-all', { preHandler: requirePermission(db, undefined, clock) }, async (request) => {
    parseInput(emptyQuerySchema, request.query);
    return { data: await markAllNotificationsRead(db, request.principal!.id_user, clock()) };
  });
}
