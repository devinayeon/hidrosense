import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto';

const N = 32768;
const r = 8;
const p = 3;

function derive(password: string, salt: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scrypt(password, salt, 64, { N, r, p, maxmem: 64 * 1024 * 1024 }, (error, key) => {
      if (error) reject(error); else resolve(key);
    });
  });
}

export async function hashPassword(password: string) {
  const salt = randomBytes(16).toString('hex');
  const key = await derive(password, salt);
  return `scrypt$${N}$${r}$${p}$${salt}$${key.toString('hex')}`;
}

const dummySalt = '0'.repeat(32);

export async function verifyPassword(password: string, encoded: string) {
  const match = /^scrypt\$32768\$8\$3\$([a-f0-9]{32})\$([a-f0-9]{128})$/.exec(encoded);
  // Unknown users and unsupported hashes still pay the password derivation cost.
  const actual = await derive(password, match?.[1] ?? dummySalt);
  const expected = match ? Buffer.from(match[2], 'hex') : Buffer.alloc(64);
  return timingSafeEqual(actual, expected) && Boolean(match);
}
