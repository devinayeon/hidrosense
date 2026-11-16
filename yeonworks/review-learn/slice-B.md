# Slice B: database layer audit

Scope: `src/db/*`, `migrations/0001`–`0015` (up and down), `src/features/sync/*`, `scripts/*.mjs`, plus every `src/features/*/store.ts` and the services that write domain rows.

Proof scripts are in `C:\Users\Delion\AppData\Local\Temp\claude\6f51bf7f9cfd15e3\7068d4a5-4b1d-4583-ab33-a15eb255e81e\scratchpad\learn\b\`. Each one builds in-memory databases only:
- `roundtrip.mjs`: up and down for every migration, with a schema diff.
- `checks.mjs`: the renumbered-database rollback, legacy rows, the seeder on real data, query plans, and the Turso probe insert.
- `checks2.mjs`: a local replay of the deploy-script digest, receipt-lookup timing, and paging.
- `checks3.mjs`: which records the feed announces.
- `checks4.mjs`: legacy sale weights and the seed stock date.

Run them from `apps/backend` with `node --import tsx <script>`.

---

### B1 [LOGIC] `db:rollback` on a database with the old `0012_operation_key_lower` row rolls back `0011_harvest_weights` instead
- Severity: medium
- Status: VERIFIED
- Where: `src/db/migrate.ts:38-41`, `src/db/migrate.ts:76`, `src/db/migrate.ts:79-81`
- What: `forgetRenumberedMigration` runs for both directions. On a `down`, it first silently deletes the `0012_operation_key_lower` history row and drops its index. The last remaining applied migration is then `0011_harvest_weights`, so the rollback also undoes that one. The operator asked to undo one index migration. Instead they lose `detail_panen.berat_reject_minor`, `berat_minor` and every `panen` public id/version. The CLI prints only `down: 0011_harvest_weights`.
- Trace or proof: `checks.mjs` section A. It builds the old local history (0001–0011, then a fake `0012_operation_key_lower` row and index) and runs `migrate(db, all, { direction: 'down', allowDataLoss: true })`. Output: `rolled back: [ '0011_harvest_weights' ] last applied now: 0010_damage_index`.
- Failing input: `_schema_migrations` = 0001..0011 + `0012_operation_key_lower`; run `npm run db:rollback -- --allow-data-loss`.
- Suggested fix: Call `forgetRenumberedMigration` only when `direction === 'up'`. For `down`, treat the stale row as the migration being rolled back: delete the row, drop the index, and stop.

### B2 [LOGIC] The seeder writes demo rows into real data, and fails outright on a bootstrapped database
- Severity: medium
- Status: VERIFIED
- Where: `src/db/seed.ts:60-77` (users), `src/db/seed.ts:104-126` (stock), `src/db/seed.ts:132-158` (sowings, tables, transfer), `src/db/seed-cli.ts:11`
- What: Every seed row uses a fixed primary key with `ON CONFLICT(<pk>) DO NOTHING`. If the seed parent row already exists as real data, the seed still writes children that point at it. Those writes go straight to SQL and skip every business rule. The comment at `seed.ts:54-55` says "existing rows always win", but these child rows still get written.
  - Real `inventaris` 1..5 with no stock yet: the seed posts a "Stok Awal" incoming movement into them and adds to their `stok_saldo`.
  - Real `meja_tanam` 1 and `penyemaian` 1: the seed inserts `pemindahan` 1, moving 200 seedlings onto that table regardless of capacity, sowing age, seed count or table status. The real table then answers 409 `TABLE_BALANCE_INVALID`.
  - The user insert targets `ON CONFLICT(username)` with an explicit `id_user`. After `auth:bootstrap` creates the owner under any other username at id 1, seeding aborts with `UNIQUE constraint failed: users.id_user`.
  - `DELETE FROM auth_rate_limits` also clears real brute-force lockouts whenever `ALLOW_PROD_SEED=1` is used.
- Trace or proof: `checks.mjs` section C.
  - C1, bootstrap with username `pemilik`, then seed: `seed after bootstrap fails: SQLITE_CONSTRAINT: UNIQUE constraint failed: users.id_user`.
  - C3, a real jenis, items "Pupuk Daun"/"Pupuk Akar" (gram) and table `REAL` with 5 holes, then seed: `real item 1 Pupuk Daun saldo now 1000`, and `real table 1 after seed: 409 TABLE_BALANCE_INVALID`.
  - C2 is the same with a real 10-seed sowing: `seed ok`, and a 200-plant transfer is inserted from it.
- Failing input: Any local DB with real `inventaris` id 1..5 (unit `gram`/`liter`/...), `meja_tanam` id 1 or `penyemaian` id 1, then `npm run db:seed`.
- Suggested fix: Refuse to seed when any seeded table already has rows the seed did not create, for example by checking a marker row. At minimum, insert children only when their seed parent was inserted in the same run. Make the user insert conflict on `id_user` as well, or refuse.

### B3 [RISK] Every write scans the caller's whole receipt ledger and id-map list; the 0014 index is never used for its key
- Severity: medium
- Status: VERIFIED
- Where: `src/common/sync.ts:41-48` (receipt lookup), `src/common/sync.ts:32-36` (id-map lookup), `migrations/0014_operation_key_lower.up.sql`
- What: The receipt query is `WHERE id_user=? AND (operation_key=? OR lower(operation_key)=?)`. The `OR` stops SQLite from using `lower(operation_key)` in `idx_sync_operations_key_lower`. The plan is `SEARCH ... USING INDEX idx_sync_operations_key_lower (id_user=?)`, so every receipt of that user is scanned. This query runs inside every write transaction, so the cost grows with ledger size, which is exactly what 0014 meant to prevent. The id-map lookup `lower(client_id)=?` has no expression index either and scans every map of that user and type.
- Trace or proof: `checks2.mjs` section G, with 20 000 receipts and 20 000 maps for one user:
  - receipt lookup as written: 21.79 ms/query
  - the same lookup on `lower()` alone: 0.11 ms
  - id-map lookup as written: 14.95 ms
  - id-map exact match: 0.09 ms

  On Turso this cost is paid inside the single-writer transaction.
- Failing input: A farm account with tens of thousands of writes, which is about one receipt per write over a season.
- Suggested fix: Query `lower(operation_key)=?` only, then rank by `operation_key=?` (the index then covers it). Add `CREATE INDEX ... ON sync_id_maps(id_user, resource_type, lower(client_id))`.

### B4 [LOGIC] Rows that predate their feature's sync identity are missing from `/sync/changes`, and some can never be edited
- Severity: medium
- Status: VERIFIED
- Where: `migrations/0013_sales.up.sql` (no link backfill, unlike `0011` through `src/db/harvest-weights.ts:13-18`), `migrations/0015_sync_changes.up.sql:10-14` (backfill only from `sync_resource_versions`), `src/common/sync.ts:161-162`, `src/features/sales/service.ts:112-113`
- What: Only `jenis-inventaris`/`obat`/`inventaris` (0005), `stok` (0006) and `panen` (0011) rows that already existed get a public id and version from a migration. Older `penjualan`, `meja_tanam`, `pemindahan`, `kerusakan_tanaman` and `penyemaian` rows keep `public_id: null`. They:
  - never appear in the change feed, whose backfill and triggers both key off versions, so a device doing a full pull from cursor 0 misses them;
  - reject any update that sends `expected_version` with 409 `VERSION_CONFLICT` (`sync.ts:162`).

  `updateSaleSchema` requires `expected_version`, and `updateSale` throws when `version == null`. So every pre-0013 sale is permanently uneditable.
- Trace or proof: `checks.mjs` section B migrates to 0012, inserts a legacy sowing, table, transfer, harvest and sale, then migrates the rest.
  - GET of the sale: `public_id/version: null null`.
  - PATCH `/penjualan/1` with `expected_version` `1`: 409 `SALE_VERSION_CONFLICT`.
  - Feed: `[]`.
  - PATCH `/meja-tanam/1` with `expected_version: '1'`: 409 `VERSION_CONFLICT`.
- Failing input: Any `penjualan` row inserted before 0013 was applied, for example data imported from the DBML-era schema.
- Suggested fix: Add a forward migration that assigns links and version 1 to every unlinked row of each synced type (0005 and 0006 show the pattern). The 0015 triggers then announce them.

### B5 [LOGIC] Writes that change another record's response are not announced, and one stored field changes without a version bump
- Severity: medium
- Status: VERIFIED
- Where: `src/features/inventory/jenis-inventaris.ts:50` and `src/features/inventory/obat.ts:56` (renames are copied into `inventaris` responses via `store.ts:72`), `src/features/tables/store.ts:86-91` (`kode_meja` copied into `transfers/store.ts:25` and `harvest/store.ts:16`), `src/features/harvest/service.ts:45-48` (weight copied into `sales/store.ts:47,81` `berat_layak`), `src/features/transfers/service.ts:83-88`
- What: The feed's rule is "a record whose response changed must appear". These writes break it:
  - Renaming a jenis or obat changes `nama_jenis`/`nama_obat` on every linked inventaris. Only the jenis/obat is announced.
  - Renaming a table code changes `kode_meja` on its transfers and harvest details. Only `meja-tanam` is announced.
  - Editing harvest weights changes `berat_layak` on its sales. Only `panen` is announced.

  A device that caches those records keeps stale names and weights until a full reload. Separately, `createTransfer` writes `status_penyemaian='selesai'`, which is a stored field and not a derived value. It announces the sowing only as a derived change, so the version stays 1. A client that uses version to skip re-reads never sees the status change.
- Trace or proof: `checks3.mjs`. Feed after each step:
  - rename jenis: `['jenis-inventaris:1@v2']`
  - rename meja kode: `['meja-tanam:1@v2']`
  - edit harvest weight: `['panen:1@v2']`

  The re-read responses do change: `inventaris.nama_jenis now Bibit | pemindahan.kode_meja now M-01 | penjualan.berat_layak now 3.00`. After the full transfer: `status selesai version 1`.
- Failing input: PATCH `/jenis-inventaris/1 {nama_jenis:'Bibit'}`, then pull the feed. `inventaris:1` is missing.
- Suggested fix: Call `recordDerivedChange` for the dependent rows in these four write paths, for example every `inventaris` with that `id_jenis_inventaris`/`id_obat`. For the auto-`selesai`, bump the sowing's version through `nextResourceVersion`, or document that clients must always re-read.

### B6 [RISK] `deploy-turso-migrations.mjs` reports failure after a correct data migration, and only after the remote is already migrated
- Severity: medium
- Status: VERIFIED (local replay of the script's own `digest()` comparison; no remote touched)
- Where: `scripts/deploy-turso-migrations.mjs:83-89`, `scripts/deploy-turso-migrations.mjs:98`
- What: The "domain preservation" check requires every pre-existing table, including `sync_resource_links`, `sync_resource_versions` and `meja_tanam`, to hash the same after `migrate()`. But 0011 inserts `panen` links and versions, and 0012 rewrites `status_meja`. Both are intended changes. With any harvest row, or any table whose stored status differs from its derived occupancy, the check fails after `migrate()` has committed. The run then reports `status: failed` and exits 1 while the remote is already upgraded. The error report keeps only `{ name, code }`, so the operator cannot tell which table failed. Live writes between the snapshot and the comparison cause the same false failure.
- Trace or proof: `checks2.mjs` section F. A DB at 0010 with one harvest and a `'Tersedia'` table is migrated to head. Tables whose digest changed: `[ 'meja_tanam', 'sync_resource_versions', 'sync_resource_links' ]`.
- Failing input: Deploy pending `0011_harvest_weights` onto a database with at least one `panen` row.
- Suggested fix: Compare only tables and columns the pending migrations do not own. Alternatively, let each migration declare the tables it rewrites. Put the failing table name in the report.

### B7 [DEAD] `verify-turso-features.mjs` cannot pass on any schema since 0006
- Severity: low
- Status: VERIFIED
- Where: `scripts/verify-turso-features.mjs:82-85`
- What: The B005 probe inserts `inventaris(..., stok_minimum='0.25')` without `stok_minimum_minor`. Trigger `b006_minimum_insert` requires both or neither, so the probe always aborts. The opt-in live verification therefore always reports `failed`, and it can no longer catch a real regression.
- Trace or proof: `checks.mjs` section E. The same insert fails with `SQLITE_CONSTRAINT: STOCK_MINIMUM_INVALID`.
- Suggested fix: Pass `stok_minimum_minor` (`25`) in the probe insert. Also assert the probe against a local in-memory DB first, as `verify-turso-live.mjs:54` already does.

### B8 [DEAD] `idx_sync_operations_change` indexes the rowid alias
- Severity: low
- Status: VERIFIED
- Where: `migrations/0003_sync_foundation.up.sql:13`
- What: `id_change` is `INTEGER PRIMARY KEY`, which is the rowid. The secondary index on it is never chosen and costs a write on every receipt insert. The plan for `WHERE id_change=?` is `SEARCH sync_operations USING INTEGER PRIMARY KEY (rowid=?)`.
- Trace or proof: `checks.mjs` section D, `idx_sync_operations_change`.
- Suggested fix: Drop it in a new migration.

### B9 [RISK] Every sale read aggregates the whole `detail_panen` table
- Severity: low
- Status: VERIFIED
- Where: `src/features/sales/store.ts:54-58`
- What: The `LEFT JOIN (SELECT id_panen, SUM(berat_minor) ... FROM detail_panen GROUP BY id_panen) hp` is materialized in full for each GET and each list page. The plan is `MATERIALIZE hp | SCAN detail_panen USING INDEX idx_detail_panen_id_panen | ... AUTOMATIC COVERING INDEX`. The cost therefore grows with all harvest history, not with the page.
- Trace or proof: `checks.mjs` section D, `sale detail layak`.
- Suggested fix: Use a correlated scalar subquery `(SELECT SUM(berat_minor) FROM detail_panen x WHERE x.id_panen=d.id_panen)`, which uses `idx_detail_panen_id_panen` per line.

### B10 [RISK] `/sync/changes` re-groups the whole tail on every page; cursors can be silently reused after a rollback or restore
- Severity: low
- Status: VERIFIED (plan); SUSPECTED (cursor reuse)
- Where: `src/features/sync/changes.ts:41-53`, `src/features/sync/changes.ts:35-38`, `migrations/0015_sync_changes.down.sql`
- What: The inner query groups every change with `id_change > cursor` into a temp B-tree before applying `LIMIT`. The plan is `SEARCH sync_changes USING INTEGER PRIMARY KEY (rowid>?) | USE TEMP B-TREE FOR GROUP BY | ... TEMP B-TREE FOR ORDER BY`. So the first full pull costs O(N) per page and O(N²/limit) overall, and `sync_changes` is never compacted. Separately, the only reset signal is `cursor > MAX(id_change)`. After 0015 down then up, `DROP TABLE` removes its `sqlite_sequence` row and the re-backfill restarts at 1. After a restore from an older backup, ids are reused too. A client whose cursor is still within the new range sees no 409 and skips records.
- Trace or proof: `checks.mjs` section D, `changes page`. Paging correctness itself holds (see Checked and fine).
- Suggested fix: Keep a server "epoch" (a random id written by 0015 and by restores), return it in `meta`, and answer 409 when it differs. Compact superseded rows periodically, or add `(resource_type, domain_id, id_change)` and walk ids in bounded windows.

### B11 [DEAD] Seeded stock movement 1 has no public identity and never reaches the feed
- Severity: low
- Status: VERIFIED
- Where: `src/db/seed.ts:161-181` (the list has no `stok` entry), `src/db/seed.ts:108-126`
- What: Every other seeded resource gets a fixed public UUID and version 1. `stok` 1 does not. `GET /stok/1` returns `public_id: null, version: null`, and the feed never lists `stok:1`. `test/sync-changes.test.js` asserts exactly 19 rows, which is the list length, so the gap goes unnoticed.
- Trace or proof: `checks.mjs` section C3: `seeded stok 1 public_id: null`.
- Suggested fix: Add `['stok', '1', '70000000-0000-4000-8000-000000000001']` to `syncResources`.

### B12 [DEAD] Columns, an index and a branch that no code reads or reaches
- Severity: low
- Status: VERIFIED (grep of `src`, `scripts`, `test`)
- Where:
  - `sync_operations.created_at` and `sync_id_maps.created_at`: written at `src/common/sync.ts:75,81`, never selected.
  - `stok.id_perawatan`: no caller passes the `{ id_perawatan }` origin. The only origin is nursery's `{ id_penyemaian }` at `src/features/nursery/service.ts:35`. This makes the `Origin` variant at `src/features/stock/store.ts:94`, the `original.id_perawatan` test at `src/features/stock/service.ts:24`, and `idx_stok_care_origin` (0006) dead.
  - `m.status_meja` and `m.jumlah_lubang`: selected at `src/features/transfers/store.ts:26-27` but never read by `transferRow`.
  - The `penanganan_cuaca` table: no code reads or writes it.
  - `seed()` returns `success`, which no caller reads (`seededUsers` is read only by `test/seed.test.js:30`).
- What: Dead weight that misleads readers. For example, the stock code looks as if care treatments already consume stock.
- Suggested fix: Drop the unused selects. Leave the care and weather schema, but mark it as reserved for the deferred AI and weather features.

### B13 [DUP] The active-plants formula is written five times
- Severity: low
- Status: VERIFIED (read)
- Where:
  - `src/features/tables/store.ts:7-9`
  - `src/features/transfers/store.ts:12-14`
  - `src/features/harvest/service.ts:13` (inline)
  - `src/features/damage/service.ts:36-43` and `97-106` (split into separate queries)
  - `migrations/0012_table_occupancy_status.up.sql:4-8` (frozen, which is fine)
- What: Each copy computes `jumlah_tanaman - SUM(damage) - SUM(harvest)`. None has drifted yet. A new deduction, such as a care loss, must be added in four live places, or table status, capacity checks and harvest limits will disagree.
- Suggested fix: Export one `batchActive` SQL fragment from a shared module and use it in tables, transfers, harvest and damage.

### B14 [DUP] "Weight already sold from a harvest" is read three ways, and they disagree on legacy rows
- Severity: low
- Status: VERIFIED
- Where: `src/features/sales/store.ts:23-30` (`exactWeight`: prefers minor, no round-trip guard), `src/features/sales/service.ts:38-63` (`soldForHarvest`: prefers minor, with guard), `src/features/harvest/service.ts:39-43` (legacy `jumlah_kg` only, with guard, ignores `jumlah_kg_minor`)
- What: A legacy sale line stored as an inexact REAL reads as `0.30` on GET, but every new sale on that harvest is refused. Worse, `updateHarvest` runs the sold-weight check even when only `keterangan` changes, so an unrelated note edit is blocked too.
- Trace or proof: `checks4.mjs` B15, with a legacy `detail_penjualan.jumlah_kg = 0.1+0.2`:
  - `GET legacy sale -> 200 0.30`
  - `new sale on same harvest -> 409 SALE_LEGACY_AMOUNT_INVALID`
  - `harvest edit {keterangan} -> 409 HARVEST_SOLD_WEIGHT_INVALID`
- Failing input: `INSERT INTO detail_penjualan(...,jumlah_kg,...) VALUES (...,0.1+0.2,...)` before 0013, then PATCH `/panen/1 {expected_version, keterangan:'x'}`.
- Suggested fix: Use one helper, `soldForHarvest`, in harvest and sales. Skip the sold check in `updateHarvest` when `details` is absent. Make GET use the same guard, or flag the line.

### B15 [LOGIC] Seeded stock date mixes the Jakarta calendar date with a UTC rendering
- Severity: low
- Status: VERIFIED
- Where: `src/db/seed.ts:31,112`, `src/features/stock/store.ts:43`
- What: `tanggal_stok` is `${jakartaDate(now)} 08:00:00`, and `movementResponse` renders it as `...T08:00:00.000Z`. So the seeded stock is shown at 15:00 WIB. Between 17:00 and 24:00 UTC it is dated in the future: seeding at `2026-11-05T20:00Z` stores `2026-11-06 08:00:00`, which renders as `2026-11-06T08:00:00.000Z`, 12 h ahead. Every other stock row is written as a UTC ISO string at `stock/store.ts:109`.
- Trace or proof: `checks4.mjs` B16.
- Suggested fix: Write `new Date(now).toISOString()`, as `appendMovement` does.

---

## Checked and fine

- **Every down migration reverses its up (schema).** `roundtrip.mjs` steps up 0001→0015, then down one at a time, diffing `sqlite_master` against the snapshot taken before each up. The only difference is whitespace in the re-created `idx_penyemaian_user_date` (0008 down). Re-up applies all 15. The 0006 down `DROP COLUMN reversal_of` (a column with an FK) succeeds once the triggers and indexes are dropped.
- **Data across up-down-up.** The 0001/0006 downs are destructive or guarded on purpose: 0006 refuses when any stock exists. The 0013 down/up turns `belum_lunas` into `lunas`, which `test/sales-migration.test.js:47-49` asserts as intended. The 0011 down/up re-backfills `berat_minor` from `berat`, loses reject weights and issues new panen public ids; that is expected for a data-loss rollback.
- **0005/0006 SQL UUID generator** yields 36-character, version-4, variant-8 ids that satisfy `CHECK(length=36)`.
- **CHECK constraints against Zod schemas.** Every length, enum and range agrees, with Zod equal or stricter. Checked: users fields; jenis/obat/inventaris names and units; `detail_stok.satuan`; `jumlah_minor`/`saldo_minor` against `toMinor` (≤ 999999999999); `stok_minimum_minor > 0` against `positiveDecimal`; `status_penyemaian` trigger against `z.enum`; `kode_meja`/`status_meja` ≤ 30; `jenis_kerusakan` ≤ 100; `pembeli` ≤ 100; the `status_pembayaran` enum; `berat_minor`/`jumlah_kg_minor` ≤ 9999999999 against `parseWeight`; `harga_per_kg_minor` ≤ 999999999999 against `parseMoney`; `sync_*` key lengths; and the 0006 whitespace set against JS `trim()`.
- **Paging on `/sync/changes`.** Cursor semantics are correct: records are grouped by their newest change and ordered by that id. Records edited between pages reappear later. Hidden types are skipped without stalling the cursor. An empty visible list (`IN ()`) returns zero rows with `has_more:false`. `next_cursor` echoes the input on an empty page. Proven in `checks2.mjs` section H (edits between pages, hidden interleaved type) and in the existing `test/sync-changes.test.js`. With one MAX aggregate, SQLite takes the bare `changed_at` from the newest row.
- **The `sync_changes` triggers see a link for every versioned write.** Every code path inserts the link before the version: `executeDomainMutation`, `initializeStockIdentity`, `backfillHarvest` and the seeder. Retried and failed writes add no change (existing tests).
- **Write paths and announcements.** Coverage of every domain write:
  - Inventory create, update and deactivate: own version.
  - Stock create and reverse: link and version for the new header, plus a derived `inventaris` change per line.
  - Nursery create: sowing version, stock identity and inventaris derived change. Nursery update: own version.
  - Table create and update: own version.
  - Transfer create: own version, plus derived `penyemaian` and `meja-tanam` changes. Transfer update: own version.
  - Damage create and update: own version, plus derived `pemindahan` and `meja-tanam` changes.
  - Harvest create: own version, plus derived `pemindahan` and `meja-tanam` changes. Harvest update: own version.
  - Sales create and update: own version.
  - Users are not a synced type, by design.

  The gaps are listed in B4, B5 and B11.
- **`readPermissions` keys match every `resourceType`** used by the write wrappers (`kerusakan_tanaman` with an underscore, `meja-tanam` and `jenis-inventaris` with hyphens). The sales/pegawai split works.
- **The seeder's fixed public UUIDs cannot collide with real rows.** Real public ids always come from server `randomUUID()`; a client never chooses one. Links are only removed by migration downs. The seed ids are valid v4 UUIDs.
- **Renumber handling, `up` direction.** It is atomic with the rest of the migration, so a mismatched history rolls the delete back. A DB already on the new numbering is untouched (test plus reasoning). `migrationStatus` rejecting the old history until `db:migrate` runs is intended (`test/migration-renumber.test.js:27`).
- **List-query indexes.**
  - The penyemaian, pemindahan, kerusakan, panen and penjualan list orders match their `(date DESC, id DESC)` indexes.
  - `isReversed` uses the partial unique `idx_stok_reversal`.
  - The stock-history `EXISTS` uses `idx_detail_stok_header_item`.
  - `reconcile.ts` keyset pagination over `(id_stok, id_detail_stok)` is correct and runs in one read transaction.
- **`backfillHarvest`** rejects ambiguous REALs (round-trip guard), and its range equals the column CHECK.
- **`migrate`** wraps everything in one write transaction, verifies `foreign_keys=1` inside it, runs `foreign_key_check` before commit and rolls back history together with the schema. `loadMigrations` rejects unpaired files and duplicate versions.
- **CLI guards.** `cli.ts` requires `--allow-data-loss` for down and scrubs URLs from errors. `seed-cli.ts` blocks remote URLs even when `NODE_ENV=development`. `backupDatabase` refuses to overwrite and uses a bound `VACUUM INTO`.

Counts: LOGIC 5, RISK 4, DEAD 4, DUP 2 (15 total). Severity: medium 6 (B1–B6), low 9.
