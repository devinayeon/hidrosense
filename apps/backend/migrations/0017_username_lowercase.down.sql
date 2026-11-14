-- Hanya melepas penjaga. Huruf besar yang sudah diubah menjadi kecil tidak dikembalikan.
DROP TRIGGER IF EXISTS trg_users_username_lower_update;
DROP TRIGGER IF EXISTS trg_users_username_lower_insert;
