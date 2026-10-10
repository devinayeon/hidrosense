DELETE FROM sync_resource_versions WHERE resource_type='panen';
DELETE FROM sync_resource_links WHERE resource_type='panen';
DROP INDEX idx_panen_date_id;
ALTER TABLE detail_panen DROP COLUMN berat_reject_minor;
ALTER TABLE detail_panen DROP COLUMN berat_minor;
