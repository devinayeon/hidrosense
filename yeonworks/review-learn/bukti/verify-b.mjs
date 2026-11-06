// My own check of slice-B claims B1 and B3. In-memory database only.
const src = 'file:///D:/Dev/Projects/hidrosense/apps/backend/src/';
const { openDatabase } = await import(src + 'db/client.ts');
const { loadMigrations, migrate } = await import(src + 'db/migrate.ts');
const all = await loadMigrations();
const out = {};

// B1: a database built on the old local numbering, then an explicit rollback of its last migration
const db = await openDatabase({ url: ':memory:' });
await migrate(db, all.slice(0, 11));
await db.execute('CREATE INDEX idx_sync_operations_key_lower ON sync_operations (id_user, lower(operation_key))');
await db.execute("INSERT INTO _schema_migrations (id, checksum) VALUES ('0012_operation_key_lower', 'lama')");
const rolled = await migrate(db, all, { direction: 'down', allowDataLoss: true });
const last = (await db.execute('SELECT id FROM _schema_migrations ORDER BY id DESC LIMIT 1')).rows[0].id;
const hasWeights = Number((await db.execute("SELECT COUNT(*) AS n FROM pragma_table_info('detail_panen') WHERE name='berat_minor'")).rows[0].n);
out.B1 = { asked_to_roll_back: '0012_operation_key_lower', actually_rolled_back: rolled, last_applied_now: last, detail_panen_berat_minor_column_left: hasWeights };

// B3: does the receipt lookup use the expression index for its lower() half?
const fresh = await openDatabase({ url: ':memory:' });
await migrate(fresh, all);
const plan = async (sql) => (await fresh.execute({ sql: `EXPLAIN QUERY PLAN ${sql}`, args: [1, 'a', 'a', 'a'] })).rows.map((r) => String(r.detail));
out.B3_as_written = await plan("SELECT operation_type FROM sync_operations WHERE id_user=? AND (operation_key=? OR lower(operation_key)=?) ORDER BY (operation_key=?) DESC, id_change DESC LIMIT 1");
out.B3_lower_only = await plan("SELECT operation_type FROM sync_operations WHERE id_user=? AND lower(operation_key)=? AND ?=? LIMIT 1");
out.B3_id_maps = (await fresh.execute({ sql: "EXPLAIN QUERY PLAN SELECT client_id FROM sync_id_maps WHERE id_user=? AND resource_type=? AND lower(client_id)=?", args: [1, 'x', 'a'] })).rows.map((r) => String(r.detail));
console.log(JSON.stringify(out, null, 1));
