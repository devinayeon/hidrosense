-- B006 expands the existing ledger atomically; no legacy column is rewritten.
-- Guard helper tables are dropped before commit. Any failed check rolls everything back.
CREATE TABLE _b006_guard (valid INTEGER CONSTRAINT b006_legacy_preflight CHECK(valid=1));
INSERT INTO _b006_guard SELECT 0 FROM stok s WHERE
  s.id_stok < 1 OR s.jenis_stok NOT IN ('masuk','keluar')
  OR (SELECT count(*) FROM detail_stok d WHERE d.id_stok=s.id_stok) NOT BETWEEN 1 AND 100
  OR (s.id_penyemaian IS NOT NULL AND s.id_perawatan IS NOT NULL)
  OR ((s.id_penyemaian IS NOT NULL OR s.id_perawatan IS NOT NULL) AND s.jenis_stok<>'keluar')
  OR NOT (
    (length(s.tanggal_stok)=19 AND s.tanggal_stok GLOB
      '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
      AND strftime('%Y-%m-%d %H:%M:%S',s.tanggal_stok,'+0 seconds') IS s.tanggal_stok)
    OR (length(s.tanggal_stok)=24 AND s.tanggal_stok GLOB
      '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
      AND strftime('%Y-%m-%dT%H:%M:%fZ',s.tanggal_stok,'+0 seconds') IS s.tanggal_stok)
  ) OR substr(s.tanggal_stok,1,4)='0000';
INSERT INTO _b006_guard SELECT 0 FROM detail_stok GROUP BY id_stok,id_inventaris HAVING count(*)>1;
INSERT INTO _b006_guard SELECT 0 FROM stok WHERE id_penyemaian IS NOT NULL
  GROUP BY id_penyemaian HAVING count(*)>1;
INSERT INTO _b006_guard SELECT 0 FROM stok WHERE id_perawatan IS NOT NULL
  GROUP BY id_perawatan HAVING count(*)>1;
INSERT INTO _b006_guard SELECT 0 FROM inventaris WHERE id_inventaris<1 OR
  typeof(satuan)<>'text' OR length(satuan) NOT BETWEEN 1 AND 30 OR satuan<>trim(satuan,
    char(9,10,11,12,13,32,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,65279));
INSERT INTO _b006_guard SELECT 0 FROM detail_stok WHERE id_detail_stok<1;

-- Inspect canonical stored numeric text, split digits, then use integer arithmetic.
-- A historical NUMERIC affinity value cannot recover the original user keystrokes.
CREATE TABLE _b006_amounts AS
WITH amounts AS (
  SELECT 'detail' AS kind,id_detail_stok AS id,typeof(jumlah) AS storage,
    CAST(jumlah AS TEXT) AS text_value,jumlah AS original FROM detail_stok
  UNION ALL
  SELECT 'minimum',id_inventaris,typeof(stok_minimum),CAST(stok_minimum AS TEXT),stok_minimum
    FROM inventaris WHERE stok_minimum IS NOT NULL
), parts AS (
  SELECT *,CASE WHEN instr(text_value,'.')=0 THEN text_value
    ELSE substr(text_value,1,instr(text_value,'.')-1) END AS whole,
    CASE WHEN instr(text_value,'.')=0 THEN ''
    ELSE substr(text_value,instr(text_value,'.')+1) END AS fraction FROM amounts
)
SELECT *,CAST(whole AS INTEGER)*100+CAST(substr(fraction||'00',1,2) AS INTEGER) AS minor FROM parts;
INSERT INTO _b006_guard SELECT 0 FROM _b006_amounts WHERE
  storage NOT IN ('integer','real') OR length(whole) NOT BETWEEN 1 AND 10
  OR whole GLOB '*[^0-9]*' OR length(fraction)>2 OR fraction GLOB '*[^0-9]*'
  OR (instr(text_value,'.')>0 AND length(fraction)=0)
  OR minor NOT BETWEEN 1 AND 999999999999
  OR CAST(printf('%d.%02d',minor/100,minor%100) AS NUMERIC) IS NOT original;

ALTER TABLE stok ADD COLUMN sealed INTEGER NOT NULL DEFAULT 0
  CHECK(typeof(sealed)='integer' AND sealed IN (0,1));
ALTER TABLE stok ADD COLUMN reversal_of INTEGER REFERENCES stok(id_stok) ON DELETE NO ACTION;
ALTER TABLE detail_stok ADD COLUMN jumlah_minor INTEGER
  CHECK(jumlah_minor IS NULL OR (typeof(jumlah_minor)='integer' AND jumlah_minor BETWEEN 1 AND 999999999999));
ALTER TABLE detail_stok ADD COLUMN satuan TEXT CHECK(satuan IS NULL OR length(satuan) BETWEEN 1 AND 30);
ALTER TABLE inventaris ADD COLUMN stok_minimum_minor INTEGER
  CHECK(stok_minimum_minor IS NULL OR
    (typeof(stok_minimum_minor)='integer' AND stok_minimum_minor BETWEEN 1 AND 999999999999));
UPDATE detail_stok SET
  jumlah_minor=(SELECT minor FROM _b006_amounts WHERE kind='detail' AND id=id_detail_stok),
  satuan=(SELECT i.satuan FROM inventaris i WHERE i.id_inventaris=detail_stok.id_inventaris);
UPDATE inventaris SET stok_minimum_minor=(SELECT minor FROM _b006_amounts
  WHERE kind='minimum' AND id=id_inventaris);

-- Window sums run only after exact bounded line validation. Overflow fails closed.
CREATE TABLE _b006_prefix AS SELECT d.id_inventaris,d.id_stok,d.id_detail_stok,
  sum(CASE s.jenis_stok WHEN 'masuk' THEN d.jumlah_minor ELSE -d.jumlah_minor END)
  OVER (PARTITION BY d.id_inventaris ORDER BY d.id_stok,d.id_detail_stok ROWS UNBOUNDED PRECEDING) AS balance
  FROM detail_stok d JOIN stok s ON s.id_stok=d.id_stok;
INSERT INTO _b006_guard SELECT 0 FROM _b006_prefix WHERE balance NOT BETWEEN 0 AND 999999999999;
CREATE TABLE stok_saldo (
  id_inventaris INTEGER PRIMARY KEY REFERENCES inventaris(id_inventaris) ON DELETE NO ACTION,
  saldo_minor INTEGER NOT NULL CHECK(typeof(saldo_minor)='integer' AND saldo_minor BETWEEN 0 AND 999999999999)
);
INSERT INTO stok_saldo SELECT id_inventaris,balance FROM (
  SELECT *,row_number() OVER (PARTITION BY id_inventaris ORDER BY id_stok DESC,id_detail_stok DESC) AS last_row
  FROM _b006_prefix
) WHERE last_row=1;
UPDATE stok SET sealed=1;

CREATE UNIQUE INDEX idx_detail_stok_header_item ON detail_stok(id_stok,id_inventaris);
CREATE INDEX idx_detail_stok_item_header ON detail_stok(id_inventaris,id_stok);
CREATE UNIQUE INDEX idx_stok_reversal ON stok(reversal_of) WHERE reversal_of IS NOT NULL;
CREATE UNIQUE INDEX idx_stok_sowing_origin ON stok(id_penyemaian) WHERE id_penyemaian IS NOT NULL;
CREATE UNIQUE INDEX idx_stok_care_origin ON stok(id_perawatan) WHERE id_perawatan IS NOT NULL;

-- Preserve existing stock identities, versions, mappings, and receipt JSON verbatim.
INSERT INTO sync_resource_links(resource_type,domain_id,public_id)
SELECT 'stok',CAST(s.id_stok AS TEXT),
  lower(hex(randomblob(4)))||'-'||lower(hex(randomblob(2)))||'-4'||substr(lower(hex(randomblob(2))),2)
  ||'-8'||substr(lower(hex(randomblob(2))),2)||'-'||lower(hex(randomblob(6))) FROM stok s
  WHERE NOT EXISTS (SELECT 1 FROM sync_resource_links l
    WHERE l.resource_type='stok' AND l.domain_id=CAST(s.id_stok AS TEXT));
INSERT INTO sync_resource_versions(resource_type,public_id,version,changed_at)
SELECT 'stok',l.public_id,1,CAST(strftime('%s','now') AS INTEGER)*1000 FROM sync_resource_links l
  WHERE l.resource_type='stok' AND NOT EXISTS (SELECT 1 FROM sync_resource_versions v
    WHERE v.resource_type='stok' AND v.public_id=l.public_id);

CREATE TRIGGER b006_header_insert BEFORE INSERT ON stok BEGIN
  -- REPLACE deletes do not fire DELETE triggers unless recursive_triggers is on.
  SELECT CASE WHEN EXISTS (SELECT 1 FROM stok WHERE id_stok=NEW.id_stok)
    THEN RAISE(ABORT,'STOCK_HEADER_IMMUTABLE') END;
  SELECT CASE WHEN NEW.sealed<>0 OR NEW.jenis_stok NOT IN ('masuk','keluar')
    OR (NEW.id_penyemaian IS NOT NULL AND NEW.id_perawatan IS NOT NULL)
    OR ((NEW.id_penyemaian IS NOT NULL OR NEW.id_perawatan IS NOT NULL)
      AND (NEW.jenis_stok<>'keluar' OR NEW.reversal_of IS NOT NULL))
    THEN RAISE(ABORT,'STOCK_HEADER_INVALID') END;
  SELECT CASE WHEN NEW.reversal_of IS NOT NULL AND (
    NEW.keterangan IS NULL OR length(trim(NEW.keterangan)) NOT BETWEEN 1 AND 1000
    OR NOT EXISTS (SELECT 1 FROM stok o WHERE o.id_stok=NEW.reversal_of AND o.sealed=1
      AND o.reversal_of IS NULL AND o.jenis_stok<>NEW.jenis_stok))
    THEN RAISE(ABORT,'STOCK_REVERSAL_INVALID') END;
END;
CREATE TRIGGER b006_header_update BEFORE UPDATE ON stok BEGIN
  SELECT CASE WHEN OLD.sealed<>0 OR NEW.sealed<>1
    OR NEW.id_stok IS NOT OLD.id_stok OR NEW.id_user IS NOT OLD.id_user
    OR NEW.id_penyemaian IS NOT OLD.id_penyemaian OR NEW.id_perawatan IS NOT OLD.id_perawatan
    OR NEW.tanggal_stok IS NOT OLD.tanggal_stok OR NEW.jenis_stok IS NOT OLD.jenis_stok
    OR NEW.keterangan IS NOT OLD.keterangan OR NEW.reversal_of IS NOT OLD.reversal_of
    OR (SELECT count(*) FROM detail_stok WHERE id_stok=OLD.id_stok) NOT BETWEEN 1 AND 100
    THEN RAISE(ABORT,'STOCK_HEADER_IMMUTABLE') END;
  SELECT CASE WHEN NEW.reversal_of IS NOT NULL AND (
    EXISTS (SELECT id_inventaris,jumlah_minor,satuan FROM detail_stok WHERE id_stok=NEW.reversal_of
      EXCEPT SELECT id_inventaris,jumlah_minor,satuan FROM detail_stok WHERE id_stok=NEW.id_stok)
    OR EXISTS (SELECT id_inventaris,jumlah_minor,satuan FROM detail_stok WHERE id_stok=NEW.id_stok
      EXCEPT SELECT id_inventaris,jumlah_minor,satuan FROM detail_stok WHERE id_stok=NEW.reversal_of))
    THEN RAISE(ABORT,'STOCK_REVERSAL_LINES_INVALID') END;
END;
CREATE TRIGGER b006_header_delete BEFORE DELETE ON stok BEGIN
  SELECT RAISE(ABORT,'STOCK_HEADER_IMMUTABLE');
END;
CREATE TRIGGER b006_detail_insert BEFORE INSERT ON detail_stok BEGIN
  SELECT CASE WHEN EXISTS (SELECT 1 FROM detail_stok WHERE id_detail_stok=NEW.id_detail_stok
    OR (id_stok=NEW.id_stok AND id_inventaris=NEW.id_inventaris))
    THEN RAISE(ABORT,'STOCK_DETAIL_IMMUTABLE') END;
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM stok WHERE id_stok=NEW.id_stok AND sealed=0)
    OR (SELECT count(*) FROM detail_stok WHERE id_stok=NEW.id_stok)>=100
    THEN RAISE(ABORT,'STOCK_HEADER_SEALED') END;
  SELECT CASE WHEN NEW.jumlah_minor IS NULL OR typeof(NEW.jumlah_minor)<>'integer'
    OR NEW.jumlah_minor NOT BETWEEN 1 AND 999999999999
    OR NEW.satuan IS NULL OR typeof(NEW.satuan)<>'text'
    OR NEW.satuan IS NOT (SELECT satuan FROM inventaris WHERE id_inventaris=NEW.id_inventaris)
    OR CAST(printf('%d.%02d',NEW.jumlah_minor/100,NEW.jumlah_minor%100) AS NUMERIC) IS NOT NEW.jumlah
    THEN RAISE(ABORT,'STOCK_DETAIL_INVALID') END;
END;
CREATE TRIGGER b006_detail_update BEFORE UPDATE ON detail_stok BEGIN
  SELECT RAISE(ABORT,'STOCK_DETAIL_IMMUTABLE');
END;
CREATE TRIGGER b006_detail_delete BEFORE DELETE ON detail_stok BEGIN
  SELECT RAISE(ABORT,'STOCK_DETAIL_IMMUTABLE');
END;
CREATE TRIGGER b006_inventory_unit BEFORE UPDATE OF satuan ON inventaris
WHEN NEW.satuan IS NOT OLD.satuan AND EXISTS (
  SELECT 1 FROM detail_stok WHERE id_inventaris=OLD.id_inventaris)
BEGIN SELECT RAISE(ABORT,'UNIT_LOCKED'); END;
CREATE TRIGGER b006_minimum_insert BEFORE INSERT ON inventaris BEGIN
  SELECT CASE WHEN EXISTS (SELECT 1 FROM detail_stok WHERE id_inventaris=NEW.id_inventaris)
    AND NEW.satuan IS NOT (SELECT satuan FROM inventaris WHERE id_inventaris=NEW.id_inventaris)
    THEN RAISE(ABORT,'UNIT_LOCKED') END;
  SELECT CASE WHEN (NEW.stok_minimum IS NULL)<>(NEW.stok_minimum_minor IS NULL)
    OR (NEW.stok_minimum IS NOT NULL AND (typeof(NEW.stok_minimum) NOT IN ('integer','real')
      OR typeof(NEW.stok_minimum_minor)<>'integer' OR NEW.stok_minimum_minor NOT BETWEEN 1 AND 999999999999
      OR CAST(printf('%d.%02d',NEW.stok_minimum_minor/100,NEW.stok_minimum_minor%100) AS NUMERIC) IS NOT NEW.stok_minimum))
    THEN RAISE(ABORT,'STOCK_MINIMUM_INVALID') END;
END;
CREATE TRIGGER b006_minimum_update BEFORE UPDATE ON inventaris BEGIN
  SELECT CASE WHEN (NEW.stok_minimum IS NULL)<>(NEW.stok_minimum_minor IS NULL)
    OR (NEW.stok_minimum IS NOT NULL AND (typeof(NEW.stok_minimum) NOT IN ('integer','real')
      OR typeof(NEW.stok_minimum_minor)<>'integer' OR NEW.stok_minimum_minor NOT BETWEEN 1 AND 999999999999
      OR CAST(printf('%d.%02d',NEW.stok_minimum_minor/100,NEW.stok_minimum_minor%100) AS NUMERIC) IS NOT NEW.stok_minimum))
    THEN RAISE(ABORT,'STOCK_MINIMUM_INVALID') END;
END;
DROP TABLE _b006_prefix;
DROP TABLE _b006_amounts;
DROP TABLE _b006_guard;
