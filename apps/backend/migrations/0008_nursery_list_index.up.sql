-- Replace the B007 user-leading index with one matching the cross-user list order.
CREATE INDEX idx_penyemaian_date ON penyemaian(tanggal_semai DESC, id_penyemaian DESC);
DROP INDEX idx_penyemaian_user_date;
