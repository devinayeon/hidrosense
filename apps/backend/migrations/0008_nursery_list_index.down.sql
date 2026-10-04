-- Restore the index shape present before migration 0008.
CREATE INDEX idx_penyemaian_user_date ON penyemaian(id_user, tanggal_semai DESC, id_penyemaian DESC);
DROP INDEX idx_penyemaian_date;
