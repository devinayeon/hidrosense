# B006 Stock Ledger PRD

Date: 3 October 2026, Asia/Jakarta. Baseline: HEAD `35db8c0`.
Status: refinement complete; B006 implementation authorized by the subsequent user request on 3 October 2026. Local implementation and verification are tracked in [the task plan](tasks-stock-ledger.md) and [implementation evidence](../backend-b006.md). The earlier run selected **refinement and PRD only**.

The subsequent [architecture refinement](architecture-refinement-2026-10-03.md) preserves all FR/NFR and public contracts. It consolidates private persistence prerequisites inside append and records a fresh local regression run; deployment obligations remain separate.

## Purpose and authority

Complete the PB-02 stock contract before implementation. Employees record stock receipts and usage; farmers and employees read balances and history. A committed stock movement must have one durable audit record, exact quantities, and a nonnegative resulting balance, including retries and concurrent writers.

This PRD refines [the backend plan](../rencana-backend.md), [the API contract](../backend-api.md), and R1/R2 in [the 3 October readiness report](../readiness-report-hidrosense-2026-10-03.md). Explicit user decisions control permissions and execution order. This document defines engineering choices for B006; actual implementation evidence is recorded separately. It does not claim partner acceptance or production verification.

## Baseline review: B000–B005

| Phase | Available foundation | B006 consequence |
| --- | --- | --- |
| B000 | Checksum migrations, FK enforcement, local WAL, transactional migration history, backup tooling | Add a migration; never rewrite 0001–0005. Validate legacy rows and preserve identifiers. |
| B001 | Strict validation, error envelope, limits, pagination, decimal-string transport | Reuse these boundaries and specify exact integer storage. |
| B002 | Database-backed sessions and role permissions | Recheck authentication and permission within the write transaction. |
| B003 | Atomic authenticated writes and session revocation | Reuse `authenticatedWrite`; a stale token cannot authorize a stock commit. |
| B004 | Actor-scoped receipts, canonical hashing, UUID mapping, public identity/version | Receipt, ledger, identity, version, and balance must commit together. |
| B005 | Active master references, decimal-string minimum, inventory CRUD | Freeze inventory units after first stock history; migrate minimum quantities to exact representation. |

[The B000–B005 audit](../review-backend-b000-b005.md) records remediation of F1–F6. In particular, retain signed64 ID-to-TEXT projections, lowercase client UUIDs, legacy receipt compatibility, and shared HTTP boundaries. The previously reported 85 tests are historical evidence, not tests rerun by this refinement.

Remote migrations 0001–0005 are applied according to [deployment evidence](../deployment-turso-migrations.md), with readiness 200 and 54 matching schema objects. Earlier “remote pending” wording is historical. No live database was accessed during this task. Neither legacy stock emptiness nor B006 remote readiness is inferred from the deployment result.

## Scope

Included: manual stock receipts/usage; exact balances; paginated movement history/detail; whole-movement reversal; a documented two-operation correction; stock retry semantics; immutable audit protection; migration/backfill and recovery design; future transactional consumption interface.

The authorized follow-up includes B006 runtime code, migration 0006, local tests, API documentation and graph refresh. Remote deployment and B007–B019 implementation remain excluded. B006 itself does not introduce unit conversion, lot/FIFO allocation, direct balance editing, partial reversal, notifications, stock valuation, or automatic consumption endpoints. Future consumption belongs to B007/B014; accepting a recommendation never consumes stock.

## Functional requirements and acceptance criteria

| ID | Requirement | Observable acceptance |
| --- | --- | --- |
| FR-001 | Exact quantities | Decimal strings parse without floating-point arithmetic; repeated `0.01` additions and deductions remain exact. Bounds and excess precision are rejected. |
| FR-002 | Stable units | Each submitted unit matches the item's trimmed unit exactly. History locks unit changes even at zero balance. No automatic conversion occurs. |
| FR-003 | Atomic movements | A header contains 1–100 unique item lines. All lines, balances, identity, version, and receipt commit together or all roll back. |
| FR-004 | Safe balances | Each committed item balance is within `0..9999999999.99`. Two concurrent deductions against insufficient combined stock cannot both succeed. |
| FR-005 | Immutable audit | Committed headers/details cannot be edited, deleted, or extended with additional details. Reads preserve original actor, time, direction, quantities, units, and reason. |
| FR-006 | Explicit corrections | A whole original movement can be reversed once, with mandatory reason and opposite exact lines. Insufficient current balance blocks reversal of incoming stock. Replacement is a separate explicit movement. |
| FR-007 | Durable idempotency | Client-supplied operation key is mandatory. Same actor/key/normalized request returns the saved response; changed content or operation conflicts. Response-loss retry cannot deduct twice. |
| FR-008 | Read contracts | Authorized users read item balance, movement list, and movement detail; signed64 IDs and quantity values remain strings. History includes inactive items. |
| FR-009 | Authorization | `inventaris:read` permits reads; `inventaris:write` permits manual writes/reversal. Petani has read access; pegawai has read/write access. Anonymous and revoked sessions are denied. |
| FR-010 | Compatible migration | Existing IDs, references, receipts, and public identities survive upgrade. Unsupported legacy values fail closed; no rounding, deletion, or reset occurs. |
| FR-011 | Future domain consumption | Internal writer accepts an active transaction. Sowing/care consumption has one unique domain linkage independently of actor-scoped operation keys. Generic stock routes cannot forge or reverse domain consumption. |
| FR-012 | Failure and retry contract | Contention/uncertain commit produces a retryable availability error; client preserves request and key. A failed transaction has no success receipt. Replay still checks current authentication. |

## Non-functional requirements

| ID | Requirement | Acceptance |
| --- | --- | --- |
| NFR-001 | Security | Bound SQL, strict schemas, existing HTTP protections, current database permissions, no credentials or raw SQL in responses/logs. |
| NFR-002 | Integrity/reliability | Exact integers, bounded balance projection, sealed ledger, transaction rollback, immutable receipts; reconciliation uses chronological BigInt arithmetic. |
| NFR-003 | Performance | At most 100 lines per movement and 100 records per page; balance reads use one indexed projection rather than a lifetime ledger aggregate. No external calls inside write transaction. |
| NFR-004 | Deployment/recovery | Migration is additive, validates legacy input, and commits schema/data/history atomically. Mixed old/new stock writers are prohibited. Recovery preserves ledger and identities. |
| NFR-005 | Maintainability/testability | Reuse Fastify, Zod, libSQL and existing transaction/sync boundaries. Separate transport, domain rules, and persistence without adding an ORM/framework. |
| NFR-006 | Observability | Existing structured request logs include request ID/status/duration. Expected conflicts have stable error codes. Log failure category without tokens, raw SQL, or full payloads. Record reconciliation results in deployment evidence. |

No latency SLA or remote concurrency pass is claimed. Measure staging workloads during implementation and record sample size and connection conditions.

## Decisions closing R1/R2

### DQ-01: representation, scale, bounds, and rounding

- Every inventory unit uses scale **100**: one minor unit is `0.01` of that item's recorded unit. A unit is an opaque label, not an inferred conversion rule.
- Input `jumlah` is a string matching `^\d{1,10}(\.\d{1,2})?$`, with value `0.01..9999999999.99`. JSON numbers, signs, whitespace, commas, exponent notation, and more than two fractional digits are rejected. Leading zeros are accepted within the ten-digit limit and canonicalized.
- Normalize `0010.50` to `10.5`, `1.00` to `1`, and `0.10` to `0.1`. Canonical output omits unnecessary trailing zeros.
- Parse using digit strings and `BigInt`; store `jumlah_minor INTEGER` in `1..999999999999`. Require SQLite `typeof(jumlah_minor)='integer'`, not just INTEGER affinity. Cast returned integer quantities and domain IDs to TEXT before the number-mode driver reads them.
- Balance storage `saldo_minor INTEGER` is bounded to `0..999999999999`. The maximum is a balance cap as well as a per-line cap.
- **No rounding is permitted for stock.** Reject excess precision, including `1.000`. Stock corrections do not use the future money half-up rule.
- `stok_minimum` is nullable, or a positive amount with this same scale/bound. Exact comparison uses an integer companion `stok_minimum_minor`; the existing DECIMAL column remains compatibility data only. Existing zero/negative/out-of-contract minimum values require reconciliation before upgrade.
- Ten whole digits preserve the existing B005 API range. SQLite's declared `DECIMAL(10,2)` does not enforce the conventional eight-whole-digit SQL range; this PRD explicitly selects the existing API range.

### DQ-02: units

Keep B005's trimmed, nonempty 1–30-character `satuan`. Movement lines must supply the exact stored label after trimming; comparisons are case-sensitive. `ml`, `mL`, and `liter` are different labels. No aliases or conversion factors are guessed.

All labels permit two decimal places in stock. Integer seed/plant counts in B007–B010 remain a separate domain constraint; the stock system does not infer count-only behavior from labels such as `pcs`. If a future partner requirement needs per-unit scale, refine it before a separate compatibility migration.

Snapshot `satuan` in each detail. Reject changing an item's unit after any stock detail exists, including reversed history and a current zero balance. Names may change; history identifies the item by stable ID and its original unit snapshot.

### DA-01: immutable ledger and correction

`jenis_stok` is exactly `masuk` or `keluar`. Details store positive amounts; direction determines the signed balance effect. Reject duplicate item IDs, empty details, or more than 100 details. Sort normalized lines by numeric item ID before hashing and storing.

A new header starts unsealed only within its owning transaction. Append every detail, apply balance changes, then seal before the receipt and commit. Database guards reject UPDATE/DELETE of committed headers/details and INSERT into sealed headers. The only permitted header update is its initial seal transition; no unsealed header may be committed by the application.

Reversal creates a new movement with unique nullable `reversal_of` pointing to the original header. It copies the original units/amounts, uses the opposite direction, and records the current actor/server time and a mandatory nonempty reason (maximum 1,000 characters). The original remains unchanged. Reversal of a reversal and a second reversal are rejected. Reversal may use inactive inventory because it corrects history; it must still satisfy balance bounds. No lot attribution exists: reversing an incoming entry requires current available balance at least equal to its quantity for every line.

Correction is **two independently committed operations**: reverse the entire mistaken manual movement, then record a replacement with a new key/client identity and a nonempty explanation referencing the original. The replacement explanation and original ID reference are a client workflow obligation carried in free-text `keterangan`; the server cannot identify correction intent from the generic create schema and does not enforce or promise a structured replacement relationship. The reversal relationship itself is enforced by `reversal_of`. If replacement fails, the reversal remains committed and visible; no automatic restoration is promised. Partial reversal and an atomic replacement endpoint are outside B006. A client must replay the reversal with its original key after response loss before submitting replacement.

Headers linked to `id_penyemaian` or `id_perawatan` cannot be reversed through the generic stock endpoint. Their future owning feature must correct domain state and ledger together. Generic request schemas reject both linkage fields. Each non-null linkage is unique, mutually exclusive with the other, and only valid on an outgoing, non-reversal consumption header. Reversal headers have null domain links and identify the original through `reversal_of`; domain correction must also preserve the owning record's invariants.

### DI-01: operation identity and retry

All stock POST routes require `Idempotency-Key` as a UUID string. Preserve B004's exact-text key semantics, including casing. Never generate a fallback key. Use the same actor/key namespace as existing receipts across all operation types; `stok.create` and `stok.reverse` cannot reuse one key for different operations.

Optional `X-Client-Id` is a UUID normalized lowercase and included in operation identity; resource type is `stok`. It identifies the new header on both create and reversal, never the original. A previous `sync.reserve-id` mapping can be bound to the movement. A different operation key with an already-bound client UUID returns `RESOURCE_ALREADY_EXISTS`; a different actor's mapping remains separate.

Hash normalized business payload, operation type, and optional client identity. Normalize decimal strings, trimmed labels/reasons, numeric detail ordering, optional absent reason to null, and reversal target ID. Do not include generated time, generated domain IDs, or current balance in the request hash. Time is assigned once by the server and saved in the response. Clients must persist the key and payload before first send and preserve both until reconciliation completes.

After current authentication, check the saved receipt **before** checking current item activity, balances, or reversal state. Matching receipt returns its original data/operation with `replayed:true`; it does not rerun effects or resource version increments. A revoked session cannot replay. Failed writes do not reserve a successful outcome. Stock availability errors must not cause the client to invent another operation key.

### DB-01: atomic verification

Use `authenticatedWrite` with `db.transaction('write')`, followed by current session/permission verification. The installed libSQL 0.18.0 maps write mode to `BEGIN IMMEDIATE` for local and Hrana transactions. Reuse the sync mutation wrapper for lookup/hash/receipt/identity/version.

Use a bounded integer balance projection maintained in the **same transaction** as ledger append. For each numeric-ID-sorted item, initialize missing projection at zero, apply a conditional signed integer update within bounds, and require one affected row. Append details and seal only if all updates succeed. Any validation, receipt, mapping, detail, seal, or commit failure rolls back the full transaction unless commit outcome is uncertain; uncertain outcomes are resolved through receipt replay.

No check outside the transaction, process-local mutex, or JavaScript floating-point balance is authoritative. See [architecture](architecture-stock-ledger.md) for exact responsibilities and migration strategy.

## HTTP acceptance contract

These routes are **planned**, not registered today. Reuse the existing error envelope, Bearer token and HTTP protections. Stock writes return 201 on first commit and 200 on replay.

| Route | Request | Response / purpose |
| --- | --- | --- |
| `POST /api/v1/stok` | Required idempotency key; optional client UUID; strict body below | Immutable movement, operation receipt, replay indicator; `Location: /api/v1/stok/{id_stok}` |
| `POST /api/v1/stok/:id/reverse` | Same headers; strict `{ "keterangan": "reason" }`; signed64 original ID | Newly appended reversal with its own ID/UUID, not an edited original |
| `GET /api/v1/stok/:id` | Signed64 ID; no query fields | Original immutable header/details, identity/version; 404 if absent |
| `GET /api/v1/stok` | `page` default 1, `limit` default 20/max100; optional `id_inventaris`, `jenis_stok` | History including reversals, ascending numeric header ID; `meta` includes total/total_pages |
| `GET /api/v1/inventaris/:id/saldo` | Signed64 item ID; no query fields | ID, current unit, exact saldo, minimum, `di_bawah_minimum`; inactive items readable |

Body for create has exactly `jenis_stok`, `details`, and optional `keterangan` (null or trimmed nonempty string, max1,000). Each line has exactly `id_inventaris`, `jumlah`, `satuan`. No client actor/time/balance/domain links or unknown fields are accepted. Domain IDs are strings `1..9223372036854775807` without leading zeros. Pagination follows existing positive-string query rules; filters are strict enums/IDs. Reversal body requires its non-null reason.

Detail reads return `{ data: Movement }`, where Movement has exactly the fields illustrated below; immutable details are sorted by numeric item ID. History returns `{ data: Movement[], meta: { page, limit, total, total_pages } }`, with metadata as JSON integers. The `id_inventaris` filter selects distinct headers containing that item and returns every detail of each selected movement, not only matching lines. Direction filter applies to the header; both filters combine with AND. Count `total` over distinct matching headers, before pagination; `total_pages` is `ceil(total/limit)` and is zero for an empty result. Out-of-range pages return an empty array. Reads include linked consumption and reversal headers; all IDs/linkages use string-or-null types as shown.

```json
{
  "jenis_stok": "masuk",
  "details": [{ "id_inventaris": "12", "jumlah": "10.50", "satuan": "ml" }],
  "keterangan": "Receipt from supplier"
}
```

Example first-commit response (illustrative IDs):

```json
{
  "data": {
    "id_stok": "21",
    "public_id": "cc06496f-22ba-4ad9-b795-147bff7871f3",
    "version": "1",
    "id_user": "2",
    "id_penyemaian": null,
    "id_perawatan": null,
    "tanggal_stok": "2026-10-03T03:00:00.000Z",
    "jenis_stok": "masuk",
    "keterangan": "Receipt from supplier",
    "reversal_of": null,
    "details": [{ "id_detail_stok": "31", "id_inventaris": "12", "jumlah": "10.5", "satuan": "ml" }]
  },
  "operation": {
    "operation_key": "5f9c14e6-76bc-4f68-a3cf-8e4fd877d744",
    "revision": "30",
    "public_id": "cc06496f-22ba-4ad9-b795-147bff7871f3",
    "version": "1"
  },
  "replayed": false
}
```

Movement version remains 1 because the header is immutable. Reversals have a separate identity/version/receipt and appear in history with `reversal_of`; the original is not assigned a mutable reversed status. Original replay remains its saved snapshot. Balance is read separately rather than added to an immutable movement response.

Balance response is `{ "data": { "id_inventaris":"12", "satuan":"ml", "saldo":"10.5", "stok_minimum":"2", "di_bawah_minimum":false } }`. Missing balance projection for an existing item means zero. Null minimum gives `di_bawah_minimum:false`; otherwise compare strictly `saldo < minimum`. No projection is created by a read.

| Status | Stable code | Rule |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Invalid/missing headers, fields, amounts, IDs, line cardinality or duplicates |
| 401 / 403 | Existing auth codes / `FORBIDDEN` | Current token/session/permission required |
| 404 | `STOK_NOT_FOUND` / `INVENTARIS_NOT_FOUND` | Requested movement or balance item absent |
| 422 | `INVENTARIS_NOT_AVAILABLE` / `UNIT_MISMATCH` | Manual create references missing/inactive item or mismatched unit |
| 409 | `INSUFFICIENT_STOCK` / `STOCK_LIMIT_EXCEEDED` | Candidate balance below zero / above maximum |
| 409 | `OPERATION_CONFLICT` / `RESOURCE_ALREADY_EXISTS` / existing UUID conflict code | Existing key changed or client identity already bound/ambiguous |
| 409 | `STOK_ALREADY_REVERSED` / `REVERSAL_NOT_ALLOWED` | Duplicate reversal, reversal-of-reversal, or generic reversal of domain consumption |
| 409 | `UNIT_LOCKED` | B005 unit PATCH attempts to change a historically used unit |
| 503 | `STOCK_WRITE_UNAVAILABLE` | Classified lock contention, transaction unavailable, or uncertain remote commit; `Retry-After: 1`, same key/payload |
| 500 | `INTERNAL_ERROR` | Other unexpected errors; no details leaked, same-key retry remains safe |

Existing 413/415/426/429 policy errors also apply. Do not convert arbitrary programming or constraint errors into 503; explicitly classify supported driver error cases during implementation. An uncertain outcome message must tell the client to retry the same operation, not state that no commit occurred.

## Risk mitigations and verification handoff

| Risk | Decision / required proof |
| --- | --- |
| R1 negative/double stock | DI-01/DB-01; independent-client contention, same-key concurrent replay, response-loss and rollback tests |
| R2 precision/drift | DQ-01; exact parsing/storage, repeated fractions, maximum values, legacy conversion rejection |
| R3 unit changes / stale writes | DQ-02; database unit lock persists after reversal; movements append rather than overwrite |
| R8 future duplicate consumption | DA-01/FR-011; unique domain origin plus same-transaction domain writes |
| R11 identity loss on rollback | FR-010/NFR-004; identity-preserving recovery, no live down migration as troubleshooting |
| R12 remote contention/timeouts | FR-012/NFR-003; bounded transaction, classified retry, staging two-client tests before deployment |

Implementation tasks and test cases are in [the task plan](tasks-stock-ledger.md). Design closure of R1/R2 does not substitute for those proofs.

## Sequential follow-up

B006 refinement → B006 implementation/proof → B007 seeding → B008–B010 tables/batches/damage → B011 detections → B012–B014 rules/decisions/actions → B015–B016 harvest/sales → B017 full sync → B018 non-weather package → B019 only after official BMKG revision.

Draft each later phase's PRD before code. Do not consider the B006 contract a decision on the B009 harvest-age discrepancy or B012 agronomy. Both remain later-phase inputs. BMKG stays last and on hold.
