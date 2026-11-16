# Slice E: harvest, sales, and cross-feature duplication sweep

Scope: every file in `src/features/harvest/` and `src/features/sales/`, the helpers they call (`common/weights.ts`, `common/money.ts`, `common/dates.ts`, `common/sync.ts`, `common/authenticated-write.ts`, `common/validation.ts`, `db/harvest-weights.ts`, `db/migrate.ts`), migrations 0001, 0005, 0011, 0013 and 0015, and a duplication sweep over all of `src/features/*`.

All proofs are scripts under `C:\Users\Delion\AppData\Local\Temp\claude\6f51bf7f9cfd15e3\7068d4a5-4b1d-4583-ab33-a15eb255e81e\scratchpad\learn\e\`:
- `proofs.test.mjs` (P1 to P8)
- `conc.test.mjs` (P7b)
- `query.test.mjs` (P9)

Each one runs against `fixture()` with `:memory:`. Run it from `apps/backend` with `node --import tsx --test <path>`. Output lines start with `[proof]`.

---

## Findings

### E1 [DUP] Legacy float sold weight is read four ways, and read and write paths disagree
- Severity: medium
- Status: VERIFIED
- Where:
  - `src/features/harvest/service.ts:39-43` (harvest PATCH sold floor)
  - `src/features/sales/service.ts:38-63` (`soldForHarvest`)
  - `src/features/sales/store.ts:23-39` (`exactWeight`, `exactPrice`)
  - `src/db/harvest-weights.ts:6-10` (backfill)
- What: The copies have drifted.
  - Harvest reads only the float `jumlah_kg`. It ignores `jumlah_kg_minor`, runs the round-trip check, and throws `HARVEST_SOLD_WEIGHT_INVALID`.
  - `soldForHarvest` prefers `jumlah_kg_minor`. It runs the round-trip check only on float rows and throws `SALE_LEGACY_AMOUNT_INVALID`.
  - `exactWeight` and `exactPrice` prefer the minor columns but have no round-trip check. They accept a float that the other two refuse.
  - So one legacy row is readable but blocks every write: GET shows a clean sale, a new sale on that harvest is refused, and even a note-only edit of the harvest is refused.
- Trace or proof: P1. The legacy row is `detail_penjualan(jumlah_kg=0.30000000000000004, harga_per_kg=1000, minor columns NULL)`.
  ```
  [proof] P1 GET sale 200 {..."jumlah_kg":"0.30","harga_per_kg":"1000.00","total_harga":"300.00"}
  [proof] P1 GET list 200
  [proof] P1 POST sale 409 SALE_LEGACY_AMOUNT_INVALID
  [proof] P1 PATCH harvest note 409 HARVEST_SOLD_WEIGHT_INVALID
  ```
  The two write-side refusals are what the tests expect (`sales.test.js:132`, `harvest.test.js:81`). What is new is that the read side shows the same row as exact `0.30` and `300.00`. The user sees a normal sale and cannot tell why both forms refuse.
  - Harvest ignoring `jumlah_kg_minor` makes no difference for rows the app writes. `insertLine` stores `formatWeight(q)` into a `DECIMAL` (NUMERIC affinity) column, which always round-trips; P3 and P7 harvest PATCHes over app-written sales succeed.
  - It only matters for a hand-edited row whose minor is set while the float is ambiguous. Harvest would refuse that row; sales would accept it.
- Failing input: the legacy row above.
- Suggested fix: Put one `readSoldMinor(tx, idPanen, excludeSaleId?)` in a shared module, using minor first and then float with the round-trip check. Call it from both services, and use the same round-trip rule in `exactWeight` and `exactPrice`, so a row that blocks writes also reads as unreadable (or flagged).

### E2 [LOGIC] Sales rows that predate the API have no sync identity and can never be edited
- Severity: medium
- Status: VERIFIED
- Where:
  - `migrations/0013_sales.up.sql` (no identity backfill)
  - `src/features/sales/service.ts:112` (`existing.version == null` leads to conflict)
  - `src/db/harvest-weights.ts:13-18` (harvest did get a backfill)
- What: 0011 backfills `sync_resource_links` and `sync_resource_versions` for every legacy `panen`, but 0013 does nothing of the kind for `penjualan`.
  - A legacy sale therefore reads with `version: null`, `public_id: null` and `pembeli: ""`.
  - `updateSale` turns `version == null` into `SALE_VERSION_CONFLICT` for every `expected_version`, so the row cannot be corrected: not its empty buyer, nor its weight.
  - It also never appears in `/sync/changes`.
  - The test suite treats such rows as supported data (`sales.test.js:132`).
- Trace or proof: P2.
  ```
  [proof] P2 legacy version/public_id/pembeli null null ""
  [proof] P2 PATCH expected 1 409 SALE_VERSION_CONFLICT
  [proof] P2 PATCH expected 2 409 SALE_VERSION_CONFLICT
  [proof] P2 PATCH expected 9 409 SALE_VERSION_CONFLICT
  [proof] P2 harvest from API has version 1
  ```
- Failing input: any `penjualan` row inserted without a link row, then `PATCH /api/v1/penjualan/1 {expected_version:'1', pembeli:'Fix'}`.
- Suggested fix: Add a migration that gives each unlinked `penjualan` a link and version 1, the same way `backfillHarvest` does for `panen`.

### E3 [LOGIC] A harvest weight edit changes every linked sale's `berat_layak`, but the sale's version does not move and no change is recorded for it
- Severity: low
- Status: VERIFIED
- Where:
  - `src/features/harvest/service.ts:31-51` (no `recordDerivedChange`)
  - `src/features/sales/store.ts:47,54-58,81` (sale embeds the harvest's `SUM(berat_minor)`)
- What: The sale response carries the harvest's current `berat_layak`. `updateHarvest` records no derived change for `penjualan`, so a device syncing from `/sync/changes` keeps the old `berat_layak` on every sale of that harvest. Compare `createHarvest`, damage and transfer: they call `recordDerivedChange` for the records whose derived values they move.
- Trace or proof: P3.
  ```
  [proof] P3 sale before 1 1.80
  [proof] P3 harvest patch 200
  [proof] P3 sale after 1 1.00          (version still 1)
  [proof] P3 changes since cursor (petani) ["panen"]
  ```
- Failing input: a sale on harvest 1, then a harvest PATCH that changes detail weights.
- Suggested fix: When `input.details` is present, call `recordDerivedChange(tx, 'penjualan', id, now)` for each sale on that harvest. Or drop `berat_layak` from the sale payload.

### E4 [LOGIC] Sale PATCH with detail fields deletes and re-inserts the detail row, so `id_detail_penjualan` changes
- Severity: low
- Status: VERIFIED
- Where: `src/features/sales/service.ts:125-126`
- What: Any PATCH that carries `id_panen`, `jumlah_kg` and `harga_per_kg` runs a `DELETE` and then an `INSERT`, even with identical values. The detail id the API returned before no longer exists, so a client keyed on `id_detail_penjualan` loses its reference.
- Trace or proof: P4. `[proof] P4 detail id before/after (same values) 1 2 version 2`
- Failing input: `PATCH /penjualan/1 {expected_version:'1', id_panen:'1', jumlah_kg:'0.50', harga_per_kg:'1000.00'}` with unchanged values.
- Suggested fix: `UPDATE detail_penjualan SET id_panen=?, jumlah_kg=?, ... WHERE id_penjualan=?`. The one-line rule already guarantees a single row.

### E5 [RISK] One unreadable legacy sale makes the whole `GET /penjualan` page return 409
- Severity: low
- Status: VERIFIED
- Where:
  - `src/features/sales/store.ts:64` (`SALE_DETAILS_MISSING`)
  - `src/features/sales/store.ts:32-39` (`exactPrice` throws)
  - `src/features/sales/store.ts:115` (mapped per page)
- What: `saleResponse` throws inside `headers.map`. A single header without details, or a single price like `1000.005`, therefore fails every list request whose page includes that row. The client has no way to page past it.
  - The stock check (`soldForHarvest`) never reads price. The bad-price row still counts toward sold weight, yet it cannot be listed.
- Trace or proof: P5.
  ```
  [proof] P5 list with bad price row 409 SALE_LEGACY_AMOUNT_INVALID
  [proof] P5 list with header-without-detail row 409 SALE_DETAILS_MISSING
  ```
- Failing input: `detail_penjualan(harga_per_kg=1000.005)`, or a `penjualan` row with no detail.
- Suggested fix: Validate legacy rows once, in a migration or preflight. Or return the row with a per-row error flag instead of failing the page.

### E6 [LOGIC] A NULL `berat_minor` gives a 500 from the harvest endpoints but a 409 from sales
- Severity: low
- Status: VERIFIED
- Where:
  - `src/features/harvest/store.ts:32` (`BigInt(String(null))`)
  - `src/features/sales/service.ts:30-34` (`HARVEST_NOT_SELLABLE`)
- What:
  - Sales deliberately handles a detail whose layak weight is unknown: `known_count` and `layak == null` lead to `409 HARVEST_NOT_SELLABLE`.
  - The harvest store has no such case. `BigInt('null')` throws a `SyntaxError`, which becomes `500 INTERNAL_ERROR` on both `GET /panen/:id` and the whole `GET /panen` list.
  - No API path writes NULL, and the 0011 backfill fills every row. So the sales branch is reachable only through out-of-band writes, and the two features handle that one state in opposite ways.
- Trace or proof: P6, using a raw `detail_panen` row without `berat_minor`.
  ```
  [proof] P6 GET harvest 500 INTERNAL_ERROR
  [proof] P6 GET harvest list 500 INTERNAL_ERROR
  [proof] P6 POST sale 409 HARVEST_NOT_SELLABLE
  ```
- Suggested fix: Decide whether NULL can exist. If it cannot, drop the sales branch (`known_count`). If it can, map NULL in `harvestResponse` to `berat_layak: null` the same way reject is already handled.

### E7 [DEAD] Re-check of the detail fields inside `updateSale` can never fire
- Severity: low
- Status: VERIFIED (schema)
- Where:
  - `src/features/sales/service.ts:119-122` (and the non-null assertion `input.id_panen!` on `:123`)
  - The check that already guarantees it: `src/features/sales/contracts.ts:50`
- What: `updateSaleSchema` already refuses any body that has one detail field without the other two, and `updateSale` is called only after `parseInput`, from `write.ts:53`. The inner throw is unreachable and returns the same 400 anyway.
- Trace or proof: `sales.test.js:154` (`jumlah_kg` alone gives 400 from Zod). The only caller is `salesWrite`, fed by `sales/index.ts:53`.
- Suggested fix: Drop the inner check and narrow the type, for example with `if (input.id_panen && input.jumlah_kg && input.harga_per_kg)`.

### E8 [DEAD] The result of `validateLine` is discarded, and weight and price are parsed twice
- Severity: low
- Status: VERIFIED (reading)
- Where:
  - `src/features/sales/service.ts:80` (returns `{quantity, price}`)
  - Callers at `:101` and `:124` ignore it
  - `insertLine` at `:88-89` parses both values again
- What: `parseMoney` inside `validateLine` exists only to build a value nobody reads.
- Suggested fix: Have `validateLine` return `{quantity, price}`, and have `insertLine` take those bigints.

### E9 [DEAD] Money and weight limits: one unused export and two unreachable range checks
- Severity: low
- Status: VERIFIED (grep and regex)
- Where:
  - `src/common/money.ts:1` `MAX_SALE_WEIGHT_MINOR`: imported nowhere in `src`, `test` or `test-support`. Only `dist/` contains it.
  - `src/common/money.ts:10`: the regex allows 10 integer digits and 2 decimals, so the largest value is exactly `999999999999` = `MAX_SALE_PRICE_MINOR`.
  - `src/common/weights.ts:9`: 8 integer digits give a maximum of `9999999999` = `MAX_WEIGHT_MINOR`.
- What: The range checks cannot fail. The real limit lives in the regex, and nothing ties the constants to the CHECK constraints in 0011 and 0013.
- Suggested fix: Delete the unused export. Either derive the regex from the constant or delete the dead comparison.

### E10 [RISK] `total_harga` can exceed 2^53, and a positive sale can total 0.00
- Severity: low
- Status: VERIFIED
- Where: `src/common/money.ts:18-20`, `src/features/sales/store.ts:84`
- What:
  - 99999999.99 kg × 9999999999.99 per kg is accepted, and `total_harga` is returned as `"999999999899000000.00"`. The server is exact because it uses BigInt and a string. A client that parses the string as `double` (Dart or JS) loses the cents.
  - Half-up rounding also lets 0.01 kg × 0.49 return `0.00`.
- Trace or proof: P8.
  ```
  [proof] P8 big sale 201 999999999899000000.00
  [proof] P8 0.01kg x 0.50 total 0.01
  [proof] P8 0.01kg x 0.49 total 0.00
  ```
- Suggested fix: Cap the line total (or the price) so that it stays under 2^53 / 100 and document the cap. Optionally refuse a line whose total rounds to zero.

### E11 [DUP] The `*/write.ts` wrappers have drifted in error mapping, header errors and the clock
- Severity: low
- Status: VERIFIED for the differences (reading). SUSPECTED for the 500 under SQLITE_BUSY: not reproduced, because in-process concurrency serialized cleanly (P7b).
- Where:
  - `harvest/write.ts:14-57`
  - `sales/write.ts:14-57`
  - `damage/write.ts:14-58`
  - `transfers/write.ts:14-58`
  - `tables/write.ts:12-30`
  - `nursery/write.ts:13-48`
  - `stock/write.ts:9-31`
  - `inventory/write.ts:13-32`
- What: How the copies differ in behaviour:
  1. **Busy errors.** Only `stock/write.ts:55-59` maps `SQLITE_BUSY`, `TRANSACTION_ACTIVE` and similar errors to `503 STOCK_WRITE_UNAVAILABLE`. In every other wrapper the same failure is a `500 INTERNAL_ERROR`.
  2. **Bad X-Client-Id.** `stock/write.ts:16` parses it with `parseInput` and answers "Input tidak sesuai kontrak API.". The others answer "Header sinkronisasi tidak valid.". Stock also skips the create-only rule, which is harmless because both stock operations create.
  3. **`expectedVersion`.** Harvest and sales do not pass it; they check it in the service with `HARVEST_VERSION_CONFLICT` / `SALE_VERSION_CONFLICT`. The other five pass it and get `VERSION_CONFLICT`. This difference is documented in `API.md:41-43`.
  4. **Clock.** Harvest, sales, damage, transfers and tables call `clock()` once for the receipt and again inside the effect, so the receipt `created_at` and the record's `changed_at` and `jakartaDate` can differ by milliseconds. Nursery and stock read `now` once.
  5. **Payload.** Inventory derives the resource and domain id from the `operationType` string and `payload.id`. Nursery and stock take the payload from the caller. The rest JSON-copy the whole `command`.
- Suggested fix (smallest shared helper): `common/domain-write.ts` exporting

  ```ts
  domainWrite({ db, request, clock, permission, resourceType, idField, operationType, payload, domainId?, expectedVersion?, createOnlyClientId = true, mapError? , effect(tx, actorId, now) })
  ```

  It computes `now` once and builds the operation the same way for all features. Each feature passes its own literals. To keep today's behaviour, stock passes `mapError` and harvest and sales leave out `expectedVersion`.

### E12 [DUP] "Date not in the future" is checked in five places with three different error codes
- Severity: low
- Status: VERIFIED (reading)
- Where:
  - `harvest/service.ts:10`: `VALIDATION_ERROR`
  - `sales/service.ts:11-15`: `VALIDATION_ERROR`
  - `damage/service.ts:10-14`: `VALIDATION_ERROR`
  - `transfers/service.ts:38-40`: `INVALID_TRANSFER_DATE`
  - `nursery/service.ts:18-19`: `SOWING_DATE_IN_FUTURE`
- What: The rule is the same everywhere, but the code a client must handle depends on the resource. `API.md` only promises a 400.
- Suggested fix: `assertNotFuture(date, now, message, code = 'VALIDATION_ERROR')` in `common/dates.ts`. Keep the current codes as arguments if clients depend on them.

### E13 [DUP] Unknown query parameters are refused on harvest and sales but accepted on inventory and accounts
- Severity: low
- Status: VERIFIED
- Where:
  - `emptyQuerySchema` copies: `damage/contracts.ts:42`, `harvest/contracts.ts:20`, `nursery/contracts.ts:58`, `sales/contracts.ts:57`, `stock/contracts.ts:36`, `tables/contracts.ts:21`, `transfers/contracts.ts:40`
  - Routes with no query parse: `inventory/inventaris.ts:46-56,83`, `inventory/jenis-inventaris.ts:39-56`, `inventory/obat.ts:40-62`, `accounts/read-employees.ts:26-28`, and the other `accounts/*` writes
- What: All seven schema copies are identical. The routes in inventory and accounts simply never call the check, so the "strict query" rule depends on which feature handles the request.
- Trace or proof: P9.
  ```
  [proof] P9 /api/v1/jenis-inventaris/1?junk=1 200 ok
  [proof] P9 /api/v1/panen/1?junk=1 400 VALIDATION_ERROR
  [proof] P9 /api/v1/penjualan/1?junk=1 400 VALIDATION_ERROR
  [proof] P9 /api/v1/employees/2?junk=1 200 ok
  ```
- Suggested fix: Export one `emptyQuerySchema` from `common/validation.ts` and apply it in every route without a list query. A Fastify `preValidation` hook on routes with no declared query would also work.

### E14 [RISK] Single-record GETs in stock and nursery read the header and its lines without one snapshot
- Severity: low
- Status: SUSPECTED
- Where:
  - `stock/index.ts:121-125` calls `getMovement(db, id)`, which runs 2 queries (`stock/store.ts:32-44`)
  - `nursery/index.ts:40-44` calls `getSowing(db, ...)`, which runs 2 queries (`nursery/store.ts:~50-76`)
  - Compare `harvest/index.ts:42-43` and `sales/index.ts:42-47`, which wrap the same shape in `db.transaction('read')`
- What: With a pooled file database, or a remote database with `concurrency > 1`, a write can land between the header query and the lines query. The response would then mix two states.
- Suggested fix: `withRead(db, fn)` (see the sweep below), used for every multi-query read.

### E15 [DUP] The batch's active-plant formula is written four times
- Severity: low
- Status: VERIFIED (reading; the copies are identical in effect)
- Where:
  - `harvest/service.ts:13` (inline subqueries)
  - `damage/service.ts:36-43` and `:97-106` (two separate queries, then subtraction in JS)
  - `tables/store.ts:7-9` (`batchActive`)
  - `transfers/store.ts:12-14` (`batchActive`)
- What: Every copy computes transferred minus damaged minus harvested, so they agree today. A new consumer of plants, such as a future treatment or sale-of-seedlings flow, would have to update all four.
- Suggested fix: Export `batchActive` from one module (for example `transfers/store.ts`) and use it in the harvest and damage queries.

### E16 [LOGIC] A missing detail id in a harvest PATCH body returns 404, against the 422 rule for references in the body
- Severity: low
- Status: VERIFIED (the test asserts the current behaviour)
- Where:
  - `harvest/service.ts:36` (`404 HARVEST_DETAIL_NOT_FOUND`)
  - The rule it breaks: `sales/service.ts:29` (422) and the test `sales-rework.test.js:34` ("a harvest missing from the sale body is 422; a sale missing from the URL stays 404")
  - Also `harvest/service.ts:14` (`TRANSFER_NOT_FOUND` 422)
- What: Elsewhere, an id that only appears in the body returns 422 and an id in the URL returns 404. `id_detail_panen` lives in the body and returns 404, which `harvest.test.js:53` pins. A client cannot tell "harvest gone" from "bad detail id" by status.
- Suggested fix: Return 422 with the same code and update `harvest.test.js:53`, or document the exception.

---

## Duplication sweep: patterns, every copy, drift, smallest helper

| Pattern | Copies (file:line) | Behaviour drift | Smallest shared helper |
|---|---|---|---|
| `*/write.ts` wrapper | See E11 (8 files) | Yes. See E11, items 1 to 5 | `domainWrite(config)` in `common/domain-write.ts` |
| Pagination `meta` block | `accounts/read-employees.ts:24`, `inventory/inventaris.ts:43`, `inventory/jenis-inventaris.ts:36`, `inventory/obat.ts:37`, `damage/store.ts:64-69`, `harvest/store.ts:86`, `nursery/store.ts:105`, `sales/store.ts:116`, `stock/store.ts:63`, `tables/store.ts:59`, `transfers/store.ts:229-235`. The offset `(page - 1) * limit` is repeated beside each one. | None. All use `Math.ceil(total / limit)`, so an empty list gives `total_pages: 0`. | `pageMeta({page, limit}, total)` and `pageOffset(q)` in `common/validation.ts` |
| Count plus page in one snapshot | `db.transaction('read')`: damage, harvest, nursery, sales, stock, tables, transfers. `db.batch([...], 'read')`: `accounts/read-employees.ts:14-22`, `inventory/inventaris.ts:34-41`, `jenis-inventaris.ts`, `obat.ts`. | None. Both give one snapshot. | Covered by `withRead` below |
| List with batched details (no N+1 anywhere) | `harvest/store.ts:76-83`, `sales/store.ts:106-113` (identical; each appends with `[...(map.get(id) ?? []), row]`, which copies the array on every row), `stock/store.ts:51-61` (`readDetails`, then `lines.filter` per header, which is O(headers×lines)). Placeholder builder: `harvest/store.ts:23`, `sales/store.ts:59`, `stock/store.ts:37`, and the IN list in `stock/store.ts` `assertItemsAvailable`. | None in output. Detail order is preserved because every query orders by detail id. | `placeholders(n)` and `groupRows(rows, key)` in a small `common/sql.ts` |
| Sync identity join and the `CAST AS TEXT` mapper | Join: `damage/store.ts:7-8`, `harvest/store.ts:11-12`, `nursery/store.ts:41-42`, `sales/store.ts:20-21`, `stock/store.ts:13-14`, `tables/store.ts:14-15`, `transfers/store.ts:16-17`, `sync/changes.ts:49-50`. The correlated-subquery variant: `inventory/store.ts:8-14`. Null mapping: `damage/store.ts:24-25`, `harvest/store.ts:54-55`, `sales/store.ts:72-73`, `tables/store.ts:31-32`, `inventory/store.ts:16-18`, `sync/changes.ts:60-61`. Three identical local `nullableId` copies: `nursery/store.ts:8`, `stock/store.ts:8`, `transfers/store.ts:10`. | None. The inventory subquery gives the same result. | `syncIdentityJoin(alias, resourceType, idExpr)`, `nullableString(v)` and `syncIdentity(row)` in `common/sync.ts` |
| Calendar-date schema in `contracts.ts` | `damage/contracts.ts:7-14`, `transfers/contracts.ts:7-14`, `nursery/contracts.ts:7-15`, `harvest/contracts.ts:5-8`, `sales/contracts.ts:8-11` | None observable. `isNaN` and `Number.isFinite` give the same answer on `Date.parse` output. Three copies carry a Zod message, but `parseInput` discards it (`common/validation.ts:21`). All accept year `0000`. | `calendarDateSchema` in `common/validation.ts`. Related: `assertNotFuture` (E12) |
| `emptyQuerySchema` and the `parseInput` preamble | Seven identical schemas (E13). Route order differs: `stock/index.ts:99-100` and `nursery` PATCH parse the body before the query; everyone else parses the query first. Inventory and accounts never parse the query (E13). | The order makes no difference: every path returns the same `400 VALIDATION_ERROR` and message. The missing parse does make a difference (E13). | One `emptyQuerySchema` in `common/validation.ts` |
| Read transaction open and close in `index.ts` | `damage/index.ts:31-36`, `harvest/index.ts:31-36` and `:42-43`, `nursery/index.ts:31-36`, `sales/index.ts:31-36` and `:42-47`, `stock/index.ts:32-34`, `tables/index.ts:20-21`, `transfers/index.ts:31-36`, `sync/changes.ts:33-66`, `stock/reconcile.ts:6-52` | The copies are identical. What drifts is which reads use one. Single GETs in stock and nursery run 2 queries outside a transaction (E14). | `withRead(db, (tx) => ...)` in `common/` |
| Legacy float reader (extra, from the slice brief) | See E1 (4 copies) | Yes. See E1 | `readSoldMinor(tx, idPanen, excludeSaleId?)` and one `exactLegacy(text, roundtrip, parse)` |
| Active-plant formula (extra) | See E15 (4 copies) | None today | One exported `batchActive` SQL fragment |

---

## Checked and fine

- **Sale and harvest edits racing each other.** Every check and write runs inside `authenticatedWrite`'s `BEGIN IMMEDIATE` transaction, and the pool serializes them. Eight concurrent sales of 0.30 kg against 2.00 kg, plus a harvest PATCH down to 1.00 kg, ended at 6×201, 2×`SALE_EXCEEDS_HARVEST_STOCK` and the harvest at `HARVEST_WEIGHT_BELOW_SOLD`. Final state: sold 180 ≤ layak 200 (P7b). A pairwise race gave the same kind of result (P7).
- **Sellable-weight maths agree.** Both sides use `SUM(detail_panen.berat_minor)` for "layak" and the same sold total for app-written rows. The harvest floor (`sum layak ≥ sold`) is the exact dual of the sale check (`qty ≤ layak - sold`). E1 is about legacy rows only.
- **Sale PATCH that moves to another harvest.** `validateLine` excludes the sale's own row from sold, and that row lives on the old harvest, so the new harvest's stock is computed correctly. The old harvest is freed by the `DELETE`. `sales.test.js:123` covers it.
- **Sale date rules.** A PATCH of the date alone is re-checked against the existing harvest date (`service.ts:128-132`). A detail change is checked against the new harvest. The future-date check uses the effective date. Harvest PATCH cannot change `tanggal_panen` (refused by the strict schema).
- **`HARVEST_NOT_SELLABLE` with partly unknown reject weights.** The rule looks only at `berat_minor` (layak). A legacy detail with `berat_reject_minor` NULL is still sellable, while the harvest shows `berat_reject` and `berat_total` as `null`. That is consistent, because sellable weight never needs the reject.
- **Plant counts after harvest updates.** Harvest PATCH cannot change `jumlah_tanaman` (`patchDetail` has no such key, and the strict object refuses it). This is deliberate: the test is "counts stay immutable" (`harvest.test.js:56`). Active-plant counts in transfers, tables and damage therefore stay correct, and no derived change is needed.
- **Harvest, transfer and damage dates.** Every event only subtracts from a fixed transferred count, and the sum is capped at that count. So no ordering of dates can make the running active count go negative. Damage and harvest carry no date rule between them, and none is needed for count correctness.
- **Rounding of `total_harga`.** It is half-up `(q*p + 50) / 100` on non-negative bigints and exact (P8). With one line per sale there is no aggregate rounding drift.
- **Version handling.** Harvest `existing.version !== expected` with a `null` version also leads to conflict, so harvest and sales behave the same.
- **Ambiguous legacy sold rows blocking a note-only harvest PATCH.** `harvest.test.js:81` asserts this, so it is intended.
- **Strict schemas.** The duplicate `id_pemindahan` and `id_detail_panen` checks, the 1 to 100 detail bounds and the 64 KiB body limit on both write routes hold.

## Count

16 findings in total.

| Category | Count | IDs |
|---|---|---|
| DUP | 5 | E1, E11, E12, E13, E15 |
| LOGIC | 5 | E2, E3, E4, E6, E16 |
| DEAD | 3 | E7, E8, E9 |
| RISK | 3 | E5, E10, E14 |

By severity: 2 medium (E1, E2), 14 low. None is critical or high.
