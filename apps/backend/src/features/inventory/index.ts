import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { registerJenisInventaris } from './jenis-inventaris.js';
import { registerObat } from './obat.js';
import { registerInventaris } from './inventaris.js';

export function registerInventory(app: FastifyInstance, db: Client, clock: () => number) {
  registerJenisInventaris(app, db, clock);
  registerObat(app, db, clock);
  registerInventaris(app, db, clock);
}
