-- Migration 0007 down: remove nursery indexes and triggers
DROP TRIGGER IF EXISTS trg_penyemaian_status_update;
DROP TRIGGER IF EXISTS trg_penyemaian_status_insert;
DROP INDEX IF EXISTS idx_penyemaian_user_date;
-- sync_resource_links entries for penyemaian are soft-orphaned; no destructive cleanup needed.
