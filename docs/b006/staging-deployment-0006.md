# B006 staging deployment plan for migration 0006

Status: local tooling prepared on 4 October 2026. D-01–D-04 remain open. This plan does not authorize use of the database configured in `apps/backend/.env` or a production rollout.

## Target and stop conditions

Use a disposable Turso database with its own ignored `apps/backend/.env.staging` containing `DATABASE_URL` and `DATABASE_AUTH_TOKEN`. Record the database name and confirm it is disposable before any write. Do not copy production credentials into this file. Work from `apps/backend`; install dependencies with `npm ci` if needed. Keep old stock writers stopped during migration and recovery. The expected starting history is `0001`–`0005` applied and only `0006_stock_ledger` pending. Stop on any other history, checksum, target, snapshot, preflight, reconciliation, or health result. Never run the guarded down migration on populated stock data.

## D-01: snapshot and restore proof

1. Read the target identity outside application logs and inspect migration status with `node --env-file=.env.staging src/db/cli.js status`. Confirm the expected history above. Record the status without URL or token.
2. Set `TURSO_MIGRATION_EXPECTED_PENDING=0006_stock_ledger` and `TURSO_MIGRATION_SNAPSHOT_ONLY=1`. Run `node --env-file=.env.staging scripts/deploy-turso-migrations.mjs`. This mode reads a consistent remote snapshot, restores it into an ignored local SQLite backup, checks fingerprints, foreign keys and integrity, then stops before remote migration. Require exit 0, `status: snapshot-verified`, `backupVerified: true`, and the backup path. Keep the backup private.
3. Keep the verified backup unchanged. Copy it to a new ignored SQLite file in `apps/backend/backups`, set `DATABASE_URL` to that local `file:./backups/...` copy, and run `node src/db/cli.js up` against the copy. Run `node --import tsx scripts/reconcile-stock.mjs` against the same copy. Record the original populated row counts for `stok`, `detail_stok`, `inventaris`, identities and receipts, plus migration/reconciliation results. Clear the local `DATABASE_URL` before any remote step. The populated legacy preflight is in `0006_stock_ledger.up.sql`; this local rehearsal must pass before D-02. If staging is empty, record that limitation. Do not edit applied migrations or round legacy values to force a pass.

## D-02: apply and inspect 0006

1. Recheck target, stopped writers and migration status. Clear `TURSO_MIGRATION_SNAPSHOT_ONLY`; set `TURSO_MIGRATION_DEPLOY=1` and keep `TURSO_MIGRATION_EXPECTED_PENDING=0006_stock_ledger`. Run `node --env-file=.env.staging scripts/deploy-turso-migrations.mjs`. The script takes another verified snapshot before applying pending migrations. Require `applied` to contain only `0006_stock_ledger`, all history applied, domain fingerprints preserved, foreign keys clean and rerun no-op.
2. Run `node --env-file=.env.staging --import tsx scripts/reconcile-stock.mjs`. Require `consistent: true`, zero unsealed headers and no mismatches. Record checked detail/balance counts.
3. Set `TURSO_LIVE_VERIFY=1` and run `node --env-file=.env.staging --import tsx scripts/verify-turso-live.mjs` on staging only. This script writes and cleans scratch tables. Require schema, readiness, transaction and cleanup checks to pass. Its schema comparison covers full object definitions but reports counts and mismatch names, not individual columns. Inspect `stok_saldo`, `stok.sealed`, and `stok.reversal_of` separately in read-only schema queries. Preserve sanitized evidence and backup location.

## D-03 and D-04 handoff

- D-03: after D-02, run two independent remote writers against the disposable target. Exercise contention, same-key replay after response loss, uncertain commit resolution, rollback, and a representative measured workload. Record inputs, sample size, connection conditions, receipts, final balance and reconciliation. Local `stock-failures.test.js` does not satisfy this gate.
- D-04: only after D-01–D-03 pass, schedule one coordinated B005/B006 writer deployment. Stop old writers, take a fresh verified snapshot, migrate, reconcile, deploy matching writers, verify health, then enable traffic. Retain the snapshot and accepted-operation log for forward recovery. Production target and process lifecycle require their own operator confirmation.

No new adapter, ORM, migration, or stock behavior is part of this preparation. Mark each D item complete only with actual staging or deployment evidence, not this plan.
