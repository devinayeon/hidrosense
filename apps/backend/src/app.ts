import Fastify, { LogController } from 'fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import { readConfig, type AppConfig } from './config.js';
import { ApiError, installErrors, sendError } from './common/errors.js';
import { consumeLimit } from './common/rate-limit.js';
import { loadMigrations, migrationStatus } from './db/migrate.js';
import { registerAuth } from './features/auth/index.js';
import { registerAccounts } from './features/accounts/index.js';
import { registerSync } from './features/sync/index.js';
import { registerInventory } from './features/inventory/index.js';
import { registerStock } from './features/stock/index.js';
import { registerNursery } from './features/nursery/index.js';
import { registerTables } from './features/tables/index.js';
import { registerTransfers } from './features/transfers/index.js';
import { registerDamage } from './features/damage/index.js';

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
    frameworkErrors: sendError,
  });
  app.decorateRequest('principal', null);
  installErrors(app);
  app.register(helmet);
  app.register(cors, {
    origin: config.origins.length ? config.origins : false,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'X-Client-Id'],
    exposedHeaders: ['X-Request-Id', 'Retry-After'],
    credentials: false,
    // Prepare CORS headers for policy errors, but let the universal hook decide the response.
    preflightContinue: true,
    strictPreflight: false,
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
    if (request.method === 'OPTIONS'
      && (!request.headers.origin || !request.headers['access-control-request-method'])) {
      throw new ApiError(400, 'BAD_REQUEST', 'Preflight CORS tidak valid.');
    }
    if (request.method === 'OPTIONS' && config.origins.length) {
      return reply.code(204).header('content-length', '0').send();
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
  registerAuth(app, db, clock);
  registerAccounts(app, db, clock);
  registerSync(app, db, clock);
  registerInventory(app, db, clock);
  registerStock(app, db, clock);
  registerNursery(app, db, clock);
  registerTables(app, db, clock);
  registerTransfers(app, db, clock);
  registerDamage(app, db, clock);
  return app;
}
