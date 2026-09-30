import { z } from 'zod';
import { isIP } from 'node:net';

const environmentSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().min(1).regex(/^[a-zA-Z0-9.:-]+$/).default('127.0.0.1'),
  PORT: z.string().regex(/^\d+$/).default('3000').transform(Number).pipe(z.number().int().min(1).max(65535)),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  CORS_ORIGINS: z.string().default(''),
  TRUSTED_PROXIES: z.string().default(''),
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
  return {
    environment: parsed.NODE_ENV, host: parsed.HOST, port: parsed.PORT,
    logLevel: parsed.LOG_LEVEL, origins, proxies,
  };
}

export type AppConfig = ReturnType<typeof readConfig>;
