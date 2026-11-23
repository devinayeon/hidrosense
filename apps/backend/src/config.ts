import { z } from 'zod';
import { isIP } from 'node:net';

/** Baris `NAMA=` kosong di .env dianggap tidak diisi, bukan nilai tidak valid. */
const blankIsUnset = <T extends z.ZodType>(schema: T) =>
  z.preprocess((value) => (value === '' ? undefined : value), schema.optional());

const environmentSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().min(1).regex(/^[a-zA-Z0-9.:-]+$/).default('127.0.0.1'),
  PORT: z.string().regex(/^\d+$/).default('3000').transform(Number).pipe(z.number().int().min(1).max(65535)),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  CORS_ORIGINS: z.string().default(''),
  TRUSTED_PROXIES: z.string().default(''),
  TRUST_PROXY_HOPS: z.string().regex(/^[1-9]$/).transform(Number).optional(),
  // Unggah foto. Ketiganya diisi bersama atau dikosongkan bersama.
  CLOUDINARY_CLOUD_NAME: blankIsUnset(z.string().regex(/^[a-zA-Z0-9_-]{1,64}$/)),
  CLOUDINARY_API_KEY: blankIsUnset(z.string().regex(/^[0-9]{6,20}$/)),
  CLOUDINARY_API_SECRET: blankIsUnset(z.string().min(8).max(128)),
});

export function readConfig(env: Record<string, string | undefined> = process.env) {
  const result = environmentSchema.safeParse(env);
  if (!result.success) {
    throw new Error(`Invalid configuration: ${result.error.issues.map((issue) => issue.path.join('.')).join(', ')}`);
  }
  const parsed = result.data;
  const origins = parsed.CORS_ORIGINS.split(',').map((value) => value.trim()).filter(Boolean);
  for (const origin of origins) {
    let url: URL;
    try { url = new URL(origin); } catch { throw new Error('Invalid configuration: CORS_ORIGINS'); }
    if (!['http:', 'https:'].includes(url.protocol) || url.origin !== origin ||
      (parsed.NODE_ENV === 'production' && url.protocol !== 'https:')) {
      throw new Error('Invalid configuration: CORS_ORIGINS requires exact origins (HTTPS in production).');
    }
  }
  const proxies = parsed.TRUSTED_PROXIES.split(',').map((value) => value.trim()).filter(Boolean);
  for (const proxy of proxies) {
    const [address, prefix, extra] = proxy.split('/');
    const version = isIP(address);
    if (!version || extra !== undefined || (prefix !== undefined &&
      (!/^\d+$/.test(prefix) || Number(prefix) > (version === 4 ? 32 : 128)))) {
      throw new Error('Invalid configuration: TRUSTED_PROXIES requires IP addresses or CIDRs.');
    }
  }
  if (parsed.TRUST_PROXY_HOPS !== undefined && proxies.length) {
    throw new Error('Invalid configuration: set TRUST_PROXY_HOPS or TRUSTED_PROXIES, not both.');
  }
  const cloudinaryFields = [parsed.CLOUDINARY_CLOUD_NAME, parsed.CLOUDINARY_API_KEY, parsed.CLOUDINARY_API_SECRET];
  // Setengah terisi: production gagal start; di dev/test unggah nonaktif (503) supaya server tetap jalan.
  if (cloudinaryFields.some(Boolean) && !cloudinaryFields.every(Boolean) && parsed.NODE_ENV === 'production') {
    throw new Error('Invalid configuration: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET must be set together.');
  }
  const cloudinary = parsed.CLOUDINARY_CLOUD_NAME && parsed.CLOUDINARY_API_KEY && parsed.CLOUDINARY_API_SECRET
    ? { cloudName: parsed.CLOUDINARY_CLOUD_NAME, apiKey: parsed.CLOUDINARY_API_KEY, apiSecret: parsed.CLOUDINARY_API_SECRET }
    : null;
  return {
    environment: parsed.NODE_ENV, host: parsed.HOST, port: parsed.PORT,
    logLevel: parsed.LOG_LEVEL, origins, proxies, proxyHops: parsed.TRUST_PROXY_HOPS, cloudinary,
  };
}

export type AppConfig = ReturnType<typeof readConfig>;
