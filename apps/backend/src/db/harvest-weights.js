import { randomUUID } from 'node:crypto';

export function parseWeight(value) {
  if (typeof value !== 'string' || !/^[0-9]{1,8}(?:\.[0-9]{1,2})?$(?![\s\S])/.test(value)) throw new Error('Invalid exact harvest weight');
  const [whole, fraction = ''] = value.split('.');
  const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (minor > 9999999999n) throw new Error('Harvest weight exceeds range');
  return minor;
}

export function formatWeight(minor) {
  return `${minor / 100n}.${String(minor % 100n).padStart(2, '0')}`;
}

export async function backfillHarvest(tx) {
  const rows = (await tx.execute('SELECT CAST(id_detail_panen AS TEXT) AS id, CAST(berat AS TEXT) AS weight, CAST(CAST(berat AS TEXT) AS NUMERIC)=berat AS roundtrip FROM detail_panen')).rows;
  for (const row of rows) {
    let minor;
    try { if (Number(row.roundtrip) !== 1) throw new Error('Ambiguous float'); minor = parseWeight(row.weight); }
    catch { throw new Error(`Invalid legacy harvest weight at detail_panen ${row.id}: ${row.weight}`); }
    await tx.execute({ sql: 'UPDATE detail_panen SET berat_minor=? WHERE id_detail_panen=?', args: [minor, row.id] });
  }
  const headers = (await tx.execute('SELECT CAST(id_panen AS TEXT) AS id FROM panen')).rows;
  for (const row of headers) {
    const publicId = randomUUID();
    await tx.execute({ sql: "INSERT INTO sync_resource_links(resource_type,domain_id,public_id) VALUES ('panen',?,?)", args: [row.id, publicId] });
    await tx.execute({ sql: "INSERT INTO sync_resource_versions(resource_type,public_id,version,changed_at) VALUES ('panen',?,1,?)", args: [publicId, Date.now()] });
  }
}
