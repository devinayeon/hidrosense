import { z } from 'zod';
import { ApiError, type ErrorDetail } from './errors.js';

export const integerIdSchema = z.string().regex(/^[1-9][0-9]{0,18}$(?![\s\S])/)
  .pipe(z.string().refine((value) => BigInt(value) <= 9223372036854775807n));
export const uuidSchema = z.string().uuid();
export const clientUuidSchema = uuidSchema.transform((value) => value.toLowerCase());
export const idParamSchema = z.strictObject({ id: integerIdSchema });
/** Rute tanpa parameter query: yang tidak dikenal ditolak 400, sesuai kontrak di API.md. */
export const emptyQuerySchema = z.strictObject({});
export const expectedVersionSchema = integerIdSchema.optional();
/** A PATCH body must change something; the version it was based on is not a change. */
export const hasChanges = (value: object) => Object.keys(value).some((key) => key !== 'expected_version');
export const pageQuerySchema = z.strictObject({
  page: z.string().regex(/^[1-9][0-9]{0,5}$(?![\s\S])/).default('1').transform(Number),
  limit: z.string().regex(/^[1-9][0-9]{0,2}$(?![\s\S])/).default('20').transform(Number)
    .refine((value) => value <= 100),
});
export const activeListQuerySchema = pageQuerySchema.extend({
  status_aktif: z.enum(['0', '1']).optional(),
});

/**
 * Satu bentuk baku untuk username: NFC, lalu huruf kecil. Daftar, ubah, bootstrap, dan login
 * semuanya lewat sini, jadi 'Budi', 'budi', dan 'BUDI' satu akun, begitu juga é yang disusun
 * satu kodepoin atau dua. Kolom `username` menyimpan bentuk baku itu; UNIQUE di database
 * menjaga keunikannya dan migrasi 0017 menolak penulisan lain.
 */
export const canonicalUsername = (value: string) => value.normalize('NFC').toLowerCase().normalize('NFC');

// Karakter kontrol, format (lebar nol, pembalik arah), pemisah baris, dan spasi selain ' ' membuat
// dua username tampak sama di layar padahal berbeda, atau tak terlihat sama sekali.
// Huruf "kosong" (pengisi Hangul, braille kosong, grapheme joiner) bukan spasi dan bukan karakter
// format menurut Unicode, tetapi di layar tampak sebagai ruang kosong, jadi daftarnya eksplisit.
const hiddenCharacters = /[\p{C}\p{Zl}\p{Zp}]|[^\S ]|[͏ᅟᅠ⠀ㅤﾠ]/u;
const isPlainUsername = (value: string) => !hiddenCharacters.test(value) && !value.includes('  ')
  && value === value.trim();

/** Username untuk penulisan: dibakukan dulu, baru dibatasi 1–50 karakter tanpa karakter tersembunyi. */
export const usernameSchema = z.string().min(1).max(200).transform(canonicalUsername)
  .pipe(z.string().min(1).max(50).refine(isPlainUsername));

/** Password baru: 6–128 karakter dan memuat minimal satu karakter yang terlihat. */
export const newPasswordSchema = z.string().min(6).max(128).refine((value) => /\S/u.test(value));

/** Satu baris teks tampak, misalnya nama: tanpa karakter kontrol, tak terlihat, atau spasi selain ' '. */
export const plainLine = (max: number) => z.string().trim().min(1).max(max)
  .refine((value) => !hiddenCharacters.test(value));

/** Teks beberapa baris, misalnya alamat: baris baru dan tab sah, karakter tersembunyi lain tidak. */
export const plainText = (max: number) => z.string().trim().min(1).max(max)
  .refine((value) => !hiddenCharacters.test(value.replace(/[\n\r\t]/g, '')));

/**
 * Kolom pilihan: string kosong atau hanya spasi berarti "kosongkan" dan disimpan sebagai null,
 * sama seperti mengirim null. Tanpa ini, formulir yang mengirim "" untuk kolom kosong ditolak.
 */
export const clearable = <T extends z.ZodType>(schema: T) => z.preprocess(
  (value) => (typeof value === 'string' && value.trim() === '' ? null : value),
  schema.nullable(),
).optional();

/** Email dibakukan huruf kecil supaya keunikannya tidak bergantung pada huruf besar kecil. */
export const emailSchema = z.string().trim().max(100).email().transform((value) => value.toLowerCase());

const MAX_DETAILS = 20;

/** Indonesian, value-free text for one zod issue. Never includes what the client sent. */
function issueMessage(issue: z.core.$ZodIssue): string {
  switch (issue.code) {
    case 'too_big': {
      const max = Number(issue.maximum);
      return issue.origin === 'string' ? `Maksimal ${max} karakter.`
        : issue.origin === 'array' ? `Maksimal ${max} item.` : `Maksimal ${max}.`;
    }
    case 'too_small': {
      const min = Number(issue.minimum);
      if (issue.origin === 'string' || issue.origin === 'array') {
        return min <= 1 ? 'Wajib diisi.' : `Minimal ${min} ${issue.origin === 'string' ? 'karakter' : 'item'}.`;
      }
      return issue.inclusive === false ? `Harus lebih dari ${min}.` : `Minimal ${min}.`;
    }
    case 'invalid_type': return /received undefined/.test(issue.message) ? 'Wajib diisi.' : 'Tipe data tidak sesuai.';
    case 'invalid_format': return 'Format tidak valid.';
    case 'invalid_value': return 'Nilai tidak dikenal.';
    default: return 'Nilai tidak valid.';
  }
}

/** Field-level details of a failed parse: one entry per problem, capped, unknown fields listed by name. */
export function validationDetails(error: z.ZodError): ErrorDetail[] {
  const details: ErrorDetail[] = [];
  for (const issue of error.issues) {
    const base = issue.path.map(String);
    if (issue.code === 'unrecognized_keys') {
      for (const key of issue.keys) details.push({ field: [...base, key].join('.'), message: 'Field tidak dikenal.' });
    } else {
      details.push({ field: base.join('.') || '_', message: issueMessage(issue) });
    }
    if (details.length >= MAX_DETAILS) break;
  }
  return details.slice(0, MAX_DETAILS);
}

export function parseInput<T>(schema: z.ZodType<T>, input: unknown): T {
  const result = schema.safeParse(input);
  if (!result.success) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Input tidak sesuai kontrak API.', validationDetails(result.error));
  }
  return result.data;
}

/**
 * Every write carries a client-generated UUID so a retry replays the stored receipt
 * instead of applying the same change twice. Required by all write endpoints.
 */
export function requireIdempotencyKey(headers: Record<string, string | string[] | undefined>): string {
  const parsed = uuidSchema.safeParse(headers['idempotency-key']);
  if (!parsed.success) throw new ApiError(400, 'VALIDATION_ERROR', 'Header sinkronisasi tidak valid.');
  return parsed.data;
}
