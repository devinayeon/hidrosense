import { createHash, randomUUID } from 'node:crypto';
import type { Transaction } from '@libsql/client';
import { ApiError } from './errors.js';

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Operation = { operation_key: string; operation_type: string; payload: Json; resource_type?: string; client_id?: string };

function canonicalJson(value: Json): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
}

function hashPayload(operation: Operation) {
  return createHash('sha256').update(canonicalJson({ operation_type: operation.operation_type, payload: operation.payload })).digest('hex');
}

export async function replayOperation(tx: Transaction, actorId: string, operation: Operation, now: number) {
  const payloadHash = hashPayload(operation);
  const existing = (await tx.execute({
    sql: `SELECT operation_type,payload_hash,result_json FROM sync_operations
      WHERE id_user=? AND operation_key=?`, args: [actorId, operation.operation_key],
  })).rows[0];
  if (existing) {
    if (existing.operation_type !== operation.operation_type || existing.payload_hash !== payloadHash) {
      throw new ApiError(409, 'OPERATION_CONFLICT', 'Kunci operasi sudah dipakai dengan isi berbeda.');
    }
    return { data: JSON.parse(String(existing.result_json)), replayed: true };
  }

  let publicId: string | null = null;
  if (operation.resource_type && operation.client_id) {
    const mapping = (await tx.execute({
      sql: `SELECT public_id FROM sync_id_maps WHERE id_user=? AND resource_type=? AND client_id=?`,
      args: [actorId, operation.resource_type, operation.client_id],
    })).rows[0];
    publicId = mapping ? String(mapping.public_id) : randomUUID();
    if (!mapping) await tx.execute({
      sql: `INSERT INTO sync_id_maps (id_user,resource_type,client_id,public_id,created_at) VALUES (?,?,?,?,?)`,
      args: [actorId, operation.resource_type, operation.client_id, publicId, now],
    });
  }
  const inserted = await tx.execute({
    sql: `INSERT INTO sync_operations (id_user,operation_key,operation_type,payload_hash,result_json,created_at)
      VALUES (?,?,?,?,?,?) RETURNING CAST(id_change AS TEXT) AS revision`,
    args: [actorId, operation.operation_key, operation.operation_type, payloadHash, '{}', now],
  });
  const data = { operation_key: operation.operation_key, revision: String(inserted.rows[0].revision), public_id: publicId };
  await tx.execute({ sql: 'UPDATE sync_operations SET result_json=? WHERE id_user=? AND operation_key=?',
    args: [JSON.stringify(data), actorId, operation.operation_key] });
  return { data, replayed: false };
}

export async function nextResourceVersion(tx: Transaction, resourceType: string, publicId: string, now: number) {
  await tx.execute({ sql: `INSERT INTO sync_resource_versions (resource_type,public_id,version,changed_at) VALUES (?,?,1,?)
    ON CONFLICT(resource_type,public_id) DO UPDATE SET version=version+1, changed_at=excluded.changed_at`, args: [resourceType, publicId, now] });
  return String((await tx.execute({ sql: `SELECT version FROM sync_resource_versions WHERE resource_type=? AND public_id=?`, args: [resourceType, publicId] })).rows[0].version);
}
