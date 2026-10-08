import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
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
  registerDeactivateEmployee(app, db, clock);
  registerActivateEmployee(app, db, clock);
  registerProfile(app, db, clock);
}
