import { z } from 'zod';
import { expectedVersionSchema, hasChanges, integerIdSchema as intId } from '../../common/validation.js';
import { positiveDecimalSchema as positiveDecimal } from '../../common/quantities.js';
export { idParamSchema, activeListQuerySchema as listQuerySchema, emptyQuerySchema, parseInput } from '../../common/validation.js';

export const createJenisSchema = z.strictObject({
  nama_jenis: z.string().trim().min(1).max(50),
});

export const updateJenisSchema = createJenisSchema.extend({ expected_version: expectedVersionSchema });

export const createObatSchema = z.strictObject({
  nama_obat: z.string().trim().min(1).max(100),
  jenis_obat: z.string().trim().min(1).max(50).nullable().optional(),
  dosis: z.string().trim().min(1).max(100).nullable().optional(),
  aturan_penggunaan: z.string().trim().min(1).nullable().optional(),
  deskripsi: z.string().trim().min(1).nullable().optional(),
});

export const updateObatSchema = createObatSchema.partial()
  .extend({ expected_version: expectedVersionSchema }).refine(hasChanges);

/**
 * Satu barang hanya boleh tertaut ke salah satu sumber obat: master milik
 * pengguna (`id_obat`) atau katalog bawaan (`id_katalog`).
 */
const atMostOneMedicine = (value: { id_obat?: string | null; id_katalog?: string | null }) =>
  value.id_obat == null || value.id_katalog == null;

const inventarisFields = z.strictObject({
  id_jenis_inventaris: intId,
  id_obat: intId.nullable().optional(),
  id_katalog: intId.nullable().optional(),
  // Wajib untuk barang non-obat; bila `id_katalog` diisi, server menurunkan nama
  // dari `obat_katalog.bahan_aktif` supaya kolom "Nama barang" tidak perlu diisi.
  nama_barang: z.string().trim().min(1).max(100).optional(),
  satuan: z.string().trim().min(1).max(30),
  stok_minimum: positiveDecimal.nullable().optional(),
});

export const createInventarisSchema = inventarisFields
  .refine((value) => value.nama_barang !== undefined || value.id_katalog != null, {
    path: ['nama_barang'], message: 'Isi nama barang atau pilih obat.',
  })
  .refine(atMostOneMedicine, {
    path: ['id_katalog'], message: 'Pilih satu sumber obat saja.',
  });

export const updateInventarisSchema = inventarisFields.partial()
  .extend({ expected_version: expectedVersionSchema }).refine(hasChanges)
  .refine(atMostOneMedicine, {
    path: ['id_katalog'], message: 'Pilih satu sumber obat saja.',
  });
