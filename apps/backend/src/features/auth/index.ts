import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { registerLogin } from './login.js';
import { registerRefresh } from './refresh.js';
import { registerMe } from './me.js';
import { registerLogout } from './logout.js';

export function registerAuth(app: FastifyInstance, db: Client, clock: () => number) {
  registerLogin(app, db, clock);
  registerRefresh(app, db, clock);
  registerMe(app, db, clock);
  registerLogout(app, db, clock);
}
