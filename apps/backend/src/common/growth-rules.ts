/**
 * Aturan waktu budidaya selada. Server yang berwenang; aplikasi menyalinnya di
 * apps/mobile/lib/core/growth_rules.dart hanya untuk umpan balik cepat di formulir.
 */

/** HSS (Hari Setelah Semai) minimal sebelum bibit boleh dipindah ke meja tanam. */
export const MIN_TRANSFER_AGE_DAYS = 15;

/**
 * Estimasi panen dihitung dari tanggal pindah ke meja tanam. Bibit yang pindah tepat
 * di hari ke-15 dipanen pada hari ke-60 sejak semai; pindah lebih lambat ikut menggeser.
 */
export const GROWTH_DAYS_ON_TABLE = 45;
