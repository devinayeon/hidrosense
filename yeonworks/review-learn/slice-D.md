# Slice D: cultivation chain (stock, nursery, tables, transfers, damage)

All paths are relative to `D:\Dev\Projects\hidrosense\apps\backend`. I read every file in `src/features/{stock,nursery,tables,transfers,damage}`. I also read `src/common/{sync,quantities,validation,authenticated-write,dates}.ts`, `src/features/harvest/{service,contracts}.ts` (it changes active plants), `src/features/sync/changes.ts`, and migrations 0001, 0006, 0007, 0008, 0009, 0010, 0012 and 0015.

Probe scripts (in-memory DB only, run from `apps/backend` with `node --import tsx <script>`):
- `C:\Users\Delion\AppData\Local\Temp\claude\6f51bf7f9cfd15e3\7068d4a5-4b1d-4583-ab33-a15eb255e81e\scratchpad\learn\d\seq.mjs`: sequences S1 to S7, plus a 400-step random fuzz (S8) over transfer, damage create, damage patch, harvest, table capacity and sowing `jumlah_benih`. It checks the invariants after every step.
- `C:\Users\Delion\AppData\Local\Temp\claude\6f51bf7f9cfd15e3\7068d4a5-4b1d-4583-ab33-a15eb255e81e\scratchpad\learn\d\recon.mjs`: reconcile pagination past 100 rows, the error code for a full table, and damage zeroing or deletion.

Headline: the core invariants hold. No table goes over capacity, no batch goes negative, `moved <= jumlah_benih` always holds, and the stored `tersedia`/`penuh` value always equals the derived one. The fuzz found 0 violations in 400 steps. The real defects are in lifecycle and correction paths: completed sowings and wrong records cannot be corrected. There are also smaller consistency gaps.

---

### D1 [LOGIC] Sowing completion is terminal, so an under-counted sowing can never be corrected
- Severity: medium
- Status: VERIFIED
- Where: `src/features/transfers/service.ts:82-88` (auto `selesai`); `src/features/nursery/service.ts:51-53` (any PATCH on a `selesai` sowing is refused); `src/features/nursery/contracts.ts:43`
- What: `createTransfer` sets `status_penyemaian='selesai'` once `moved >= jumlah_benih`. `updateSowing` then refuses every change to a `selesai` sowing, including `jumlah_benih`, `keterangan` and `status_penyemaian:'aktif'`. Suppose the farmer typed too small a seed count and moved that many. The sowing is then locked for good, and the remaining real seedlings can never be transferred. A manual `selesai` set by mistake is irreversible in the same way.
- Trace or proof: `seq.mjs` S2. Sowing 50, move 50, then the sowing reads `status=selesai`. `PATCH jumlah_benih=80` returns `409 SOWING_COMPLETED`. `PATCH keterangan` returns `409 SOWING_COMPLETED`. `PATCH status_penyemaian='aktif'` returns `409 SOWING_COMPLETED`.
- Failing input: `POST /penyemaian {jumlah_benih:50}`, then `POST /pemindahan {jumlah_tanaman:50}`, then `PATCH /penyemaian/:id {jumlah_benih:80}`.
- Suggested fix: allow `jumlah_benih` increases on a `selesai` sowing and recompute the status (`aktif` when `moved < jumlah_benih`). Alternatively, derive `selesai` from `sisa_benih = 0` instead of storing it. Allow `keterangan` edits at any status.

### D2 [LOGIC] Shrinking `jumlah_benih` to the moved count leaves the sowing `aktif` with nothing left to move
- Severity: low
- Status: VERIFIED
- Where: `src/features/nursery/service.ts:55-61` versus `src/features/transfers/service.ts:83`
- What: the auto-complete rule `moved >= jumlah_benih` runs only in `createTransfer`. `updateSowing` accepts `jumlah_benih == moved`, which gives `sisa_benih` 0, but keeps `status_penyemaian='aktif'`. Every further transfer then fails `SEEDLING_INSUFFICIENT`. The two paths that reach "nothing left" disagree on the resulting status.
- Trace or proof: `seq.mjs` S1. Sowing 100, move 60, `PATCH jumlah_benih=60` returns 200 with `status=aktif sisa=0 siap=true`. A move of 1 returns `409 SEEDLING_INSUFFICIENT`.
- Failing input: as above.
- Suggested fix: apply the same completion rule in `updateSowing`, or derive the status from `sisa_benih` (see D1).

### D3 [LOGIC] `siap_pindah` ignores status and remaining seedlings
- Severity: low
- Status: VERIFIED
- Where: `src/features/nursery/store.ts:27` (`siap_pindah: age >= 15`) and `:89` (list filter on age only)
- What: `siap_pindah` ("ready to transfer") is true for a `selesai` sowing and for an `aktif` sowing with `sisa_benih` 0. A transfer from either is rejected (`SOWING_INACTIVE` or `SEEDLING_INSUFFICIENT`). `GET /penyemaian?siap_pindah=1&status_penyemaian=aktif` still returns the stuck sowing from D2.
- Trace or proof: `seq.mjs` S1 shows the list includes the stuck sowing (`true`). S2 shows `status=selesai siap_pindah=true sisa=0`.
- Suggested fix: define `siap_pindah` as `status='aktif' AND age >= 15 AND sisa_benih > 0`, in both the JS row and the SQL filter.

### D4 [LOGIC] No correction path for sowing stock, damage records or transfers
- Severity: medium
- Status: VERIFIED
- Where: `src/features/stock/service.ts:24-26` (sowing-origin reversal refused); `src/features/nursery/service.ts` (no cancel, and no material edit); `src/features/damage/contracts.ts:28` (`jumlah_tanaman` positive) together with `src/features/damage/index.ts` (no DELETE); `src/features/transfers/contracts.ts:25-31` (only `keterangan` is editable) together with `src/features/transfers/index.ts` (no DELETE)
- What: `reverseMovement` refuses stock with an `id_penyemaian` and says "harus dikoreksi melalui fitur pemiliknya". The nursery feature has no such correction, so seed consumed by a wrong sowing never returns to stock. A damage record cannot go below 1 and cannot be deleted, so a wrong entry permanently removes at least one active plant. A transfer to the wrong table, or with the wrong count, cannot be changed at all.
- Trace or proof: `seq.mjs` S5: reversing the sowing stock returns `409 REVERSAL_NOT_ALLOWED`. `recon.mjs`: `PATCH /kerusakan/:id {jumlah_tanaman:0}` returns `400 VALIDATION_ERROR`, `DELETE /kerusakan/:id` returns 404, and `DELETE /pemindahan/:id` returns 404.
- Suggested fix: add owner-feature corrections that go through the same write transaction. Examples: a sowing cancel that reverses its stock line, allowing damage `jumlah_tanaman` 0 (or a void flag), and a transfer void while the batch has no damage or harvest. Until then, change the error message so it does not promise a path that does not exist.

### D5 [RISK] Transfer gate trusts the stored `status_meja`, and a full table reports the wrong error
- Severity: low
- Status: VERIFIED (error code); SUSPECTED (future coupling)
- Where: `src/features/transfers/service.ts:64-67`; writers of `syncTableStatus`: `transfers/service.ts:78`, `damage/service.ts:54,118`, `harvest/service.ts:26`, `tables/service.ts:25`
- What: `createTransfer` rejects any table whose stored status is not `tersedia`, instead of deriving the status from occupancy. That is correct today only because all four active-plant writers call `syncTableStatus`. A future writer that forgets the call (for example a harvest correction or a transfer void from D4) would block transfers into a table that has free holes. A table that is exactly full also returns `TABLE_NOT_AVAILABLE` ("sedang tidak dapat digunakan"), while a table that is short of holes returns `TABLE_CAPACITY_EXCEEDED`.
- Trace or proof: `recon.mjs`. Moving 2 into a 4/5 table returns `409 TABLE_CAPACITY_EXCEEDED`. Moving 1 into a 5/5 table returns `409 TABLE_NOT_AVAILABLE`.
- Suggested fix: gate on manual statuses only (`lower(status_meja) NOT IN ('tersedia','penuh')`) and let the capacity check decide fullness. That also makes the error code consistent.

### D6 [DUP] Batch-active arithmetic is written five times
- Severity: low
- Status: VERIFIED (read; no drift today)
- Where: `src/features/tables/store.ts:7-9`, `src/features/transfers/store.ts:12-14`, `src/features/harvest/service.ts:13` (inline), `src/features/damage/service.ts:36-43` and `:97-106` (same rule in JS, with the harvested-sum query copied twice), `migrations/0012_table_occupancy_status.up.sql:4-8`. Related copies: `nursery/store.ts:109-116 countMoved` equals `transfers/store.ts:120-126 countMovedSeedlings`, which is also inline at `nursery/store.ts:51-52`. `tables/store.ts:16-20 occupancyStatus` (JS) mirrors `:21-24 effectiveStatusSql` (SQL).
- What: "moved minus damaged minus harvested" and "moved per sowing" have no single owner. All copies agree today (same `COALESCE`/`SUM`, same `>=` for `penuh`, both lower-case the status). A change to the rule, for example excluding voided damage, would need about five edits in four features.
- Suggested fix: export one `batchActiveSql` and one `countTableActive` from `tables/store.ts` (or a shared `cultivation` module), and use them in damage and harvest too.

### D7 [LOGIC] A metadata-only damage PATCH publishes derived changes for the batch and the table
- Severity: low
- Status: VERIFIED
- Where: `src/features/damage/service.ts:117-120`
- What: `updateDamage` always runs `syncTableStatus` and records derived changes for `pemindahan` and `meja-tanam`, even when only `keterangan`, `jenis_kerusakan` or `tanggal_kejadian` changed. Every device then re-fetches a batch and a table whose numbers did not move.
- Trace or proof: `seq.mjs` S3. `PATCH /kerusakan/:id {keterangan:'x'}` added 3 `sync_changes` rows: `kerusakan_tanaman`, `meja-tanam` and `pemindahan`.
- Suggested fix: run the sync and the derived changes only when `input.jumlah_tanaman` is defined and differs from the stored value.

### D8 [LOGIC] Auto-completion changes the sowing's own field without bumping its version
- Severity: low
- Status: VERIFIED
- Where: `src/features/transfers/service.ts:79,84-87`; contract at `src/common/sync.ts:95-98`
- What: `recordDerivedChange` says it is for records whose "own fields did not [move]". `createTransfer` uses it for `penyemaian` and then rewrites `status_penyemaian`, which is a stored field of that sowing. The sowing keeps version 1 while its status flips. A client that caches by version, or a PATCH with `expected_version` 1, cannot tell the record changed. The PATCH is caught later only by the D1 block.
- Trace or proof: `seq.mjs` S2 prints `penyemaian version after auto-selesai (own field changed): 1`.
- Suggested fix: bump the sowing's resource version when the status changes, or derive the status (D1) so it is no longer a stored field.

### D9 [DEAD] The `toMinor` upper-bound branch is unreachable, and the SQL repeats the bound as a literal
- Severity: low
- Status: VERIFIED
- Where: `src/common/quantities.ts:4,11`; `src/features/stock/store.ts:117`
- What: `decimalPattern` allows at most 10 whole digits and 2 fraction digits. The largest input is `9999999999.99`, which is 999999999999 minor, exactly `MAX_QUANTITY_MINOR`. So `minor > MAX_QUANTITY_MINOR` can never be true. `appendMovement` hard-codes `BETWEEN 0 AND 999999999999` instead of using the constant. `reconcile.ts` and the migrations hard-code it too.
- Trace or proof: `seq.mjs` S6. `toMinor('9999999999.99')` returns 999999999999. Stock `masuk 9999999999.99` returns 201. A further `0.01` returns `409 STOCK_LIMIT_EXCEEDED` from the SQL guard. 11 digits return `400 VALIDATION_ERROR`.
- Suggested fix: keep the guard as defence but say it is defensive, and pass `MAX_QUANTITY_MINOR` as a SQL argument instead of the literal.

### D10 [DEAD] Unreachable branches in services
- Severity: low
- Status: VERIFIED (callers and schemas checked)
- Where and why:
  - `src/features/stock/service.ts:11-13`: `origin && jenis_stok !== 'keluar'`. The only caller with an `origin` is `nursery/service.ts:31-35`, which always passes `'keluar'`. The branch also uses the wrong code (`REVERSAL_NOT_ALLOWED` for a direction error). The DB trigger `b006_header_insert` backs up the rule anyway.
  - `src/features/stock/service.ts:24`: `original.id_perawatan`. No code writes `stok.id_perawatan` (care is not built), so only legacy rows can reach it.
  - `src/features/transfers/store.ts:147`: `if ('keterangan' in input)`. `updateTransferSchema` has only `keterangan` as a changeable key, and `hasChanges` forces at least one such key, so the condition is always true.
  - `src/features/nursery/service.ts:78-80`: `!assignments.length`. `hasChanges` already guarantees that one of the three fields is present.
  - `src/features/nursery/contracts.ts:43`: `status_penyemaian: 'aktif'` is always a no-op. An `aktif` sowing is already `aktif`, and a `selesai` one is refused (D1).
  - `src/features/tables/store.ts:91`: `patchTable` returns `getTable(...)`, but `tables/service.ts:24` discards it and calls `getTable` again after `syncTableStatus`. That is one wasted query per PATCH.
- Suggested fix: delete these, or turn the `origin` check into an assertion with a correct code.

### D11 [DUP] The nursery material schema re-implements the stock quantity rule and has already drifted
- Severity: low
- Status: VERIFIED
- Where: `src/features/nursery/contracts.ts:17-23` versus `src/common/quantities.ts:4,27-29`; normalised again at `src/features/stock/service.ts:10`
- What: the nursery uses `/^\d+(\.\d{1,2})?$/` plus `parseFloat > 0`. That has no 10-digit limit, accepts leading zeros, and uses a float test. An 11-digit `jumlah` passes the route schema and fails only inside the write transaction, after the `penyemaian` row has been inserted (the transaction then rolls back). The idempotency payload hashes the raw string (`"0005.5"`), while the ledger stores `"5.5"`.
- Trace or proof: `seq.mjs` S6. Sowing material `10000000000` returns `400 VALIDATION_ERROR` (from the inner parse). `0005.5` returns 201.
- Suggested fix: use `positiveDecimalSchema` in `materialLineSchema`.

### D12 [LOGIC] A sowing does not have to consume any seed
- Severity: low
- Status: VERIFIED (behaviour); SUSPECTED (intent)
- Where: `src/features/nursery/contracts.ts:30-37` (comment: "at least one seed material must be recorded"); `src/features/nursery/service.ts:31-35`
- What: the schema only requires at least one material line of any inventory item. A sowing that consumes only fertiliser (`kg`) is accepted, so the rule "a sowing consumes seed" is not enforced.
- Trace or proof: `seq.mjs` S7. A sowing whose only material is `Pupuk` with `0.5 kg` returns 201.
- Suggested fix: if the rule is real, require at least one line whose `jenis_inventaris` is the seed category (this needs a stable category key). Otherwise, correct the comment.

### D13 [RISK] Nursery create writes the stock ledger but does not map lock errors to 503
- Severity: low
- Status: SUSPECTED
- Where: `src/features/stock/write.ts:25-29` versus `src/features/nursery/write.ts:31-47`
- What: `stockWrite` turns `SQLITE_BUSY` and transport errors into `503 STOCK_WRITE_UNAVAILABLE`, which tells the client to retry with the same key. `nurseryWrite` performs the same ledger write (through `recordMovement`) but lets those errors reach the client as 500. The two endpoints give different retry signals for the same failure.
- Suggested fix: wrap `nurseryWrite`, and the other cultivation writers, with the same `stockUnavailable` mapping, or move it into `authenticatedWrite`.

### D14 [RISK] `reconcileStock` can flood its mismatch list
- Severity: low
- Status: SUSPECTED
- Where: `src/features/stock/reconcile.ts:27-28`
- What: once an item's ledger prefix leaves `[0, MAX]`, every later detail row of that item pushes another `LEDGER_PREFIX_OUT_OF_BOUNDS` entry. The array and the printed JSON are unbounded in the number of ledger rows.
- Suggested fix: record only the first out-of-bounds row per item, or cap the mismatch list and report a count.

### D15 [LOGIC] "Date in the future" uses three different error codes
- Severity: low
- Status: VERIFIED (read)
- Where: `src/features/nursery/service.ts:18-20` (`SOWING_DATE_IN_FUTURE`), `src/features/transfers/service.ts:38-40` (`INVALID_TRANSFER_DATE`), `src/features/damage/service.ts:10-13` (`VALIDATION_ERROR`), `src/features/harvest/service.ts:10` (`VALIDATION_ERROR`)
- What: the same rule returns three codes across sibling endpoints. The date-order checks also differ (`INVALID_TRANSFER_DATE`, `INVALID_DAMAGE_DATE`, `INVALID_HARVEST_DATE`). A client cannot handle "future date" with one code. The four copies of `dateSchema` (nursery, transfers, damage, harvest contracts) are a related duplicate.
- Suggested fix: use one shared `DATE_IN_FUTURE` code and one shared date schema.

---

## Checked and fine
- **Every rule runs inside the write transaction.** Transfers, damage, harvest, table updates and sowings re-read counts through `tx`. `authenticatedWrite` opens `db.transaction('write')` and uses one connection (`concurrency: 1`), so no check reads stale numbers.
- **No table goes over capacity.** The 400-step fuzz (`seq.mjs` S8) mixed transfers, damage creates and restores, harvests, capacity shrinks and `jumlah_benih` edits. It found 0 violations. Table active plants never exceeded capacity, no batch went negative, and `moved <= jumlah_benih` held throughout.
- **Stored and derived status always agree.** After every fuzz step, the stored `tersedia`/`penuh` value equalled the derived occupancy.
- **Damage capacity maths is right.** `restored`, `otherDamaged` and `remaining` all behave correctly (S3). A restore over capacity returns 409. A restore is allowed once a harvest frees holes. A new damage is bounded by `moved - damaged - harvested`. A restore on a table whose capacity was shrunk to equal its active plants returns 409 (S4).
- **Capacity shrink is guarded.** Shrinking `jumlah_lubang` to equal the active plants is allowed and flips the table to `penuh`. Going below returns `409 TABLE_UNDERCAPACITY`.
- **Every active-plant writer syncs.** Transfer create, damage create and update, and harvest create all call `syncTableStatus` and `recordDerivedChange` for the batch or table. A table PATCH bumps its own version.
- **`status_meja` case handling works.** `TERSEDIA` is stored and served as derived `tersedia`. The list filter is case-insensitive. `Penuh` and `PENUH` are rejected with `TABLE_STATUS_DERIVED`. Manual `Perbaikan` is kept through damage, blocks transfers, and returns to derived status when set back to `tersedia`.
- **Stock reversal rules hold.** A second reversal returns `409 STOK_ALREADY_REVERSED`. Reversing a reversal returns `409 REVERSAL_NOT_ALLOWED`. Reversing a sowing-origin movement returns 409. Reversing a `masuk` after part of it was consumed returns `409 INSUFFICIENT_STOCK`. A unit mismatch returns 422. The `appendMovement` order (reversal check, item check, unsealed header, bounded projection update, detail insert, seal) is correct, and the B006 triggers back it up.
- **Quantity bounds hold.** `toMinor`/`fromMinor` round-trip at the maximum, and overflow fails closed.
- **`reconcileStock` paginates correctly.** Its keyset uses TEXT arguments against INTEGER columns. It paged correctly past 100 rows (390 of 390 details) and caught a 1-minor projection tamper (`recon.mjs`).
- **Transfer age and the list filter agree.** Age is measured from `tanggal_pemindahan`, and a future transfer date is rejected. The `siap_pindah` SQL (`julianday <= today - 15`) matches the JS `age >= 15`.
- **`listTables` filters on the derived status.** Its filter uses `effectiveStatusSql` over the same `tanaman_aktif` subquery.

Count by category: LOGIC 8, DEAD 2, DUP 2, RISK 3, SMELL 0. By severity: medium 2, low 13.
