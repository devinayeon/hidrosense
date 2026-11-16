-- Username disimpan dalam bentuk baku (NFC dan huruf kecil), jadi 'Budi' dan 'budi' satu akun.
-- UPDATE gagal karena UNIQUE bila dua username hanya berbeda huruf besar kecil; migrasi berhenti
-- dan tidak ada yang berubah. Selesaikan dulu duplikatnya, lalu jalankan ulang.
-- Sebelum menjalankan di database nyata, lihat yang akan berubah atau bentrok:
--   SELECT username FROM users WHERE username<>lower(username) OR username GLOB '*[^ -~]*';
-- lower() di SQLite hanya mengenal ASCII. Username non-ASCII lama tidak diubah di sini;
-- aplikasi membakukannya saat login dan saat penulisan berikutnya.
UPDATE users SET username=lower(username) WHERE username<>lower(username);

CREATE TRIGGER trg_users_username_lower_insert BEFORE INSERT ON users
WHEN NEW.username<>lower(NEW.username)
BEGIN
  SELECT RAISE(ABORT, 'username must be lowercase');
END;

CREATE TRIGGER trg_users_username_lower_update BEFORE UPDATE OF username ON users
WHEN NEW.username<>lower(NEW.username)
BEGIN
  SELECT RAISE(ABORT, 'username must be lowercase');
END;
