import { randomUUID } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { buildApp } from './app.js';
import { readConfig } from './config.js';
import { isRemoteUrl, openDatabase } from './db/client.js';

// Fastify instances are thenable, so an async function resolves to the awaited type.
type App = Awaited<ReturnType<typeof buildApp>>;

/**
 * Migrations are not checked here: they run once from the deploy pipeline, not on every cold start.
 * GET /health/ready reports a database that is behind.
 */
export async function openServerlessApp(): Promise<App> {
  const url = process.env.DATABASE_URL;
  const config = readConfig();
  // A function's filesystem does not persist, so a local database in production would lose data.
  if (config.environment === 'production' && !isRemoteUrl(url)) {
    throw new Error('DATABASE_URL must be a remote libsql:// or https:// URL in production.');
  }
  // Without proxy trust every production request would be refused as plain HTTP.
  if (config.environment === 'production' && config.proxyHops === undefined && !config.proxies.length) {
    throw new Error('Production requires TRUST_PROXY_HOPS or TRUSTED_PROXIES.');
  }
  const app = buildApp({ db: await openDatabase({ url }), config });
  await app.ready();
  return app;
}

function sendNotReady(response: ServerResponse) {
  const requestId = randomUUID();
  response.writeHead(503, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'retry-after': '1',
    'x-request-id': requestId,
  });
  response.end(JSON.stringify({ error: { code: 'NOT_READY', message: 'Layanan belum siap.', request_id: requestId } }));
}

/** Node (req, res) function handler. One app is reused for the life of the instance. */
export function createHandler(open: () => Promise<App> = openServerlessApp) {
  let opening: Promise<App> | undefined;
  return async function handler(request: IncomingMessage, response: ServerResponse) {
    let app: App;
    try {
      app = await (opening ??= open().catch((error) => {
        opening = undefined;
        throw error;
      }));
    } catch {
      // Never log the raw error: it may contain the database URL or token.
      console.error('API startup failed. Check DATABASE_URL, DATABASE_AUTH_TOKEN, TRUST_PROXY_HOPS and the other API settings.');
      sendNotReady(response);
      return;
    }
    // Stay pending until the reply is finished: some platforms freeze the instance on return.
    const finished = new Promise((resolve) => response.once('close', resolve));
    app.server.emit('request', request, response);
    await finished;
  };
}

export default createHandler();
