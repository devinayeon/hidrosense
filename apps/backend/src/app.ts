import Fastify, { LogController } from 'fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import { readConfig, type AppConfig } from './config.js';
import { ApiError, installErrors } from './common/errors.js';
import { consumeLimit } from './common/rate-limit.js';
import { loadMigrations, migrationStatus } from './db/migrate.js';
import { registerLogin } from './features/auth/login.js';
import { registerRefresh } from './features/auth/refresh.js';
import { registerMe } from './features/auth/me.js';
import { registerLogout } from './features/auth/logout.js';
import { registerCreateEmployee } from './features/accounts/create-employee.js';
import { registerReadEmployees } from './features/accounts/read-employees.js';
import { registerUpdateEmployee } from './features/accounts/update-employee.js';
import { registerDeactivateEmployee } from './features/accounts/deactivate-employee.js';
import { registerProfile } from './features/accounts/profile.js';
import { registerSyncOperations } from './features/sync/operations.js';

interface AppOptions { db: Client; config?: AppConfig; clock?: () => number }

function requestPath(url: string) {
  try {
    return decodeURIComponent(url.split('?', 1)[0]);
  } catch {
    throw new ApiError(400, 'BAD_REQUEST', 'URL permintaan tidak valid.');
  }
}

export function buildApp({ db, config = readConfig(), clock = Date.now }: AppOptions) {
  const app = Fastify({
    logger: {
      level: config.logLevel,
      redact: ['req.headers.authorization', 'req.headers.cookie', 'password', 'access_token', 'refresh_token'],
    },
    logController: new LogController({ disableRequestLogging: true }),
    requestIdHeader: false,
    genReqId: () => randomUUID(),
    trustProxy: config.proxies.length ? config.proxies : false,
    bodyLimit: 16 * 1024,
    requestTimeout: 15000,
    connectionTimeout: 15000,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } },
  });
  app.decorateRequest('principal', null);
  installErrors(app);
  app.register(helmet);
  app.register(cors, {
    origin: config.origins.length ? config.origins : false,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type'],
    exposedHeaders: ['X-Request-Id', 'Retry-After'],
    credentials: false,
  });
  app.addHook('onRequest', async (request, reply) => {
    reply.header('x-request-id', request.id).header('cache-control', 'no-store');
    const path = requestPath(request.url);
    if (path.startsWith('/api/')) {
      if (config.environment === 'production' && request.protocol !== 'https') {
        throw new ApiError(426, 'HTTPS_REQUIRED', 'Gunakan HTTPS untuk mengakses API.');
      }
      await consumeLimit(db, `ip:${request.ip}`, 120, 60000, clock(), reply);
    }
  });
  app.addHook('onResponse', async (request, reply) => {
    request.log.info({ method: request.method, route: request.routeOptions.url ?? 'unmatched',
      statusCode: reply.statusCode, elapsedMs: reply.elapsedTime }, 'Request completed');
  });
  app.addHook('onClose', async () => { db.close(); });
  app.get('/health/live', async () => ({ data: { status: 'alive' } }));
  app.get('/health/ready', async () => {
    try {
      const status = await migrationStatus(db, await loadMigrations());
      if (!status.length || status.some((item: { status: string }) => item.status !== 'applied')) throw new Error('Pending migrations');
      await db.execute('SELECT id_session FROM auth_sessions LIMIT 0');
      return { data: { status: 'ready' } };
    } catch {
      throw new ApiError(503, 'NOT_READY', 'Layanan belum siap.');
    }
  });
  registerLogin(app, db, clock);
  registerRefresh(app, db, clock);
  registerMe(app, db, clock);
  registerLogout(app, db, clock);
  registerCreateEmployee(app, db, clock);
  registerReadEmployees(app, db, clock);
  registerUpdateEmployee(app, db, clock);
  registerDeactivateEmployee(app, db, clock);
  registerProfile(app, db, clock);
  registerSyncOperations(app, db, clock);
  return app;
}
