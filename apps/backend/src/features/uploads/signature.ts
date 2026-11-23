import { createHash } from 'node:crypto';

/**
 * Tanda tangan unggahan Cloudinary: parameter diurutkan menurut nama, digabung `k=v` dengan `&`,
 * ditambah api_secret di belakang, lalu SHA-1 heksadesimal. Hanya parameter yang ikut ditandatangani
 * yang boleh dikirim klien, jadi klien tidak bisa menambah folder atau transformasi sendiri.
 */
export function signCloudinaryParams(params: Readonly<Record<string, string | number>>, apiSecret: string) {
  const toSign = Object.keys(params)
    .sort()
    .map((key) => `${key}=${params[key]}`)
    .join('&');
  return createHash('sha1').update(toSign + apiSecret).digest('hex');
}
