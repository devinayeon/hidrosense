import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { ApiError } from '../../common/errors.js';
import { registerCreateEmployee } from './create-employee.js';
import { registerReadEmployees } from './read-employees.js';
import { registerUpdateEmployee } from './update-employee.js';
import { registerDeactivateEmployee } from './deactivate-employee.js';
import { registerActivateEmployee } from './activate-employee.js';
import { registerProfile } from './profile.js';

export function registerAccounts(app: FastifyInstance, db: Client, clock: () => number) {
  registerCreateEmployee(app, db, clock);
  registerReadEmployees(app, db, clock);
  registerUpdateEmployee(app, db, clock);
  // Rute tanpa body ini hanya menerima body kosong, tetapi curl, Postman, dan banyak klien HTTP
  // tetap mengirim `Content-Type: application/json`. Parser bawaan Fastify menjawab 400 untuk body
  // kosong; di lingkup ini body kosong sah, JSON rusak tetap 400, dan rute lain tidak berubah.
  void app.register(async (scope) => {
    scope.addContentTypeParser('application/json', { parseAs: 'string' }, (_request, body, done) => {
      const text = String(body);
      if (text.trim() === '') return done(null, undefined);
      try { return done(null, JSON.parse(text)); }
      catch { return done(new ApiError(400, 'VALIDATION_ERROR', 'Body JSON tidak valid.'), undefined); }
    });
    registerDeactivateEmployee(scope, db, clock);
    registerActivateEmployee(scope, db, clock);
  });
  registerProfile(app, db, clock);
}
