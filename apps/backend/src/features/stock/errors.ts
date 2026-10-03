// Classify installed libSQL transport/lock errors; constraints and code bugs stay 500.
const retryableCodes = new Set([
  'SQLITE_BUSY', 'SQLITE_BUSY_SNAPSHOT', 'SQLITE_BUSY_TIMEOUT', 'SQLITE_LOCKED',
  'TRANSACTION_ACTIVE', 'TRANSACTION_TIMEOUT',
  'SERVER_ERROR', 'STREAM_EXPIRED', 'STREAM_CLOSED', 'HRANA_WEBSOCKET_ERROR',
  'HRANA_CLOSED_ERROR', 'FETCH_ERROR', 'ECONNRESET', 'ETIMEDOUT', 'ECONNREFUSED',
  'UND_ERR_SOCKET', 'UND_ERR_CONNECT_TIMEOUT', 'UND_ERR_HEADERS_TIMEOUT', 'UND_ERR_BODY_TIMEOUT',
]);

export function stockUnavailable(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const value = error as { code?: unknown; cause?: unknown };
  return (typeof value.code === 'string' && retryableCodes.has(value.code))
    || (value.cause !== undefined && value.cause !== error && stockUnavailable(value.cause));
}
