import type { Client } from '@libsql/client';
import type { FastifyRequest } from 'fastify';
import { authenticate, type Principal } from './sessions.js';
import { ApiError } from './errors.js';

declare module 'fastify' {
  interface FastifyRequest { principal: Principal | null }
}

export function requirePermission(db: Client, permission?: string, clock = Date.now) {
  return async (request: FastifyRequest) => {
    request.principal = await authenticate(db, request.headers.authorization, clock());
    if (permission && !request.principal.permissions.includes(permission)) {
      throw new ApiError(403, 'FORBIDDEN', 'Akses tidak diizinkan untuk akun ini.');
    }
  };
}
