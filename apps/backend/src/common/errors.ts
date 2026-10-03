import type { FastifyError, FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

export class ApiError extends Error {
  constructor(public statusCode: number, public code: string, message: string) {
    super(message);
  }
}

export function sendError(error: FastifyError, request: FastifyRequest, reply: FastifyReply) {
  let status = 500;
  let code = 'INTERNAL_ERROR';
  let message = 'Terjadi kesalahan pada server.';
  if (error instanceof ApiError) {
    status = error.statusCode; code = error.code; message = error.message;
  } else if (error.validation) {
    status = 400; code = 'VALIDATION_ERROR'; message = 'Input tidak sesuai kontrak API.';
  } else if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
    status = error.statusCode;
    code = status === 413 ? 'PAYLOAD_TOO_LARGE' : status === 415 ? 'UNSUPPORTED_MEDIA_TYPE' : 'BAD_REQUEST';
    message = 'Permintaan tidak dapat diproses.';
  }
  // Never log raw errors: database errors may contain SQL, credentials or input.
  if (status >= 500) request.log.error({ code, requestId: request.id }, 'Request failed');
  if (status === 401) reply.header('www-authenticate', 'Bearer');
  if (code === 'STOCK_WRITE_UNAVAILABLE') reply.header('retry-after', '1');
  return reply.header('x-request-id', request.id).header('cache-control', 'no-store')
    .code(status).send({ error: { code, message, request_id: request.id } });
}

export function installErrors(app: FastifyInstance) {
  app.setNotFoundHandler(async () => { throw new ApiError(404, 'NOT_FOUND', 'Endpoint tidak ditemukan.'); });
  app.setErrorHandler<FastifyError>(sendError);
}
