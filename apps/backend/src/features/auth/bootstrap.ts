import type { Client } from '@libsql/client';
import { z } from 'zod';
import { hashPassword } from '../../common/passwords.js';
import { ApiError } from '../../common/errors.js';

const schema = z.object({
  username: z.string().min(1).max(50).regex(/^\S+$/),
  nama: z.string().trim().min(1).max(100),
  password: z.string().min(12).max(128),
}).strict();

export async function bootstrapPetani(db: Client, input: unknown) {
  const parsed = schema.safeParse(input);
  if (!parsed.success) throw new ApiError(400, 'INVALID_BOOTSTRAP', 'Isi username, nama, dan password 12–128 karakter yang valid.');
  const { username, nama, password } = parsed.data;
  const hash = await hashPassword(password);
  const tx = await db.transaction('write');
  try {
    const existing = await tx.execute("SELECT 1 FROM users u JOIN roles r ON r.id_role=u.id_role WHERE r.nama_role='petani' LIMIT 1");
    if (existing.rows.length) throw new ApiError(409, 'ALREADY_BOOTSTRAPPED', 'Akun petani sudah ada. Bootstrap tidak mengubah akun lama.');
    const duplicate = await tx.execute({ sql: 'SELECT 1 FROM users WHERE username=?', args: [username] });
    if (duplicate.rows.length) throw new ApiError(409, 'USERNAME_EXISTS', 'Username sudah digunakan.');
    await tx.execute("INSERT INTO roles (nama_role) VALUES ('petani'),('pegawai') ON CONFLICT(nama_role) DO NOTHING");
    const result = await tx.execute({
      sql: `INSERT INTO users (id_role,nama,username,password)
        SELECT id_role,?,?,? FROM roles WHERE nama_role='petani' RETURNING CAST(id_user AS TEXT) AS id_user,nama,username`,
      args: [nama, username, hash],
    });
    await tx.commit();
    return { id_user: result.rows[0].id_user, nama, username };
  } catch (error) {
    if (!tx.closed) await tx.rollback();
    throw error;
  } finally { tx.close(); }
}
