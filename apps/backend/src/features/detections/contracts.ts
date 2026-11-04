import { z } from 'zod';
import { activeListQuerySchema, expectedVersionSchema, hasChanges, integerIdSchema } from '../../common/validation.js';

export { idParamSchema, parseInput } from '../../common/validation.js';

/** The pests the first model supports. Adding one to the model means adding it here. */
const pestSchema = z.enum(['thrips', 'whitefly', 'aphids']);
const statusSchema = z.enum(['terdeteksi', 'tanpa_deteksi', 'gagal']);

/** Confidence from 0 to 1 with at most 4 decimals, stored exactly as 0..10000. */
export function confidenceToMinor(value: string): number {
  const [whole, fraction = ''] = value.split('.');
  return Number(whole) * 10000 + Number(fraction.padEnd(4, '0'));
}

export function minorToConfidence(minor: number): string {
  return (minor / 10000).toFixed(4);
}

const confidenceSchema = z.string().regex(/^(?:0(?:\.\d{1,4})?|1(?:\.0{1,4})?)$(?![\s\S])/);

const CLOUDINARY_HOST = 'res.cloudinary.com';

function isCloudinaryAsset(image: { public_id: string; url: string }) {
  try {
    const url = new URL(image.url);
    return url.protocol === 'https:' && url.hostname === CLOUDINARY_HOST && !url.username && !url.password
      && url.pathname.includes(image.public_id);
  } catch {
    return false;
  }
}

// The server never fetches this URL. It only refuses device paths and other hosts.
const imageSchema = z.strictObject({
  public_id: z.string().min(1).max(200).regex(/^[\w-]+(?:\/[\w-]+)*$/),
  url: z.string().max(255),
}).refine(isCloudinaryAsset);

const resultSchema = z.strictObject({
  nama_hama: pestSchema,
  confidence: confidenceSchema,
  jumlah_objek: z.number().int().positive().max(100000).default(1),
});

const note = z.string().trim().max(1000).nullable();

export const createDetectionSchema = z.strictObject({
  id_pemindahan: integerIdSchema,
  tanggal_deteksi: z.iso.datetime({ offset: true }),
  status_deteksi: statusSchema,
  model_versi: z.string().trim().min(1).max(50),
  ambang_confidence: confidenceSchema.nullable().optional().transform((value) => value ?? null),
  gambar: imageSchema.nullable().optional().transform((value) => value ?? null),
  keterangan: note.optional().transform((value) => value ?? null),
  hasil: z.array(resultSchema).max(20),
})
  .refine((value) => (value.status_deteksi === 'terdeteksi') === (value.hasil.length > 0))
  .refine((value) => new Set(value.hasil.map((row) => row.nama_hama)).size === value.hasil.length)
  .refine((value) => value.ambang_confidence === null || value.hasil.every(
    (row) => confidenceToMinor(row.confidence) >= confidenceToMinor(value.ambang_confidence!),
  ));

/** Results are a record of what the model said, so only the image and the note can change. */
export const updateDetectionSchema = z.strictObject({
  expected_version: expectedVersionSchema,
  gambar: imageSchema.optional(),
  keterangan: note.optional(),
}).refine(hasChanges);

export const listDetectionQuerySchema = z.strictObject({
  page: activeListQuerySchema.shape.page,
  limit: activeListQuerySchema.shape.limit,
  id_pemindahan: integerIdSchema.optional(),
  status_deteksi: statusSchema.optional(),
});

export const emptyQuerySchema = z.strictObject({});

export type CreateDetectionInput = z.infer<typeof createDetectionSchema>;
export type UpdateDetectionInput = z.infer<typeof updateDetectionSchema>;
export type ListDetectionQuery = z.infer<typeof listDetectionQuerySchema>;
