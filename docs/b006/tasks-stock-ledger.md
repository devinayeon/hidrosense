# B006 Structured Task Plan

Date: 3 October 2026, Asia/Jakarta. [PRD](prd-stock-ledger.md) and [architecture](architecture-stock-ledger.md) define scope and contracts.

## Completed refinement activities

- [x] R-01: Run prescribed find-skills discovery, read full output and integrate relevant existing guidance.
- [x] R-02: Query graphify; confirm HEAD, B000–B005 reports, current schema/receipts/permissions and deployment evidence.
- [x] R-03: Delegate independent contract and schema/atomicity reviews to two sub-agents.
- [x] R-04: Define scale/range/rounding/unit policy, immutable audit and reversal behavior.
- [x] R-05: Define stable operation keys, current-auth replay and response-loss behavior across writers.
- [x] R-06: Define conditional integer balance update, migration/backfill/recovery and future domain linkage.
- [x] R-07: Draft PRD with FR/NFR acceptance criteria, architecture, risks and implementation tasks.
- [x] R-08: Independently verify artifact consistency and publish the [planning readiness verdict](readiness-report-b006-2026-10-03.md): PASS.

The earlier planning run stopped after R-08. On 3 October 2026 the user explicitly requested review of all four artifacts and B006 implementation. The implementation todo below tracks that authorized follow-up; B007–B019 and production deployment remain outside this run.

## Implementation todo — 3 October 2026

- [x] T-01: Re-read the four planning artifacts; confirm baseline and discover applicable skills.
- [x] T-02: Implement I-01 exact contracts and I-02 migration; delegate independent work.
- [x] T-03: Implement I-03–I-06 stock store/use cases, receipts, reversals, HTTP and inventory invariants.
- [x] T-04: Implement/execute P-01–P-15 relevant local proofs and regression checks under I-07.
- [x] T-05: Review the diff independently; resolve findings.
- [x] T-06: Publish I-08 implementation/API evidence, update graphify and final task statuses.

Staging/production claims require their own actual evidence; local completion does not mark remote deployment complete.

## Implementation epic and stories

Epic B006 implements PB-02 stock transactions, with B004/PB-07 retry foundations. Every activity starts with the user's required discovery command and full-output read. Maintain an explicit task status and delegate independent schema/test/contract work where safe. No development begins before the PRD and architecture are read and the planning gate is accepted.

| Task | Dependencies | Scope / acceptance | Requirements |
| --- | --- | --- | --- |
| I-01 | R-08 | Implement exact decimal parser/formatter and strict request/query/header schemas; reject unsupported precision/duplicates; canonicalize before hash | FR-001/002/003/007/008, NFR-001/005 |
| I-02 | R-08 | Build migration preflight and exact backfill, integer columns/projection, sealed guards, unique reversal/source links, stock identity backfill and guarded recovery | FR-001/002/005/010/011, NFR-002/004 |
| I-03 | I-01/02 | Implement persistence/use case using active transaction and conditional projection updates; all lines commit/rollback together | FR-003/004/005/011, NFR-002/003/005 |
| I-04 | I-03 | Require stock operation keys; integrate shared receipt/UUID/version boundary and classify unavailable/uncertain outcomes | FR-007/009/012, NFR-001/002/006 |
| I-05 | I-03/04 | Implement whole reversal with immutable original, exact copied lines and unique target; forbid generic domain reversal | FR-006/011/012, NFR-002 |
| I-06 | I-02/04/05 | Register write/read endpoints; update B005 unit/minimum writes for the new invariant; implement history/detail/balance | FR-002/008/009, NFR-001/003 |
| I-07 | I-01–06 | Execute focused unit/store/HTTP/migration/concurrency tests and independent review; resolve findings | All FR/NFR |
| I-08 | I-07 | Publish implemented API contract, actual test evidence, recovery/deployment notes; graphify update after code changes | FR-008/010/012, NFR-004/005/006 |

All I-01–I-08 are **complete for the authorized local implementation**. Final `npm run check` passed typecheck, the 400-line limit and **153/153 tests**; `npm run build` passed. Independent reviews were completed and findings resolved. [Implementation evidence](../backend-b006.md) maps the actual proofs; [API documentation](../backend-stock-api.md) publishes the implemented contract. Remote deployment and staging obligations are explicitly pending below.

## Deployment obligations — not executed

- [ ] D-01: Verify consistent staging snapshot/restore and populated preflight against actual remote data.
- [ ] D-02: Apply migration 0006 to disposable staging Turso, reconcile and inspect schema/health evidence.
- [ ] D-03: Run independent remote writers, response-loss/uncertain commit and representative workload measurement.
- [ ] D-04: Deploy coordinated B005/B006 writers using the documented recovery procedure after staging proof.

Remote 0001–0005 remain applied according to previous evidence; this run did not access live data or apply remote 0006. Local completion does not close D-01–D-04 or certify production readiness.

## Required regression proofs

| Case | Expected result |
| --- | --- |
| P-01: repeat fractional usage, `0.01`, `0.1`, `0.2` | Exact atom arithmetic and canonical output; no drift |
| P-02: minimum/maximum and malformed precision | Reject zero/negative/exponent/number/three decimals; allow max line and max balance; reject over-cap addition |
| P-03: two-item write, second invalid/insufficient | No header/detail/projection/mapping/version/success receipt survives |
| P-04: two independent clients consume more than total availability | At most one commit; loser retries with same key and then receives correct business conflict; projection equals ledger |
| P-05: concurrent same actor/key/request | One header and one receipt; second succeeds only as matching replay, including contention retry |
| P-06: commit then simulate lost response | Same-key retry returns exact saved snapshot, no deduction/version increment; replay after inventory deactivation succeeds |
| P-07: same key changed payload/type/client identity | OPERATION_CONFLICT; actor namespaces stay independent; duplicate logical domain consumption still prevented |
| P-08: receipt/detail/seal/mapping failure injection | Full rollback; original successful receipt immutable; same failed key can be retried |
| P-09: whole reversal, incoming partially unavailable, duplicate reversal | Opposite exact lines; insufficient reversal fails; exactly one reversal allowed; original unchanged |
| P-10: history unit lock and sealing | Unit changes fail after history even at zero balance; SQL UPDATE/DELETE and late detail INSERT fail |
| P-11: inactive item and linked consumption | New manual use rejects inactive; reversal permitted if otherwise valid; generic domain links/reversal rejected |
| P-12: access and signed64 IDs | Petani read-only; employee write; anonymous/revoked denied; IDs above JS-safe range retain exact string identity |
| P-13: populated upgrade, repeat-up and guarded down | IDs/references/receipts/old-column fingerprints preserved; invalid legacy values/prefix balances abort without changes; no populated audit deletion |
| P-14: current minimum/projection consistency | Exact minimum companion updated atomically with B005 writes; balance reads/reconciliation agree; null/threshold behavior matches PRD |
| P-15: locks and ambiguous remote commit | Classified retry contract; no false “not committed” claim; receipt resolves retry using original key |

Use file-backed SQLite with two independently opened clients for local writer proofs. Distinguish contention from the shared HTTP throttle. Use a disposable staging Turso database for remote transaction/response-loss tests before deployment; do not infer them from in-memory tests. Remote credentials/deployment authorization belong to the later deployment task.

After focused checks, run the project's `npm run check`, `npm run build`, and scoped diff checks once; repeat only after changes/findings. The original planning run implemented no tests. The authorized follow-up added 68 stock tests and reran all 85 existing regression tests: **153 passed, 0 failed/skipped/cancelled**, about 52.2 seconds for the final full suite. Graphify's AST update completed; SQL extraction was skipped because its parser is unavailable, so migration proof comes from the actual SQL tests.

## Sequential handoff and stop conditions

| Stage | Starts after | Required refinement / closure |
| --- | --- | --- |
| B006 implementation | Planning gate and a new implementation request | Complete I-01–I-08 and relevant staging proof; no open stock-integrity defect |
| B007 seeding | B006 proven | Separate PRD: exact material allocation, seed count/status/correction, business dates and 15-day readiness; atomic source consumption |
| B008–B010 | B007 proven, in listed order | PRDs for table capacity, batch transfer, damage and shared active-plant equation; resolve B009 harvest-age discrepancy |
| B011 detection | B010 proven | PRD for client YOLO results, multiobject/empty/failure/asset-pending states and Cloudinary ownership |
| B012–B014 | B011 proven, in listed order | Validated agronomic rules/version/history; decision does not consume stock; actual care consumes once atomically |
| B015–B016 | B014 proven, in listed order | PRDs for partial harvest, exact weight/money and corrections; no oversell |
| B017 | B016 proven | Full domain-aware push/pull, dependencies and two-device replay/conflict simulator |
| B018 | B017 proven | Non-weather end-to-end package, staging, restore/upgrade and handoff proof |
| B019 | B018 proven and official BMKG revision received | Refine official weather contract first; remains on hold and lowest priority |

This plan does not draft speculative final contracts for later phases with unresolved product inputs. Each stage must close its own decisions before coding.
