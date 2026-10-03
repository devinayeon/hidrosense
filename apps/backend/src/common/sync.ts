import { createHash, randomUUID } from 'node:crypto';
import type { Transaction } from '@libsql/client';
import { ApiError } from './errors.js';

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Operation = { operation_key: string; operation_type: string; payload: Json; resource_type?: string; client_id?: string };

function canonicalJson(value: Json): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
}

function hashPayload(operation: Operation) {
  return createHash('sha256').update(canonicalJson({
    operation_type: operation.operation_type,
    payload: operation.payload,
    resource_type: operation.resource_type ?? null,
    client_id: operation.client_id ?? null,
  })).digest('hex');
}

async function executeOperation<T extends Json>(
  tx: Transaction, actorId: string, operation: Operation, now: number,
  effect: (publicId: string | null) => Promise<T>,
) {
  // Canonicalize at the transaction boundary too; old mappings keep their original spelling.
  operation = { ...operation, ...(operation.client_id ? { client_id: operation.client_id.toLowerCase() } : {}) };
  const mappings = operation.resource_type && operation.client_id ? (await tx.execute({
    sql: `SELECT client_id,public_id FROM sync_id_maps
      WHERE id_user=? AND resource_type=? AND lower(client_id)=?`,
    args: [actorId, operation.resource_type, operation.client_id],
  })).rows : [];
  if (new Set(mappings.map((row) => String(row.public_id))).size > 1) {
    throw new ApiError(409, 'CLIENT_ID_CONFLICT', 'UUID klien memiliki mapping lama yang bertentangan.');
  }
  const payloadHash = hashPayload(operation);
  const existing = (await tx.execute({
    sql: `SELECT operation_type,payload_hash,result_json FROM sync_operations
      WHERE id_user=? AND operation_key=?`, args: [actorId, operation.operation_key],
  })).rows[0];
  if (existing) {
    const stored = JSON.parse(String(existing.result_json));
    const legacyHash = createHash('sha256').update(canonicalJson({
      operation_type: operation.operation_type, payload: operation.payload,
    })).digest('hex');
    let legacyIdentityMatches = operation.client_id === undefined && operation.resource_type === undefined;
    if (operation.operation_type === 'sync.reserve-id' && operation.resource_type && operation.client_id) {
      legacyIdentityMatches = mappings.some((row) => row.public_id === stored.data?.public_id);
    }
    const legacyMatch = legacyIdentityMatches && stored.data !== undefined
      && stored.operation !== undefined && existing.payload_hash === legacyHash;
    const priorCasingMatches = mappings.some((row) =>
      row.public_id === stored.data?.public_id
      && existing.payload_hash === hashPayload({ ...operation, client_id: String(row.client_id) }));
    if (existing.operation_type !== operation.operation_type
      || (existing.payload_hash !== payloadHash && !legacyMatch && !priorCasingMatches)) {
      throw new ApiError(409, 'OPERATION_CONFLICT', 'Kunci operasi sudah dipakai dengan isi berbeda.');
    }
    return { ...stored, replayed: true } as { data: T; operation: Json; replayed: true };
  }

  let publicId: string | null = null;
  if (operation.resource_type && operation.client_id) {
    const mapping = mappings[0];
    publicId = mapping ? String(mapping.public_id) : randomUUID();
    if (!mapping) await tx.execute({
      sql: `INSERT INTO sync_id_maps (id_user,resource_type,client_id,public_id,created_at) VALUES (?,?,?,?,?)`,
      args: [actorId, operation.resource_type, operation.client_id, publicId, now],
    });
  }
  const data = await effect(publicId);
  const inserted = await tx.execute({
    sql: `INSERT INTO sync_operations (id_user,operation_key,operation_type,payload_hash,result_json,created_at)
      VALUES (?,?,?,?,?,?) RETURNING CAST(id_change AS TEXT) AS revision`,
    args: [actorId, operation.operation_key, operation.operation_type, payloadHash, '{}', now],
  });
  const result = { data, operation: {
    operation_key: operation.operation_key, revision: String(inserted.rows[0].revision),
    public_id: typeof data === 'object' && data !== null && !Array.isArray(data) ? data.public_id ?? publicId : publicId,
    ...(typeof data === 'object' && data !== null && !Array.isArray(data) && 'version' in data ? { version: data.version } : {}),
  } };
  await tx.execute({ sql: 'UPDATE sync_operations SET result_json=? WHERE id_user=? AND operation_key=?',
    args: [JSON.stringify(result), actorId, operation.operation_key] });
  return { ...result, replayed: false };
}

async function nextResourceVersion(tx: Transaction, resourceType: string, publicId: string, now: number) {
  const result = await tx.execute({ sql: `INSERT INTO sync_resource_versions (resource_type,public_id,version,changed_at) VALUES (?,?,1,?)
    ON CONFLICT(resource_type,public_id) DO UPDATE SET version=version+1, changed_at=excluded.changed_at
    RETURNING CAST(version AS TEXT) AS version`, args: [resourceType, publicId, now] });
  return String(result.rows[0].version);
}

export function reserveClientId(tx: Transaction, actorId: string, operation: Operation, now: number) {
  return executeOperation(tx, actorId, operation, now, async (publicId) => ({ public_id: publicId }));
}

// A domain operation can create a secondary immutable stock movement in its own transaction.
// Its primary receipt belongs to that domain; the stock header still needs a stable public identity.
export async function initializeStockIdentity(tx: Transaction, domainId: string, now: number) {
  const publicId = randomUUID();
  await tx.execute({ sql: `INSERT INTO sync_resource_links(resource_type,domain_id,public_id) VALUES ('stok',?,?)`,
    args: [domainId, publicId] });
  const version = await nextResourceVersion(tx, 'stok', publicId, now);
  return { public_id: publicId, version };
}

type DomainMutation<T extends Json> = {
  resourceType: string;
  domainId?: string;
  idField: string;
  effect: () => Promise<T>;
};

export function executeDomainMutation<T extends Json & Record<string, Json>>(
  tx: Transaction, actorId: string, operation: Operation, now: number, mutation: DomainMutation<T>,
) {
  return executeOperation(tx, actorId, operation, now, async (reservedId) => {
    if (!mutation.domainId && reservedId) {
      const existing = await tx.execute({ sql: 'SELECT 1 FROM sync_resource_links WHERE public_id=?', args: [reservedId] });
      if (existing.rows.length) throw new ApiError(409, 'RESOURCE_ALREADY_EXISTS', 'Identitas klien sudah terikat ke resource.');
    }
    const data = await mutation.effect();
    const domainId = mutation.domainId ?? String(data[mutation.idField]);
    const linked = (await tx.execute({
      sql: 'SELECT public_id FROM sync_resource_links WHERE resource_type=? AND domain_id=?',
      args: [mutation.resourceType, domainId],
    })).rows[0];
    const publicId = linked ? String(linked.public_id) : reservedId ?? randomUUID();
    if (!linked) await tx.execute({
      sql: 'INSERT INTO sync_resource_links (resource_type,domain_id,public_id) VALUES (?,?,?)',
      args: [mutation.resourceType, domainId, publicId],
    });
    const version = await nextResourceVersion(tx, mutation.resourceType, publicId, now);
    return { ...(data as Record<string, Json>), public_id: publicId, version } as T & { public_id: string; version: string };
  });
}
