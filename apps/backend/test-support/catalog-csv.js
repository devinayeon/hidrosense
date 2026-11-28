// Bentuk CSV dataset obat (docs/data/obat-selada.csv), diturunkan dari database hasil migrasi.
const kolom = [
  'bahan_aktif', 'jenis', 'kode_moa', 'hama', 'phi_hari', 'phi_sumber', 'boleh_direkomendasikan',
  'status_registrasi', 'catatan_registrasi', 'catatan', 'sumber', 'terverifikasi',
];

const sel = (v) => {
  if (v === null || v === undefined) return '';
  const s = String(v);
  return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
};

export async function katalogCsv(db) {
  const rows = (await db.execute(`SELECT k.*,
      (SELECT group_concat(kode_hama, ';') FROM
        (SELECT kode_hama FROM katalog_hama WHERE id_katalog = k.id_katalog ORDER BY kode_hama)) AS hama
    FROM obat_katalog k ORDER BY k.bahan_aktif`)).rows;
  return `${[kolom.join(','), ...rows.map((r) => kolom.map((c) => sel(r[c])).join(','))].join('\n')}\n`;
}
