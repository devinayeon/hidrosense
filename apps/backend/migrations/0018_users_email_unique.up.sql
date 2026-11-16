-- Email akun harus unik tanpa membedakan huruf besar kecil. Kolom NULL boleh banyak.
-- Aplikasi sudah menyimpan email dalam huruf kecil; baris lama disamakan dulu di sini.
-- Bila dua akun sudah memakai email yang sama, CREATE UNIQUE INDEX gagal dan migrasi berhenti
-- tanpa mengubah apa pun. Cari duplikatnya lebih dulu:
--   SELECT lower(email), COUNT(*) FROM users WHERE email IS NOT NULL GROUP BY 1 HAVING COUNT(*)>1;
-- Catatan 0017: lower() SQLite hanya mengenal ASCII, jadi username non-ASCII lama tidak
-- dibakukan oleh 0017. Database yang masih kosong tidak terpengaruh.
UPDATE users SET email=lower(email) WHERE email IS NOT NULL AND email<>lower(email);

CREATE UNIQUE INDEX idx_users_email_lower ON users (lower(email)) WHERE email IS NOT NULL;
