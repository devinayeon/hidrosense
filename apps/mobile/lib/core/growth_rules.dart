// Salinan aturan waktu budidaya untuk umpan balik cepat di formulir.
// Server yang memutuskan (apps/backend/src/common/growth-rules.ts); ubah keduanya bersamaan.

/// HSS (Hari Setelah Semai) minimal sebelum bibit boleh dipindah ke meja tanam.
const int minTransferAgeDays = 15;

/// Estimasi panen dihitung dari tanggal pindah ke meja tanam.
const int growthDaysOnTable = 45;
