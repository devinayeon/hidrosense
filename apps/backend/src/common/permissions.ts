// System Request controls permissions; pegawai has panen access, never penjualan.
const commonReads = ['inventaris:read', 'penyemaian:read', 'budidaya:read', 'panen:read'];
export const rolePermissions: Readonly<Record<string, readonly string[]>> = Object.freeze({
  petani: Object.freeze([
    ...commonReads, 'pegawai:manage', 'profil:read', 'profil:write',
    'penjualan:read', 'penjualan:write', 'deteksi:read', 'deteksi:write',
    'rekomendasi:read', 'rekomendasi:decide', 'perawatan:read', 'perawatan:write',
    'cuaca:read',
  ]),
  pegawai: Object.freeze([
    ...commonReads, 'inventaris:write', 'penyemaian:write', 'budidaya:write', 'panen:write',
  ]),
});

export function permissionsFor(role: string): readonly string[] {
  return Object.hasOwn(rolePermissions, role) ? rolePermissions[role] : [];
}
