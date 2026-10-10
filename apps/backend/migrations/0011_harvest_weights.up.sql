ALTER TABLE detail_panen ADD COLUMN berat_minor INTEGER CHECK (berat_minor IS NULL OR (typeof(berat_minor)='integer' AND berat_minor BETWEEN 0 AND 9999999999));
ALTER TABLE detail_panen ADD COLUMN berat_reject_minor INTEGER CHECK (berat_reject_minor IS NULL OR (typeof(berat_reject_minor)='integer' AND berat_reject_minor BETWEEN 0 AND 9999999999));
CREATE INDEX idx_panen_date_id ON panen(tanggal_panen DESC,id_panen DESC);
