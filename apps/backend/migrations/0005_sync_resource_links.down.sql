DELETE FROM sync_resource_versions WHERE public_id IN (SELECT public_id FROM sync_resource_links);
DROP TABLE sync_resource_links;
