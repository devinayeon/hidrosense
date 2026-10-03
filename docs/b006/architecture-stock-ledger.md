# B006 Stock Ledger Architecture and Refinement Decisions

Date: 3 October 2026, Asia/Jakarta. Design and implementation contract. Authority: [PRD](prd-stock-ledger.md). Actual local proof and deployment limits: [implementation evidence](../backend-b006.md).

## Existing seams and architectural fit

Keep the repository's layered Fastify vertical slices. Transport handlers validate with Zod and call a stock use case; the stock use case owns domain rules and calls persistence functions receiving an active `Transaction`. SQL, append/projection persistence and trigger constraints belong to the store/migration layer. Use `authenticatedWrite` and `executeDomainMutation` for current authentication, receipt replay, identity/version, commit/rollback. Future owning-domain handlers call the same stock use case with their existing transaction rather than calling HTTP handlers.

The [architecture refinement](architecture-refinement-2026-10-03.md) deepens the existing append module: duplicate-reversal and inventory/unit guards are private persistence prerequisites inside `appendMovement`, before any writes. Use cases retain normalization and eligibility rules for original/source movements. The transaction, error precedence, public contract and schema remain unchanged; callers no longer coordinate separate guard interfaces.

Implemented files: `features/stock/contracts.ts`, `service.ts`, `store.ts`, `write.ts`, `errors.ts`, `reconcile.ts`, `index.ts`, `common/quantities.ts`, and migration pair `0006_stock_ledger`. `app.ts` registers the routes. The owning-domain interface remains internal; B007/B014 endpoints are separate later work.

The requested backend guidelines are applied to validation, separate responsibilities, explicit errors and testability. Their Express/Prisma/BaseController/Sentry/unifiedConfig examples do not describe this project's Fastify/libSQL stack. The explicit project plan's vertical slices and existing central config/log/error boundary remain authoritative; B006 adds no replacement framework, ORM, controller base class, or telemetry dependency.

BFRI: architectural fit 5, testability 5, complexity 3, data risk 3, operational risk 1: `5 + 5 - 3 - 3 - 1 = 3`. The moderate-risk design requires transaction, migration, and concurrency proofs. The score is a planning assessment, not a safety certification.

## Requirement ownership

| Requirement | Owner / design |
| --- | --- |
| FR-001 | Contracts parse decimal strings; store integer fields and exact formatter; minimum companion column |
| FR-002 | Contracts compare units; store unit snapshot; migration locks historical item units |
| FR-003 | Stock use case, `authenticatedWrite`, store all-or-nothing append |
| FR-004 | Bounded projection and conditional update in active write transaction |
| FR-005 | Sealed header/details plus immutable/late-insert database guards |
| FR-006 | Reversal use case, exact copy, unique self-reference, current-balance checks |
| FR-007 | Stock write boundary requires key; shared sync wrapper owns hash/replay/receipt |
| FR-008 | Stock read store projects IDs to TEXT, quantities via integer formatter, indexed pagination |
| FR-009 | Existing permissions, pre-handler guard, authenticated transaction |
| FR-010 | New migration preflight/backfill/constraints, snapshot and recovery procedure |
| FR-011 | Active-transaction interface, unique source links, domain-owned correction |
| FR-012 | Error classifier and transport retry contract; receipt resolves uncertain commits |
| NFR-001 | Zod schemas, bound queries, central config/auth/log/error policies |
| NFR-002 | Projection/checks, sealed append, BigInt reconciliation, atomic receipt |
| NFR-003 | Indexed projection, bounded lines/pages, no external work within transaction |
| NFR-004 | Expand/validate/backfill, atomic migration history, single-version stock writers, recovery |
| NFR-005 | Existing dependencies and explicit seams; service/store/route regression tests |
| NFR-006 | Existing structured logs, stable categories, reconciliation evidence |

## Persistence model

Expand existing `stok` and `detail_stok`; do not create a parallel ledger disconnected from the source DDL.

| Entity | New fields / invariant |
| --- | --- |
| `stok` | `sealed` integer boolean; nullable `reversal_of` FK to `stok`; direction exactly masuk/keluar; reversal uniqueness; non-null sowing/care links unique and mutually exclusive |
| `detail_stok` | `jumlah_minor` INTEGER >0/max999999999999; non-null unit snapshot; unique `(id_stok,id_inventaris)`; retain old `jumlah` compatibility column |
| `stok_saldo` | PK/FK item ID; `saldo_minor` INTEGER with typeof integer and range 0..999999999999 |
| `inventaris` | Nullable positive `stok_minimum_minor` with same type/range; retain old minimum compatibility column |
| Existing sync tables | Bind resource type `stok` to immutable header ID and public UUID; version 1 for each header; receipt captures committed result |

SQL CHECK constraints and INSERT/seal triggers enforce integer storage, direction, bounds, non-null detail companions and linkage structure. Additive companion columns stay nullable at the column level for legacy backfill; inserted details cannot omit them. Unique indexes enforce one reversal and one consumption header per future domain origin. Index history by header ID and detail item/header ID. Add FK/index on `reversal_of`.

Database guards must prevent header deletion, all edits to a sealed header, detail deletion/update, and additional details under a sealed header. Only allow the initial seal transition on an otherwise unchanged header after at least one detail exists. Stock use case must seal before returning to the receipt wrapper. Freeze item unit using a trigger checking all historical details, not current projection balance. Trusted application writers are responsible for committing no unsealed header and maintaining the projection; privileged raw-SQL repair is outside the normal API and requires reconciliation.

Compatibility DECIMAL values are never used for balances or minimum comparisons. New writes derive their textual compatibility representation from the integer quantity. A rollback to an old writer is unsafe even if compatibility columns remain readable.

## Atomic write sequence

1. Validate transport structure and supplied key/client UUID; normalize the payload before hashing. Reject duplicate item lines and sort by numeric ID.
2. Enter `authenticatedWrite` in write mode; recheck session and correct manual or owning-domain permission.
3. Enter the existing sync mutation wrapper. Read receipt/mapping. Return matching stored receipt before state-dependent checks; reject changed request/key or bound client identity.
4. Manual create checks each referenced inventory item is active and submitted unit matches. Reversal reads sealed original, rejects prohibited source/reversal state, and copies exact positive details; inactive originals are allowed for reversal.
5. Insert the new unsealed header. For each unique item, initialize its zero projection if absent; apply the conditional update below and require one affected row. Use integers throughout.
6. Insert positive details and compatibility values/unit snapshots. Seal header. Future domain caller performs related domain state changes in this same transaction.
7. Shared sync layer binds identity/version and stores the exact response receipt. Internal linked consumption initializes its secondary stock UUID/version 1 through `initializeStockIdentity` in this same transaction; its owning domain remains responsible for current authorization and the primary receipt. Manual stock writes obtain metadata through `executeDomainMutation`. Commit once. Any known failure rolls back every change and closes transaction.

Conditional SQL contract implemented in `store.ts`:

```sql
INSERT INTO stok_saldo (id_inventaris,saldo_minor) VALUES (?,0)
ON CONFLICT(id_inventaris) DO NOTHING;

-- delta is a validated signed integer in [-999999999999,999999999999].
UPDATE stok_saldo
SET saldo_minor = saldo_minor + CAST(? AS INTEGER)
WHERE id_inventaris = ?
  AND saldo_minor + CAST(? AS INTEGER) BETWEEN 0 AND 999999999999;
-- rowsAffected must be 1. Zero means insufficient stock or cap exceeded.
```

Both operands and their sum fit signed64; the maximum absolute intermediate magnitude is below 2×10^12. Validate the delta before binding; do not use CAST to truncate arbitrary external decimal input. A failed bounded update is classified from the delta sign: deduction means insufficient balance, addition means cap exceeded. A previous line's update is rolled back if a later line fails.

Projection is a derived cache whose correctness is maintained transactionally, not an independently editable balance. Ledger remains the audit source. Reconcile by streaming committed headers/details in numeric `(id_stok,id_detail_stok)` order and folding integer signed quantities with BigInt; compare each final item balance against the projection. Do not use a lifetime DECIMAL SUM or a gross aggregate that can overflow despite bounded net stock. Reconciliation repair is an explicit maintenance activity, never an automatic balance reset in a user request.

`transaction('write')` maps to `BEGIN IMMEDIATE` in installed `@libsql/core/lib-esm/util.js:3`, and both local and Hrana paths use it. SQLite allows one writer; a process mutex cannot coordinate multiple clients. [SQLite transaction documentation](https://www.sqlite.org/lang_transaction.html) explains immediate-lock contention; [Turso SDK reference](https://docs.turso.tech/sdk/ts/reference) documents transaction modes and commit/rollback. This design requires later proof against the project's actual deployed remote service.

## Retry and conflict sequence

- Commit succeeds, HTTP response disappears: resend persisted normalized input and same key. Receipt lookup returns original response; no fresh balance check or append occurs.
- One writer loses lock acquisition: return classified 503 with Retry-After 1, no successful receipt. Client retries same key with backoff; no automatic unbounded server loop.
- Connection/commit result uncertain: close transaction safely; do not assert rollback certainty. Return availability error if a response can be sent. Next same-key request checks whether commit and receipt actually exist.
- Permission/session changed: deny replay after authentication; do not bypass revocation to return a receipt.
- Same key with another actor: receipts are independent; balances still serialize. Automatic logical consumption must also have the domain-unique origin constraint.
- Same target reversed with two keys: unique `reversal_of` and in-transaction validation permit one new reversal; matching receipt with original key remains replayable.

Use error-specific classification from the installed driver. Preserve generic INTERNAL_ERROR for unexpected failures. Shared HTTP throttle can also contend; tests must distinguish its failures from the stock transaction under test.

## Legacy migration and compatibility strategy

Design the next migration after 0005; confirm the number again when implementation starts. Preserve migration checksums, existing record IDs/FKs, sequences, public identities and receipt JSON. Run the whole upgrade under the migration runner's transaction and FK check.

Preflight all existing stock headers/details and inventory minima, including data inserted outside APIs. No assumption that these tables are empty is permitted. Validate direction, 1–100 details/header, duplicate items, unique source links, real timestamps, unit labels, quantity bounds and chronological nonnegative/bounded balances. Reject ambiguous legacy reversal semantics rather than invent them. Preserve originals on failure and report item/header IDs for controlled reconciliation without publishing database contents.

Exact backfill algorithm:

1. Inspect `typeof(jumlah)` and `CAST(jumlah AS TEXT)` for each legacy detail; minima similarly. Permit only stored numeric integer/real values whose canonical text consists of digits and at most one decimal point, with 1–10 whole digits and at most two fractional digits. NULL is allowed only for minimum. Reject exponent notation, unsupported strings/blobs, excess precision, nonpositive amounts, and out-of-range values.
2. Split that canonical text at the decimal point. Treat absent fraction as empty; pad fraction right to two digits. Compute minor quantity using integer digit parsing: `CAST(whole AS INTEGER) * 100 + CAST(padded_fraction AS INTEGER)`. Do not multiply the stored REAL by 100 and do not ROUND.
3. Verify rendering the integer back to a two-place decimal and interpreting that as NUMERIC equals the stored original. Preserve the original DECIMAL field untouched. This preserves the stored value; it cannot reconstruct user keystrokes discarded by historical numeric affinity. Record this limitation in upgrade evidence.
4. Add/backfill the integer companions and unit snapshots, preserving row/sequence IDs. Existing header time in SQLite CURRENT_TIMESTAMP form is UTC; strictly validate and format it for API output without changing original stored text. New times are server-assigned UTC. Inventory units at upgrade become legacy snapshots; unknown past unit changes cannot be reconstructed and must be noted in the preflight report.
5. Compute signed integer chronological prefix balances ordered by numeric header/detail ID. Every prefix must be within bounds. SQL integer window sums may be used during validated migration; overflow or invalid prefix aborts. A legacy balance requiring reconciliation is not imported as zero. Initialize projection only from validated exact final balances.
6. Seal all legacy headers, install guards/constraints/indexes, and assign missing stock public identities/version 1 while preserving existing ones. Migration does not fabricate successful mutation receipts for historical rows.
7. Verify row counts and fingerprints of preexisting columns, exact integer-to-decimal equivalence, FK/integrity checks, projection reconciliation and repeat-up no-op.

SQL-only migration runner supports this algorithm using guarded validation queries and string operations; failed preflight must raise an error before commit. The implementation task must prove the actual SQL on populated fixtures. Unexpected scientific formatting fails closed instead of being approximately converted. [SQLite datatypes](https://www.sqlite.org/datatype3.html) and [floating-point documentation](https://www.sqlite.org/floatingpoint.html) explain why DECIMAL affinity alone is insufficient.

Expand constraints without dropping domain records. If table rebuilding is required to enforce backfilled NOT NULL/CHECK constraints, preserve IDs, FK relationships, sequences and index definitions inside the migration and verify them on a populated upgrade. Do not disable FK protection casually or introduce a reader/writer compatibility window that permits legacy stock writes.

Deployment sequence: stop stock writers; take and verify a consistent snapshot; preflight; apply new migration; reconcile; deploy new writer; run staging acceptance; enable writers only after successful checks. B005 unit PATCH/minimum writers must change with the new schema so they cannot bypass unit lock or leave the integer minimum stale.

Recovery: a guarded down path may restore the prior schema only if no new stock writes have occurred and the upgrade introduced no stock identities/version records/client mappings/receipts that down would remove. A populated legacy upgrade normally assigns stock identities during backfill, so it disables down immediately even before a new write. Such upgrades use forward repair with retained schema; the guard must check actual metadata/data rather than only a timestamp. Empty-ledger rollback preserves all preexisting columns/rows and earlier identities. Down fails closed rather than erase audit/identity data. Maintenance recovery from a snapshot must account for every accepted post-snapshot operation. Removing populated companion/projection/audit metadata or resetting stock is not authorized by this refinement. Older stock writers remain disabled during recovery.

## Trade-offs and later inputs

- Uniform two-place scale preserves B005 transport but does not express arbitrary precision or count-only unit policies.
- A balance projection adds one derived table; it avoids scanning growing history and protects arithmetic bounds. Reconciliation is required during migration/deployment.
- Whole reversal plus separate replacement keeps audit mechanics narrow; a failed replacement leaves the correction partially completed and visible. Atomic replacement is a separate future requirement.
- Sealing protects historical detail insertion; it adds a lifecycle transition that must be tested together with receipt rollback.
- No lot tracking means reversing a receipt uses current available stock, not provenance of individual units.
- Later B007/B014 own corrections to automatic consumption. B009 harvest-age and B012 agronomic rules remain unresolved until their respective PRDs. B019 still awaits official revision.

## Discovery and review evidence

Coordinator and two independent sub-agents ran `npx skills use "https://github.com/vercel-labs/skills" --skill "find-skills"`, read the complete output, checked the [skills directory](https://skills.sh/), and searched SQLite/transactions or backend patterns. The generated find-skills instructions contained no supporting-files directory or relative resource references.

SQLite search results were mainly mismatched Postgres/Prisma ecosystems, so no unrelated dependency/skill was installed. The existing [nodejs-backend-patterns skill](../../.agents/skills/nodejs-backend-patterns/SKILL.md) was integrated for Fastify validation/error/transaction test boundaries; directory search reported about 46.9K installs from community source [wshobson/agents](https://github.com/wshobson/agents). GitHub page did not expose a reliable star count during this run; no new popularity-based recommendation was made. Requested graphify, caveman and backend-dev-guidelines were read; local lean-build, migration and TypeScript guidance informed scope, preservation and exact type boundaries.

Discovery output was saved in temporary files before reading. Repeating discovery is required at the start of later implementation, migration, test, and review activities. Discovery is guidance, not correctness evidence.
