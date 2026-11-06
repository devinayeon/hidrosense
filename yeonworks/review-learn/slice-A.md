# Slice A report: shared core

Scope read in full: `src/app.ts`, `src/server.ts`, `src/serverless.ts`, `src/config.ts`, all 14 files of `src/common/`. Followed into `features/auth/*`, `features/sync/*`, every `features/*/write.ts`, `features/accounts/{profile,store,contracts}.ts`, `features/stock/{service,store,errors}.ts`, `db/{client,migrate}.ts`, migrations 0001, 0002, 0003, 0005, 0014, 0015, and the installed Fastify 5.12.5 and libsql 0.18.0 sources where behaviour depended on them.

All proof scripts are in `...\scratchpad\learn\a\` (urls.mjs, abs.mjs, abs2.mjs, ip.mjs, plan.mjs, plan2.mjs, feed.mjs, noop.mjs, slide.mjs, errs.mjs). Run with `node --import tsx <script>` from `apps/backend`. They use `:memory:` databases or a temp file under the OS temp dir. Nothing under `data/` was touched.

---

### A1 [LOGIC] An absolute-form request target skips both the IP quota and the HTTPS check
- Severity: high
- Status: VERIFIED
- Where: `src/app.ts:80-86` (`requestPath`, `path.startsWith('/api/')`, lines 29-35)
- What: The `onRequest` hook decides "is this an API request" from `request.url.split('?')[0]`. Node leaves `req.url` as `http://host/api/v1/...` when a client sends an absolute-form request line (`GET http://x/api/v1/auth/me HTTP/1.1`, legal HTTP/1.1). That string does not start with `/api/`, so the 426 check and `consumeLimit(... 'ip:...', 120, 60000 ...)` are skipped. Fastify's router still resolves the request to the real `/api/v1/...` route, so the handler runs normally.
- Trace or proof: `abs.mjs` (raw socket, 122 requests per variant). Normal target: 120x 401 then 429. Absolute-form target (with and without a query string): 122x 401, zero 429, zero `auth_rate_limits` rows from it. `abs2.mjs` with `NODE_ENV=production` and no proxy trust: normal target gives `426 Upgrade Required`, absolute-form gives `401 Unauthorized`.
- Failing input: `GET http://x/api/v1/auth/me HTTP/1.1`.
- Effect: the 120/min request-IP quota is void for any client willing to send that form. `login` keeps its own per-IP-and-username bucket, so password guessing is still capped per username and address (see A3). Production HTTPS enforcement is bypassable the same way. Edge proxies normally rewrite the target, so real-world exposure depends on the platform, but the app does not enforce its own rule.
- Suggested fix: decide "is API" from the matched route (`request.routeOptions.url`) or from `new URL(request.url, 'http://x').pathname`, and do it once for both checks.

### A2 [LOGIC] Every write scans all of the user's receipts: the 0014 index is not used for lookup
- Severity: medium
- Status: VERIFIED
- Where: `src/common/sync.ts:41-48` (receipt lookup), `src/common/sync.ts:32-36` (client-id mapping lookup), `migrations/0014_operation_key_lower.up.sql`
- What: The lookup is `WHERE id_user=? AND (operation_key=? OR lower(operation_key)=?) ORDER BY (operation_key=?) DESC, id_change DESC LIMIT 1`. SQLite uses `idx_sync_operations_key_lower` with only the `id_user=?` prefix, then sorts in a temp B-tree. So each write reads every receipt that user ever made. The `lower(client_id)=?` mapping lookup likewise uses only the `(id_user, resource_type)` prefix.
- Trace or proof: `plan.mjs` `EXPLAIN QUERY PLAN` prints `SEARCH sync_operations USING INDEX idx_sync_operations_key_lower (id_user=?) || USE TEMP B-TREE FOR ORDER BY`. `plan2.mjs` with 200,000 receipts for one user: the current query takes 341.9 ms per call; the same lookup by exact key only takes 0.148 ms, by `lower()` only 0.140 ms. The mapping query over 20,000 rows takes 15.7 ms. On Turso this is also a row-read bill of N per write.
- Failing input: any write by a user with many stored receipts (a petani does every write; receipts are never deleted, see A6).
- Suggested fix: look up `operation_key=?` first (indexed point lookup), and only if it misses run the `lower()` fallback, or drop the fallback once no mixed-case rows exist (A14). Same for the mapping query.

### A3 [LOGIC] IPv6 address rotation defeats both the login limiter and the IP quota
- Severity: medium
- Status: VERIFIED
- Where: `src/app.ts:85` (`ip:${request.ip}`), `src/features/auth/login.ts:18` (`login:${request.ip}:${username}`), `src/common/rate-limit.ts:13`
- What: Buckets are keyed on the full textual address. A client with one IPv6 /64 owns 2^64 distinct keys, so it never reaches the 10 per 15 min login cap or the 120/min quota.
- Trace or proof: `ip.mjs` with `TRUST_PROXY_HOPS=1`: 30 wrong-password logins for `petani` with `X-Forwarded-For: 2001:db8::0 ... ::1d` all return 401. 30 logins from one v6 address give 10x 401 then 20x 429. The comment at `login.ts:15-17` accepts distributed guessing only "bounded by the 120/minute IP quota"; rotation removes that bound too. The remaining brake is scrypt cost (about 150 ms of threadpool time per attempt).
- Failing input: sequential logins with a different source address inside one /64.
- Suggested fix: key IPv6 by its /64 (mask the address) before hashing.

### A4 [DUP] `expected_version` is implemented twice, and the copies disagree
- Severity: medium
- Status: VERIFIED (static; literals quoted)
- Where: core: `src/common/sync.ts:146-154,162` + `src/common/validation.ts:9` (`expectedVersionSchema = integerIdSchema.optional()`). Copies: `src/features/harvest/service.ts:33` and `src/features/sales/service.ts:112-113`, schemas at `src/features/harvest/contracts.ts:18` and `src/features/sales/contracts.ts:40`.
- What: Harvest and sales do not pass `expectedVersion` to `executeDomainMutation`; they compare `existing.version` themselves. Drift: (1) required in harvest and sales, optional everywhere else; (2) error code `HARVEST_VERSION_CONFLICT` / `SALE_VERSION_CONFLICT` versus `VERSION_CONFLICT` for the other six resources, so a client needs per-resource handling; (3) the core check runs before the effect and treats a row with no identity as a conflict (`sync.ts:162`), the copies run inside the effect and handle null differently (sales: `existing.version == null ||`; harvest: relies on `null !== string`).
- Failing input: `PATCH /api/v1/panen/:id` without `expected_version` is a 400, while `PATCH /api/v1/penyemaian/:id` without it is last-write-wins.
- Suggested fix: pass `expectedVersion` through `executeDomainMutation` for harvest and sales and keep one error code; decide deliberately whether it is required.

### A5 [RISK] Refresh rotation has no grace: a lost response forces a full re-login
- Severity: medium
- Status: SUSPECTED
- Where: `src/features/auth/refresh.ts:15-28`
- What: One conditional UPDATE swaps both token hashes. If the response never reaches the phone (flaky farm network), the stored refresh hash is already new and the client's copy is dead: the retry gets 401 `UNAUTHENTICATED`. There is no previous-hash window and no reuse signal. An offline-first client then needs the password to continue.
- Trace or proof: by reading the SQL. `slide.mjs` confirms that a second use of a consumed refresh token is rejected (single-use is intended; test `session-sliding`).
- Suggested fix: keep the previous refresh hash valid for a short window (e.g. 60 s) and return the same new pair, or make refresh idempotent per refresh token.

### A6 [RISK] Receipts and the change log grow forever, and the cursor protocol cannot survive pruning
- Severity: medium
- Status: VERIFIED (growth by code; cost by measurement)
- Where: `src/common/maintenance.ts` (purges only `auth_sessions` and `auth_rate_limits`), `src/common/sync.ts:80-91` (full response stored per write), `src/features/sync/changes.ts:36-53`
- What: `sync_operations.result_json` (a full copy of every response) and `sync_changes` are never deleted. The feed query computes `MAX(id_change) ... GROUP BY` over every row after the cursor before applying `LIMIT`. Separately, the only reset signal is `cursor > latest` (`changes.ts:36`); there is no "cursor older than the oldest retained row" check, so adding pruning later silently makes clients skip changes.
- Trace or proof: `feed.mjs`, 100,000 change rows over 2,000 records: one page costs 170.8 ms at cursor 0, 83.9 ms at 50,000, 4.6 ms at 99,000. A full resync is about 10 pages (limit 200) at that cost each.
- Suggested fix: add retention for both tables together with an "oldest cursor" reset check, and an index/limit strategy for the grouped feed query.

### A7 [LOGIC] A PATCH that changes nothing still bumps the version and emits a change, causing false conflicts
- Severity: low
- Status: VERIFIED
- Where: `src/common/sync.ts:168` (`nextResourceVersion` always runs), `src/features/inventory/inventaris.ts:57-58,75`
- What: `executeDomainMutation` bumps the version after any successful effect, including one that returns the current row without writing. In `inventaris` PATCH, `{satuan:'KG'}` on a row with `satuan:'kg'` is treated as "unit unchanged" and returns early.
- Trace or proof: `noop.mjs`: create gives version 1; PATCH `satuan:'KG'` with `expected_version:1` returns `satuan:'kg'`, version 2, and adds a second `inventaris` row to `sync_changes`. A second editor holding version 1 then gets `409 VERSION_CONFLICT`.
- Suggested fix: let the effect report "no change" and skip the bump, or compare row state before and after.

### A8 [LOGIC] Transient database errors are retryable only for stock writes
- Severity: low
- Status: SUSPECTED
- Where: `src/features/stock/write.ts:25-29` + `src/features/stock/errors.ts`, versus `src/common/authenticated-write.ts` and the other nine `write.ts` wrappers
- What: Only `stockWrite` maps `SQLITE_BUSY`, `STREAM_EXPIRED`, `ECONNRESET`, etc. to `503 STOCK_WRITE_UNAVAILABLE` with `Retry-After`. The same errors in inventory, nursery, tables, transfers, damage, harvest, sales, sync operations and accounts surface as `500 INTERNAL_ERROR`. `common/errors.ts:25` hard-codes the stock code to attach `Retry-After`.
- Trace or proof: by reading; no other file imports `stockUnavailable`.
- Suggested fix: classify transient errors once in `authenticatedWrite` (or `sendError`) and drop the feature-specific code from `errors.ts`.

### A9 [RISK] 500 responses leave no diagnostic trail
- Severity: low
- Status: SUSPECTED
- Where: `src/common/errors.ts:22-23`, `src/server.ts:27-31`, `src/serverless.ts:51-55`, `src/app.ts:107-109`
- What: Every 5xx logs only `{code:'INTERNAL_ERROR', requestId}`. No error name, no libsql `code`, no route. The readiness handler also swallows the cause (checksum mismatch vs pending migration vs unreachable DB all become `NOT_READY`). Startup failure in `server.ts` prints a fixed sentence even for `EADDRINUSE`. Redaction is sound but leaves nothing to debug with.
- Suggested fix: log `error.name` and `error.code` (both safe), plus the route, and log the readiness failure class.

### A10 [RISK] Hop-count trust makes `X-Forwarded-Proto/For` forgeable if the process is reachable directly; `server.ts` does not enforce proxy settings in production
- Severity: low
- Status: VERIFIED (behaviour); exposure is deployment dependent
- Where: `src/app.ts:38-41`, `src/server.ts` (no production check), `src/serverless.ts:22-24` (has the check)
- What: With `TRUST_PROXY_HOPS` the function is `hop < proxyHops`, so hop 0 (the TCP peer) is always trusted. Fastify then honours `X-Forwarded-Proto` and the last `X-Forwarded-For` entry from any peer. `server.ts` (direct `listen`) accepts `NODE_ENV=production` with neither `TRUST_PROXY_HOPS` nor `TRUSTED_PROXIES`: every `/api` request is then refused with 426 and there is no TLS option, which is only discoverable at runtime.
- Trace or proof: `ip.mjs`: `NODE_ENV=production`, hops=1: a plain request gives 426; adding `X-Forwarded-Proto: https` gives 401. With `TRUST_PROXY_HOPS=2` and one real proxy, the first XFF entry (client-controlled) becomes the rate-limit key.
- Suggested fix: move the production proxy check into `readConfig`/`buildApp` so both entry points share it; document that hop mode requires the app to be unreachable except through the proxy.

### A11 [RISK] `/health/ready` is public, unthrottled, and costs three database round trips per call
- Severity: low
- Status: VERIFIED (no quota row is created; query count by reading)
- Where: `src/app.ts:101-110`, `src/db/migrate.ts:43-47,56-60`
- What: Health paths are outside `/api/`, so `consumeLimit` is skipped. Each call runs the `sqlite_master` probe, the `_schema_migrations` read, and `SELECT id_session ... LIMIT 0` (the last is implied by the first two). Against Turso that is billable load an anonymous client controls. Readiness is not cached; only the file list is.
- Suggested fix: cache the ready result for a few seconds, drop the third query.

### A12 [DUP] Three scale-100 decimal parsers, two identical formatters, and range checks that cannot fire
- Severity: low
- Status: VERIFIED (arithmetic checked in `re.mjs`/node)
- Where: `src/common/quantities.ts:3-13`, `src/common/weights.ts:1-11`, `src/common/money.ts:1-12`, formatters `weights.ts:13-15` and `money.ts:14-16`
- What: The same "digits.fraction to BigInt x100" algorithm exists three times with different limits: quantities `\d{1,10}`, money `[0-9]{1,10}`, weights `[0-9]{1,8}`. In each, the regex already caps the value at the very constant the next line checks: `9999999999.99` gives `999999999999 = MAX_QUANTITY_MINOR = MAX_SALE_PRICE_MINOR`; `99999999.99` gives `9999999999 = MAX_WEIGHT_MINOR`. So the `if (minor > MAX)` throws in all three parsers are unreachable. `MAX_SALE_WEIGHT_MINOR` (`money.ts:1`, duplicate of `weights.ts` `MAX_WEIGHT_MINOR`) and `MAX_SALE_PRICE_MINOR` are exported but imported nowhere. `formatMoney` and `formatWeight` are byte-identical. They have drifted in three visible ways: error class (`RangeError` vs plain `Error`), accepted input type (`string` vs `unknown`), and rendering (`fromMinor` trims trailing zeros, `5.5`; `formatWeight`/`formatMoney` pad, `5.50`), so the API prints the same scale in two styles.
- Suggested fix: one `parseScaled(value, {maxWholeDigits})` and one formatter; delete the dead range checks and unused constants.

### A13 [DEAD] Confirmed unreachable or unused items
- Severity: low
- Status: VERIFIED (grep over `src`, `test`, `scripts`)
- Where and proof:
  - `src/app.ts:62` `ajv: {...}` and `src/common/errors.ts:15-16` `else if (error.validation)`: no route in `src/` declares a `schema` option, so Fastify never produces `error.validation`. The branch and the option are dead; validation is all Zod via `parseInput`.
  - `src/app.ts:32-34` catch in `requestPath`: Fastify's router rejects malformed percent escapes first (`/api/%zz` returns 400 from `frameworkErrors`). The catch fires only for the `;` quirk (`/api/v1/auth/me;%zz` gives 400 instead of 401/404, `ip.mjs`).
  - `src/common/permissions.ts`: `deteksi:read/write`, `rekomendasi:read/decide`, `perawatan:read/write`, `cuaca:read` are checked by no route (grep: only the definition). They are still sent to every petani in `permissions` on login and `/auth/me`. `rolePermissions` is exported but only used inside the file.
  - `src/common/validation.ts` and `quantities.ts`: `(?![\s\S])` after `$` is redundant in JavaScript. `re.mjs`: `/^a$/.test('a\n')` is already `false`.
  - `src/common/authorization.ts:10` default `clock = Date.now`: all 40+ callers pass `clock`.
  - `src/app.ts:53` pino `redact` paths: nothing logs request headers or bodies (`disableRequestLogging: true`, custom `onResponse` logs method/route/status only).
- Suggested fix: delete the dead config and branch; drop the unbuilt permission strings until the features exist.

### A14 [DEAD] Legacy-compat paths in `executeOperation` have no sunset and pay for it on every write
- Severity: low
- Status: SUSPECTED (cannot see whether any production database still holds mixed-case keys or pre-identity hashes)
- Where: `src/common/sync.ts:27-31,32-36,41-48,51-62`
- What: `legacyHash`, `legacyIdentityMatches`, `priorCasingMatches`, the `lower(operation_key)` / `lower(client_id)` lookups exist only to replay receipts written before key canonicalisation and before `client_id`/`resource_type` entered the hash. On any database created after those changes they can never match. They cause the scans in A2 and are the most intricate code in the file. No test or comment states when they may go.
- Suggested fix: confirm with a one-off `SELECT count(*) WHERE operation_key<>lower(operation_key)` on the live DB; if zero, delete the compat code and use plain indexed equality.

### A15 [RISK] Sessions are bound to the whole `users.password` string, and the role list is hard-coded in three places
- Severity: low
- Status: SUSPECTED
- Where: `src/common/sessions.ts:31` (`s.credential_hash=u.password`), `:57-59`, `src/features/auth/refresh.ts:20-22`, `src/common/permissions.ts`
- What: Binding is correct and closes the scrypt TOCTOU (good). But any future rewrite of `users.password` that keeps the same password (the missing rehash path from the known list) silently signs out every device. Separately, the role set lives as the literal `IN ('petani','pegawai')` in two SQL statements plus `permissions.ts`; `authenticate` uses `permissionsFor(...)`, create/refresh use the literal. Adding a role needs three edits and drifts silently.
- Suggested fix: bind to a dedicated `credential_version` or only compare on explicit password change; derive the SQL role list from `rolePermissions`.

### A16 [RISK] Silent fallbacks in the sync core
- Severity: low
- Status: SUSPECTED
- Where: `src/common/sync.ts:156` (`String(data[mutation.idField])`), `src/common/sync.ts:15-21,85-89`, `src/features/nursery/write.ts` and `src/features/stock/write.ts` (payload passed as is), versus the other wrappers (`JSON.parse(JSON.stringify(...))`)
- What: A wrong `idField` yields the string `'undefined'` as `domain_id` and a link row for it, with no error. `canonicalJson` renders an object key holding `undefined` as `"k":undefined` (invalid JSON, different hash from the key being absent). Today Zod 4 omits absent optional keys, so it cannot trigger; but inventory/damage/harvest/sales/tables/transfers normalise through a JSON round trip while nursery and stock do not.
- Suggested fix: throw if `data[idField]` is null; normalise inside `hashPayload` instead of in each wrapper.

### A17 [RISK] Startup purge can abort boot, while the same purge in login is deliberately non-fatal
- Severity: low
- Status: SUSPECTED
- Where: `src/server.ts:14` versus `src/common/maintenance.ts:16-23`
- What: `sweepExpiredAuthRecords` swallows errors because "cleanup must never cost a user their sign-in". `server.ts` calls the throwing `purgeExpiredAuthRecords` inside the startup `try`, so a locked or briefly unreachable database during cleanup stops the server from starting.
- Suggested fix: use the sweeping variant at startup.

---

## Checked and fine
- Sliding session SQL (`refresh.ts`): ran `slide.mjs` across 6/12/18/24 day refreshes, then at cap-1s and cap. `refresh_expires_at` is `min(now+7d, created+30d)`, access expiry clamps to the cap, the table CHECKs (`access>created`, `refresh>=access`) never trip, and refresh and `/auth/me` both return 401 exactly at created+30d. A used refresh token is single-use.
- Credential binding: `createSession` re-checks id, username, hash, active flag and role in the INSERT, so a password change during scrypt fails with 401; `authenticate` and refresh both require `credential_hash=u.password`; profile and employee updates delete sessions on password or username change.
- `authenticatedWrite` re-authenticates and checks permission inside the same write transaction; rollback failures cannot mask the primary error; `tx.close()` always runs. Replay happens after the permission check, so a demoted user cannot replay.
- Idempotency: key and client id are lower-cased at the boundary; the payload hash covers type, payload, resource type and client id; stock lines are sorted so line order does not change the hash; all wrappers except accounts put the target id in the payload (PATCH ids, reverse ids), so one key cannot replay onto a different resource; a rolled-back effect rolls back its receipt and client-id mapping; receipt row is written before the effect result and updated in the same transaction. Version check runs before the effect and a replay skips it, so a retry after a lost response is not a false conflict.
- Triggers on `sync_resource_versions` always find the link row because every caller inserts the link first (`executeDomainMutation`, `initializeStockIdentity`, migration 0005 backfill order).
- Change feed: grouped query returns each record at its newest change; a record changed between pages reappears; `has_more`, `next_cursor`, empty page, 19-digit cursor regex versus the `BigInt` reset check, and the permission filter (unlisted types hidden by default; every type written by code appears in `readPermissions`) all behave correctly. SQLite bare-column `changed_at` correctly follows `MAX(id_change)`.
- Rate limiter SQL: single atomic upsert; window reset and increment read the old row; `hits` check is `> max`; `Retry-After` is computed from the stored reset time.
- Login: unknown, malformed-hash and inactive users all pay one scrypt derivation and return the same 401 body; `timingSafeEqual` lengths always match (regex forces 128 hex).
- Error surface: ran `errs.mjs` over bad percent escape, bad JSON, empty JSON, text/plain, 413, HEAD, OPTIONS (allowed and disallowed origin), unknown method, trailing slash, bad bearer. Every case returns the JSON envelope with `request_id`, no SQL, stack or input echo; 401 carries `WWW-Authenticate`; 413/415 codes map correctly.
- OPTIONS: hook order is cors, then the app hook (Fastify wraps `addHook` in `after`), so CORS headers exist before the 400/204 decision; missing `Origin` or `Access-Control-Request-Method` gives 400; with no configured origins a valid preflight falls to 404.
- `trustedProxy`/config: `TRUST_PROXY_HOPS` and `TRUSTED_PROXIES` are mutually exclusive, CIDR and origin validation reject trailing slash, default port and malformed prefix; `fail closed` numeric trust is avoided by using a function.
- Body limit 16 KB versus schema maxima: worst valid stock (100 lines, 19-digit ids, 30-char units) is about 12.5 KB and harvest about 12.5 KB, so no valid payload is refused.
- Local file mode with libsql `concurrency: 1`: 12 concurrent writes plus 12 concurrent reads against a file DB all succeeded (`conc.mjs`), so the single-connection transaction hold did not surface as `TRANSACTION_ACTIVE` in practice.
- `jakartaDate` (+7 h fixed offset) is correct for WIB (no DST). Integer ids are `AUTOINCREMENT`, so `sync_resource_links` cannot be re-attached to a reused id; `CAST(... AS TEXT)` keeps 64-bit ids exact.
- `serverless.ts`: failed open resets the cached promise so the next request retries; production refuses a non-remote `DATABASE_URL` and missing proxy trust; the handler waits for response close.

## Counts
By category: LOGIC 5 (A1, A2, A3, A7, A8), RISK 8 (A5, A6, A9, A10, A11, A15, A16, A17), DUP 2 (A4, A12), DEAD 2 (A13, A14), SMELL 0. Total 17.
By severity: high 1, medium 5 (A2, A3, A4, A5, A6), low 11. VERIFIED 10 (A1, A2, A3, A4, A6, A7, A10, A11, A12, A13), SUSPECTED 7 (A5, A8, A9, A14, A15, A16, A17).
