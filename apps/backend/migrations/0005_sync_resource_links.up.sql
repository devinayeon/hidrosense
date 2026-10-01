CREATE TABLE sync_resource_links (
  resource_type TEXT NOT NULL,
  domain_id TEXT NOT NULL,
  public_id TEXT NOT NULL UNIQUE CHECK (length(public_id)=36),
  PRIMARY KEY (resource_type, domain_id)
);

-- Preserve existing domain IDs while assigning stable public identities.
INSERT INTO sync_resource_links (resource_type,domain_id,public_id)
SELECT resource_type,domain_id,
  lower(hex(randomblob(4)))||'-'||lower(hex(randomblob(2)))||'-4'||substr(lower(hex(randomblob(2))),2)
  ||'-8'||substr(lower(hex(randomblob(2))),2)||'-'||lower(hex(randomblob(6)))
FROM (
  SELECT 'jenis-inventaris' AS resource_type,CAST(id_jenis_inventaris AS TEXT) AS domain_id FROM jenis_inventaris
  UNION ALL SELECT 'obat',CAST(id_obat AS TEXT) FROM obat
  UNION ALL SELECT 'inventaris',CAST(id_inventaris AS TEXT) FROM inventaris
);

INSERT INTO sync_resource_versions (resource_type,public_id,version,changed_at)
SELECT resource_type,public_id,1,CAST(strftime('%s','now') AS INTEGER)*1000 FROM sync_resource_links;
