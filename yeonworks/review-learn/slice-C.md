# Slice C report: auth, accounts, inventory

Scope read in full: `src/features/auth/*` (8 files), `src/features/accounts/*` (9), `src/features/inventory/*` (7). Also read, because the slice calls into them: `common/sessions.ts`, `authorization.ts`, `authenticated-write.ts`, `passwords.ts`, `permissions.ts`, `validation.ts`, `quantities.ts`, `rate-limit.ts`, `maintenance.ts`, `sync.ts`, `errors.ts`, `features/stock/store.ts` (item availability), and migrations 0001, 0002, 0004, 0005, 0006.

Proof scripts (in-memory DB, `app.inject`): `...\scratchpad\learn\c\probe.mjs` and `probe2.mjs`. Run from `apps/backend` with `node --import tsx <script>`.

Overall: the auth and session code is solid. Every path that changes a credential, username or status revokes sessions, and a second line of defence (`credential_hash`, `status_aktif` in `authenticate`) covers what the revocation misses. The real problems are in the inventory CRUD: a no-op PATCH bumps the version, a case-only unit change is silently dropped, and there is no way to reactivate anything. Account search has a LIKE wildcard bug.

---

### C1 [LOGIC] Inventory deactivation is irreversible and can strand stock
- Severity: medium
- Status: VERIFIED
- Where: `src/features/inventory/inventaris.ts:82-89`, `jenis-inventaris.ts:55-62`, `obat.ts:61-68`; `src/features/stock/store.ts:83`
- What: The three inventory resources have a `deactivate` route and no `activate` route. Employees have both. `POST /inventaris/:id/deactivate` does not look at stock balance. After it, any non-reversal stock movement for the item fails with `422 INVENTARIS_NOT_AVAILABLE`, including `keluar` (consumption). Saldo left on the item can only be touched by reversing an old receipt.
- Trace or proof: `probe2.mjs`: item A gets `masuk 5`, then `/deactivate` returns 200, then `keluar 1` returns `422 INVENTARIS_NOT_AVAILABLE`, and saldo stays `5`. `POST /jenis-inventaris/:id/activate` returns 404 NOT_FOUND (`probe.mjs`). API.md lists no activate route for inventory either.
- Failing input: any item with saldo > 0, then deactivate. A mis-tap on the mobile client is unrecoverable through the API.
- Suggested fix: add `activate` for the three resources, and either refuse to deactivate an item with saldo > 0 or document that stock is stranded.

### C2 [LOGIC] PATCH `/inventaris/:id` silently drops a case-only `satuan` change, even when there is no stock history
- Severity: low
- Status: VERIFIED
- Where: `src/features/inventory/inventaris.ts:56-58` and `:68`
- What: `unitChanged` compares with `trim().toLowerCase()`, and `satuan` is skipped when `!unitChanged`. A correction from `kg` to `Kg` returns 200 and does nothing. This was deliberate for items with stock history (test `stock.test.js:170-185`), but the same code also swallows the edit for an item with no history, where nothing is locked (the DB trigger `b006_inventory_unit` only blocks changes on items with `detail_stok`). The `.trim()` in `normalizeUnit` is dead: Zod already trims the input, and the stored value is trimmed by the migration guard and by Zod on create.
- Trace or proof: `probe.mjs`: PATCH `{satuan:'Kg'}` on a fresh item returned 200, `satuan` still `kg`, `version` went 1 to 2.
- Failing input: `{"satuan":"Kg"}` on an item with no detail_stok rows.
- Suggested fix: when there is no history, write the new `satuan`; or return the same 200 but do not claim a change (see C3).

### C3 [LOGIC] A PATCH that changes nothing still bumps the resource version and writes a receipt
- Severity: medium
- Status: VERIFIED
- Where: `src/features/inventory/inventaris.ts:75` (`if (assignments.length === 0) return current;`), `src/common/sync.ts:155-168` (`executeDomainMutation` always calls `nextResourceVersion` after `effect`); also `jenis-inventaris.ts:44-53` (always writes), `obat.ts:48-58`
- What: The early return in the inventaris PATCH avoids the UPDATE, but the wrapper still increments the version after the effect, and the same happens when a PATCH writes identical values. Every other client holding `expected_version` then gets a spurious `409 VERSION_CONFLICT`. The `return current` early exit looks like intent to be a no-op and is not one.
- Trace or proof: `probe.mjs`: `{satuan:'Kg'}` (ignored) took version 1 to 2; `{nama_barang:'Rockwool'}` (same value) took 2 to 3. Same for `POST .../deactivate` called twice: versions 9 then 10 on an already inactive item.
- Failing input: PATCH with the current values, or deactivate twice.
- Suggested fix: let `effect` signal "unchanged" so `executeDomainMutation` skips `nextResourceVersion`; at minimum short-circuit when nothing differs.

### C4 [LOGIC] Employee search treats `%` and `_` in `q` as wildcards
- Severity: low
- Status: VERIFIED
- Where: `src/features/accounts/read-employees.ts:12` (`const search = q ? \`%${q}%\` : null;`) and the two `LIKE ?` clauses at lines 17 and 20
- What: `q` is bound, so there is no injection, but it is not escaped and there is no `ESCAPE` clause. `q=%` or `q=_` matches everything, and `alpha_one` also matches `alphaXone`. SQLite `LIKE` is also ASCII-only case-insensitive, so `Ö` and `ö` do not match. A leading `%` forces a table scan; harmless at pegawai scale. This is the only `LIKE` in `src`.
- Trace or proof: `probe.mjs` (users `alpha_one`, `alphaXone`, `beta100`): `q=_` returns 4 of 4; `q=alpha_one` returns 2; `q=a%e` returns 2; `q=beta%0` returns 1.
- Failing input: `GET /employees?q=alpha_one`.
- Suggested fix: escape `\`, `%`, `_` and add `ESCAPE '\'`.

### C5 [LOGIC] PATCH with the same username logs the user out
- Severity: low
- Status: VERIFIED
- Where: `src/features/accounts/store.ts:46-48`
- What: The session purge runs when `changes.username !== undefined`, not when the username actually changed. A client that re-sends the whole form (the Flutter app likely does) on a profile edit, or a petani editing an employee, kills every session of that account even when only `nama` differed.
- Trace or proof: `probe.mjs`: `PATCH /employees/2 {username:'pegawai'}` (unchanged) returned 200; the next `/auth/me` for the pegawai token returned 401.
- Failing input: `PATCH /profile {"username":"<own current>","current_password":"..."}`.
- Suggested fix: compare against the stored username before deleting sessions (the row is already loaded in the employee path, and `getAccount` is cheap in the profile path).

### C6 [RISK] Usernames are case-sensitive and not normalised; look-alike accounts are accepted
- Severity: low
- Status: VERIFIED
- Where: `migrations/0001_initial_schema.up.sql:12` (`username TEXT NOT NULL UNIQUE`, default BINARY collation); `src/features/accounts/contracts.ts:7`; `src/features/auth/bootstrap.ts:7`; `src/features/auth/login.ts:14-17` (comment says this is deliberate)
- What: The collation is BINARY, so `petani`, `Petani` and `petani<U+200B>` are three distinct users. The login comment documents case-sensitivity as intended, so that part is a decision, not a bug. The risk is that the petani can create a pegawai whose username is visually identical to the owner's (a zero-width space is `\S` in JS), and the same regex permits tabs and interior spaces. The three username rules also differ: bootstrap `^\S+$` (no spaces at all), employee `^\S(?:.*\S)?$` (interior spaces and tabs allowed), login `/\S/` (anything). Only the petani can create employees, so exploitation needs a hostile owner or a phishing-style mistake by a staff member.
- Trace or proof: `probe.mjs`: `POST /employees` with `Petani` returned 201; `petani​` returned 201; `a b\tc` returned 201. Collation read from the migration.
- Suggested fix: pick one username rule in `common/`, restrict to printable non-space ASCII or `[\p{L}\p{N}._-]`, and add a `COLLATE NOCASE` unique index if case-insensitive is wanted.

### C7 [RISK] Logout needs a live access token, so it cannot revoke an idle session
- Severity: low
- Status: VERIFIED
- Where: `src/features/auth/logout.ts:6` (`requirePermission(db, undefined, clock)` then delete by `sessionId`)
- What: Access tokens live 15 minutes. After that, `POST /auth/logout` returns 401 and the session row (and its refresh token) stays valid for up to 7 days. A client that logs out after the app sat idle must refresh first, then log out; a client that skips this leaves a live refresh token behind. Logout does not accept a `refresh_token` body.
- Trace or proof: `probe.mjs`: advanced the clock 16 minutes, logout returned 401, then `/auth/refresh` with the same session's refresh token returned 200.
- Suggested fix: accept `refresh_token` in the logout body and delete by `refresh_token_hash` when the bearer has expired.

### C8 [RISK] Refresh rotation has no grace window and no reuse detection
- Severity: low
- Status: VERIFIED (behaviour), design judgement
- Where: `src/features/auth/refresh.ts:15-28`
- What: The conditional UPDATE makes refresh strictly single-use, which is correct for races. But if the response is lost on a flaky mobile network, the client still holds the old token, which no longer matches, so it gets 401 and the user is logged out. There is no reuse detection either: a replayed old token only returns 401 and the session continues on the new token.
- Trace or proof: `probe.mjs`: replaying the old refresh token returned 401 while the rotated token still worked.
- Suggested fix: keep the previous hash for a short window (30 to 60 s), or accept the logout-on-lost-response as a documented trade-off.

### C9 [DUP] Allowed roles hard-coded in three places
- Severity: low
- Status: VERIFIED
- Where: `src/common/sessions.ts:59` and `src/features/auth/refresh.ts:22` (`r.nama_role IN ('petani','pegawai')`); `src/common/permissions.ts:5-15` (`rolePermissions` keys); `authenticate` at `sessions.ts:35` uses `permissionsFor`
- What: A new role works in `authenticate` (via `permissionsFor`) but cannot log in or refresh until two SQL strings are edited. No drift today.
- Suggested fix: build the `IN (...)` list from `Object.keys(rolePermissions)`.

### C10 [DUP] The three inventory resources are three copies of one pattern, and they have already drifted
- Severity: low
- Status: VERIFIED
- Where: list handlers `jenis-inventaris.ts:26-37`, `obat.ts:27-38`, `inventaris.ts:31-44` (and `read-employees.ts:9-25`); deactivate handlers `jenis-inventaris.ts:55-62`, `obat.ts:61-68`, `inventaris.ts:82-89`; create handlers (201 vs 200 on replay plus `location`); GET-by-id (3 near-identical)
- What: Same handler skeleton repeated 3 times, plus a 4th in accounts, and `total_pages` meta appears in 11 files across `src`. Drift already present:
  1. The inline column list `...,${syncColumns(...)}` appears twice for jenis and for obat (list at `jenis-inventaris.ts:31` and `getJenis` at `store.ts:32`; list at `obat.ts:32` and `getObat` at `store.ts:62`), but inventaris shares one `inventarisColumns` constant.
  2. PATCH: jenis writes `nama_jenis` unconditionally and checks name uniqueness; obat uses a `'field' in input` loop with no uniqueness rule; inventaris has the loop plus unit lock plus a derived `stok_minimum_minor`.
  3. PATCH on an inactive record is allowed for all three, but employees reject it with `409 ACCOUNT_DEACTIVATED`.
  4. `inventaris.ts:18,64` re-check an obat/jenis as active only when the id is in the body, so re-sending an unchanged but since-deactivated parent id fails with 422 while omitting it succeeds (`probe.mjs`: resend same inactive jenis gives `422 JENIS_NOT_FOUND`, name-only patch gives 200).
- Suggested fix: one `listPage` helper and one `deactivate` factory; build the jenis/obat list SELECT from the same constant as the getter.

### C11 [LOGIC] Active items can sit under inactive parents; deactivate does not check references
- Severity: low
- Status: VERIFIED
- Where: `src/features/inventory/jenis-inventaris.ts:55-62`, `obat.ts:61-68`, `store.ts:105-117`
- What: Deactivating a jenis or obat leaves active `inventaris` rows pointing at it. New items cannot use the parent, and the response still shows the parent's name. No stock or nursery code references obat or jenis (grep over `src`: only `inventory/`, `seed.ts`, `stock` and `nursery` use `inventaris`; nothing uses `id_obat`), so nothing breaks. It is a data-consistency gap, not a crash. Related: a deactivated jenis can still be renamed, so its name is not burned (`probe.mjs`: rename to `Benih2` works, though a plain recreate of `Benih` gives `409 JENIS_NAME_TAKEN`).
- Suggested fix: refuse deactivation while active children exist, or state the rule in API.md.

### C12 [DEAD] `inventaris.stok_minimum` is write-only; reads use `stok_minimum_minor`
- Severity: low
- Status: VERIFIED
- Where: writes `inventaris.ts:20-23` and `:67-74`, `db/seed.ts:94`; reads only `stok_minimum_minor` in `inventory/store.ts:71`, `stock/store.ts:68`
- What: No `src` code reads `inventaris.stok_minimum`. It is kept in sync by the triggers `b006_minimum_insert` and `b006_minimum_update` (`(NEW.stok_minimum IS NULL)<>(NEW.stok_minimum_minor IS NULL)` or a mismatch aborts with `STOCK_MINIMUM_INVALID`). So the two columns cannot disagree through any write path, and a disagreement would fail loudly. Question answered: they cannot disagree. The column stays only because the migration did not rewrite it.
- Trace or proof: `probe.mjs`: PATCH `stok_minimum:'2.5'` gave row `(2.5, 250, real)`; PATCH `null` gave `(null, null, null)`. Values `0`, `0.00`, `0.001`, `1e2`, `-1`, ` 5` return 400; `9999999999.99` (the maximum) returns 200 and stored as REAL.
- Suggested fix: none needed now; note it for a future migration that drops the column.

---

## Checked and fine

- **Login enumeration and timing:** unknown user, wrong password and inactive user with a correct password all return the same `401 INVALID_CREDENTIALS` and the same message. `verifyPassword` runs scrypt against a dummy salt when the user is missing or the hash is malformed, and `timingSafeEqual` compares 64 bytes each way. Measured (in-process, 3 samples each): unknown 260/289/265 ms, wrong password 281/254/271 ms, inactive with correct password 263/302/265 ms, unknown 282/335/279 ms. No separable difference. The rate-limit bucket is keyed before lookup, so 429 does not reveal existence either.
- **Session revocation on changes:** password change through profile or employee PATCH deletes all of the user's sessions in the same transaction (`store.ts:46-48`), and `authenticate` and refresh also require `s.credential_hash=u.password`, so a stale session fails even if the delete were skipped. Username change deletes sessions (see C5 for the over-eager case). Deactivation deletes sessions and `authenticate` requires `status_aktif=1`. Activation needs nothing because none exist. No route changes `id_role` (grep: `UPDATE users` appears only in `activate`, `deactivate` and `updateAccount`), and the role is re-joined on every request anyway. A login in flight while a deactivate or password change commits fails, because `createSession` re-checks `status_aktif`, `username` and `password` in the INSERT-SELECT. Own-password change logs the caller out; this is documented in API.md.
- **Refresh:** a single conditional UPDATE checks expiry, `status_aktif`, `credential_hash` and role, so it is single-use and race-safe. The 30-day cap holds: `MIN(...,created_at+30d)`, and the CHECK constraints (`access > created`, `refresh >= access`) cannot be violated. The `?` for `now + REFRESH_TTL_MS` inside the `access_expires_at` MIN is redundant (always larger than `now + 15 min`) but harmless.
- **Role boundaries:** pegawai gets 403 on `GET /profile` and `GET /employees` (`probe.mjs`). Employee routes use `getAccount(..., 'pegawai')`, so a petani id returns 404 on GET and PATCH, and the petani cannot be edited or deactivated through `/employees`. `/auth/me` is open to both roles by design.
- **Username uniqueness:** `assertUsernameAvailable` runs inside the write transaction; the DB UNIQUE is the backstop. No check-then-write race.
- **Profile PATCH:** the current password is verified outside the transaction, then re-compared inside it against the same hash (`409 ACCOUNT_CHANGED`), so a concurrent password change is caught. The Zod refine and the handler condition agree (username min 1, password min 12, so truthiness and `!== undefined` coincide).
- **Nullable PATCH semantics:** in accounts, `!== undefined` is used and JSON cannot carry `undefined`, so `null` clears `email`, `no_telepon`, `alamat`. In inventory `'field' in input` is correct because Zod 4 does not add absent optional keys. `null` on non-nullable fields (`nama_barang`, `satuan`, `id_jenis_inventaris`) returns 400; `id_obat:null` and `dosis:null` clear correctly; `{}` and `{expected_version}` alone return 400 (`probe.mjs`).
- **Unit lock:** checked inside the write transaction against `detail_stok`, with the DB trigger `b006_inventory_unit` as a second layer. Real unit changes with history return `409 UNIT_LOCKED`.
- **Bootstrap and CLI:** the transaction checks for an existing petani and a duplicate username, and inserts roles with `ON CONFLICT DO NOTHING`; the password is removed from `process.env`, never logged, and the CLI refuses to run with pending migrations. The `auth:bootstrap` script runs `dist/...`, so it needs `npm run build` first (not a bug).
- **Idempotency and sync wrapper for inventory:** replay returns 200 with the stored receipt; `x-client-id` is only accepted on create; the `JSON.parse(JSON.stringify(payload))` normalisation is needed for the `{id,input}` shape.
- **Numeric handling:** `positiveDecimalSchema` canonicalises (`1.50` to `1.5`), rejects 0, more than 2 decimals, exponent, sign and whitespace, and the maximum is bounded; response `di_bawah_minimum` compares BigInts.
- **Auth `/me` and `Principal`:** `sessionId` is stripped; no password hash or token reaches any response. Error handler never logs raw errors.
- **Config-dependent (not a defect here):** rate-limit buckets use `request.ip`; with no `TRUSTED_PROXIES` or `TRUST_PROXY_HOPS` behind a serverless proxy, all clients share one IP, so `login:<ip>:<user>` becomes a global 10-per-15-minute bucket per username and one attacker can lock an account out. Successful logins also count against the same bucket (the code comment accepts the lockout trade-off). Verify the deployment sets one of the two variables.

## Counts

By category: DEAD 1, DUP 2, LOGIC 6, RISK 3 (C6, C7, C8), SMELL 0. (C1 to C5, C11 are LOGIC; C12 DEAD; C9, C10 DUP.)
By severity: critical 0, high 0, medium 2 (C1, C3), low 10.
