ALTER TABLE jenis_inventaris
ADD COLUMN status_aktif INTEGER NOT NULL DEFAULT 1 CHECK (status_aktif IN (0, 1));

CREATE INDEX idx_jenis_inventaris_status ON jenis_inventaris(status_aktif);
