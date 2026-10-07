import type { Client } from '@libsql/client';
import { hashPassword } from '../common/passwords.js';

export const SEED_CREDENTIALS = {
  petani: {
    username: 'petani',
    password: 'Petani123456!',
    nama: 'Budi Petani Hidroponik',
    email: 'petani@hidrosense.id',
    no_telepon: '081234567890',
    alamat: 'Jl. Ambulu No. 12, Jember',
    role: 'petani',
  },
  pegawai: {
    username: 'pegawai',
    password: 'Pegawai123456!',
    nama: 'Siti Pegawai Kebun',
    email: 'pegawai@hidrosense.id',
    no_telepon: '081298765432',
    alamat: 'Jl. Selada Sejahtera No. 5, Jember',
    role: 'pegawai',
  },
} as const;

const dayMs = 24 * 60 * 60 * 1000;

export async function seed(db: Client, options: { clock?: () => number } = {}) {
  const clock = options.clock ?? Date.now;
  const now = clock();
  const today = new Date(now + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const dateOffset = (days: number) =>
    new Date(Date.parse(`${today}T00:00:00Z`) + days * dayMs).toISOString().slice(0, 10);

  const petaniHash = await hashPassword(SEED_CREDENTIALS.petani.password);
  const pegawaiHash = await hashPassword(SEED_CREDENTIALS.pegawai.password);

  const tx = await db.transaction('write');
  try {
    // 1. Clear transient auth rate limits to ensure test logins succeed
    await tx.executeMultiple(`
      DELETE FROM auth_rate_limits;
    `);

    // 2. Seed Roles (idempotent via ON CONFLICT)
    await tx.executeMultiple(`
      INSERT INTO roles (id_role, nama_role) VALUES (1, 'petani')
        ON CONFLICT(id_role) DO NOTHING;
      INSERT INTO roles (id_role, nama_role) VALUES (2, 'pegawai')
        ON CONFLICT(id_role) DO NOTHING;
    `);

    // 3. Test Users across all active roles (petani & pegawai)
    await tx.execute({
      sql: `INSERT INTO users (id_user, id_role, nama, username, password, email, no_telepon, alamat, status_aktif)
        VALUES (1, 1, ?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(username) DO UPDATE SET
          nama=excluded.nama, password=excluded.password, email=excluded.email,
          no_telepon=excluded.no_telepon, alamat=excluded.alamat, status_aktif=1`,
      args: [
        SEED_CREDENTIALS.petani.nama, SEED_CREDENTIALS.petani.username, petaniHash,
        SEED_CREDENTIALS.petani.email, SEED_CREDENTIALS.petani.no_telepon, SEED_CREDENTIALS.petani.alamat,
      ],
    });
    await tx.execute({
      sql: `INSERT INTO users (id_user, id_role, nama, username, password, email, no_telepon, alamat, status_aktif)
        VALUES (2, 2, ?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(username) DO UPDATE SET
          nama=excluded.nama, password=excluded.password, email=excluded.email,
          no_telepon=excluded.no_telepon, alamat=excluded.alamat, status_aktif=1`,
      args: [
        SEED_CREDENTIALS.pegawai.nama, SEED_CREDENTIALS.pegawai.username, pegawaiHash,
        SEED_CREDENTIALS.pegawai.email, SEED_CREDENTIALS.pegawai.no_telepon, SEED_CREDENTIALS.pegawai.alamat,
      ],
    });

    // 4. B005 Master: Jenis Inventaris, Obat, Inventaris
    await tx.executeMultiple(`
      INSERT INTO jenis_inventaris (id_jenis_inventaris, nama_jenis, status_aktif) VALUES
        (1, 'Benih', 1),
        (2, 'Nutrisi', 1),
        (3, 'Obat & Pestisida', 1),
        (4, 'Perlengkapan', 1)
        ON CONFLICT(id_jenis_inventaris) DO UPDATE SET
          nama_jenis=excluded.nama_jenis, status_aktif=excluded.status_aktif;

      INSERT INTO obat (id_obat, nama_obat, jenis_obat, dosis, aturan_penggunaan, deskripsi, status_aktif) VALUES
        (1, 'Abamectin 18 EC', 'Insektisida', '0.5 ml/L', 'Semprot daun sore hari', 'Pengendali thrips dan kutu daun', 1),
        (2, 'Imidakloprid 200 SL', 'Insektisida', '0.75 ml/L', 'Semprot saat ada kutu', 'Pengendali wereng dan kutu kebul', 1),
        (3, 'Mancozeb 80 WP', 'Fungisida', '1.5 g/L', 'Semprot saat lembap tinggi', 'Pencegah busuk daun dan bercak daun', 1)
        ON CONFLICT(id_obat) DO UPDATE SET
          nama_obat=excluded.nama_obat, jenis_obat=excluded.jenis_obat, dosis=excluded.dosis,
          aturan_penggunaan=excluded.aturan_penggunaan, deskripsi=excluded.deskripsi, status_aktif=excluded.status_aktif;

      INSERT INTO inventaris (id_inventaris, id_jenis_inventaris, id_obat, nama_barang, satuan, stok_minimum, stok_minimum_minor, status_aktif) VALUES
        (1, 1, NULL, 'Benih Selada Romaine', 'gram', 100, 10000, 1),
        (2, 1, NULL, 'Benih Selada Butterhead', 'gram', 100, 10000, 1),
        (3, 2, NULL, 'Nutrisi AB Mix Sayuran Daun', 'liter', 20, 2000, 1),
        (4, 3, 1, 'Insektisida Abamectin', 'botol', 5, 500, 1),
        (5, 4, NULL, 'Rockwool Semai Standar', 'lembar', 10, 1000, 1)
        ON CONFLICT(id_inventaris) DO UPDATE SET
          id_jenis_inventaris=excluded.id_jenis_inventaris, id_obat=excluded.id_obat,
          nama_barang=excluded.nama_barang, satuan=excluded.satuan, stok_minimum=excluded.stok_minimum,
          stok_minimum_minor=excluded.stok_minimum_minor, status_aktif=excluded.status_aktif;
    `);

    // 5. B006 Initial Incoming Stock Ledger (Sealed) - Guard against immutable re-insert
    const existingStock = await tx.execute({
      sql: 'SELECT id_stok FROM stok WHERE id_stok = 1',
      args: [],
    });
    if (existingStock.rows.length === 0) {
      await tx.execute({
        sql: `INSERT INTO stok (id_stok, id_user, tanggal_stok, jenis_stok, keterangan, sealed)
          VALUES (1, 2, ?, 'masuk', 'Stok Awal Inventaris Kebun', 0)`,
        args: [`${today} 08:00:00`],
      });
      await tx.executeMultiple(`
        INSERT INTO detail_stok (id_detail_stok, id_stok, id_inventaris, jumlah, jumlah_minor, satuan) VALUES
          (1, 1, 1, 1000, 100000, 'gram'),
          (2, 1, 2, 800, 80000, 'gram'),
          (3, 1, 3, 100, 10000, 'liter'),
          (4, 1, 4, 20, 2000, 'botol'),
          (5, 1, 5, 50, 5000, 'lembar');
        UPDATE stok SET sealed = 1 WHERE id_stok = 1;
        INSERT INTO stok_saldo (id_inventaris, saldo_minor) VALUES
          (1, 100000), (2, 80000), (3, 10000), (4, 2000), (5, 5000)
          ON CONFLICT(id_inventaris) DO UPDATE SET saldo_minor=excluded.saldo_minor;
      `);
    }

    // 6. B007 Nursery (Penyemaian)
    // Sowing 1: 20 days ago (ready for transfer), Sowing 2: 5 days ago (young)
    const semai1Date = dateOffset(-20);
    const semai2Date = dateOffset(-5);
    await tx.execute({
      sql: `INSERT INTO penyemaian (id_penyemaian, id_user, tanggal_semai, jumlah_benih, status_penyemaian, keterangan) VALUES
        (1, 2, ?, 600, 'aktif', 'Semai Selada Romaine Batch A'),
        (2, 2, ?, 400, 'aktif', 'Semai Butterhead Batch B')
        ON CONFLICT(id_penyemaian) DO UPDATE SET
          id_user=excluded.id_user, tanggal_semai=excluded.tanggal_semai,
          jumlah_benih=excluded.jumlah_benih, status_penyemaian=excluded.status_penyemaian,
          keterangan=excluded.keterangan`,
      args: [semai1Date, semai2Date],
    });

    // 7. B008 Meja Tanam NFT
    await tx.executeMultiple(`
      INSERT INTO meja_tanam (id_meja, kode_meja, jumlah_lubang, status_meja, keterangan) VALUES
        (1, 'M-01', 250, 'tersedia', 'Meja NFT Blok A1'),
        (2, 'M-02', 250, 'tersedia', 'Meja NFT Blok A2'),
        (3, 'M-03', 250, 'tersedia', 'Meja NFT Blok B1'),
        (4, 'M-04', 200, 'perbaikan', 'Meja NFT Blok B2 dalam perbaikan')
        ON CONFLICT(id_meja) DO UPDATE SET
          kode_meja=excluded.kode_meja, jumlah_lubang=excluded.jumlah_lubang,
          status_meja=excluded.status_meja, keterangan=excluded.keterangan;
    `);

    // 8. B009 Seedling Transfer (Pemindahan Bibit)
    // Transferred on day 15 after sowing (i.e. dateOffset(-5))
    const pindah1Date = dateOffset(-5);
    await tx.execute({
      sql: `INSERT INTO pemindahan (id_pemindahan, id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman, keterangan)
        VALUES (1, 1, 1, ?, 200, 'Pindah 200 bibit Romaine ke Meja M-01')
        ON CONFLICT(id_pemindahan) DO UPDATE SET
          id_penyemaian=excluded.id_penyemaian, id_meja=excluded.id_meja,
          tanggal_pemindahan=excluded.tanggal_pemindahan, jumlah_tanaman=excluded.jumlah_tanaman,
          keterangan=excluded.keterangan`,
      args: [pindah1Date],
    });

    // 9. Sync resource links & versions
    const syncResources: [string, string, string][] = [
      ['jenis-inventaris', '1', '10000000-0000-4000-8000-000000000001'],
      ['jenis-inventaris', '2', '10000000-0000-4000-8000-000000000002'],
      ['jenis-inventaris', '3', '10000000-0000-4000-8000-000000000003'],
      ['jenis-inventaris', '4', '10000000-0000-4000-8000-000000000004'],
      ['obat', '1', '20000000-0000-4000-8000-000000000001'],
      ['obat', '2', '20000000-0000-4000-8000-000000000002'],
      ['obat', '3', '20000000-0000-4000-8000-000000000003'],
      ['inventaris', '1', '30000000-0000-4000-8000-000000000001'],
      ['inventaris', '2', '30000000-0000-4000-8000-000000000002'],
      ['inventaris', '3', '30000000-0000-4000-8000-000000000003'],
      ['inventaris', '4', '30000000-0000-4000-8000-000000000004'],
      ['inventaris', '5', '30000000-0000-4000-8000-000000000005'],
      ['meja-tanam', '1', '40000000-0000-4000-8000-000000000001'],
      ['meja-tanam', '2', '40000000-0000-4000-8000-000000000002'],
      ['meja-tanam', '3', '40000000-0000-4000-8000-000000000003'],
      ['meja-tanam', '4', '40000000-0000-4000-8000-000000000004'],
      ['penyemaian', '1', '50000000-0000-4000-8000-000000000001'],
      ['penyemaian', '2', '50000000-0000-4000-8000-000000000002'],
      ['pemindahan', '1', '60000000-0000-4000-8000-000000000001'],
    ];

    for (const [resourceType, domainId, defaultPublicId] of syncResources) {
      await tx.execute({
        sql: `INSERT INTO sync_resource_links (resource_type, domain_id, public_id)
          VALUES (?, ?, ?)
          ON CONFLICT(resource_type, domain_id) DO NOTHING`,
        args: [resourceType, domainId, defaultPublicId],
      });
      const link = await tx.execute({
        sql: `SELECT public_id FROM sync_resource_links WHERE resource_type = ? AND domain_id = ?`,
        args: [resourceType, domainId],
      });
      const resolvedPublicId = String(link.rows[0]?.public_id ?? defaultPublicId);
      await tx.execute({
        sql: `INSERT INTO sync_resource_versions (resource_type, public_id, version, changed_at)
          VALUES (?, ?, 1, ?)
          ON CONFLICT(resource_type, public_id) DO UPDATE SET changed_at=excluded.changed_at`,
        args: [resourceType, resolvedPublicId, now],
      });
    }

    await tx.commit();
    return {
      success: true,
      seededUsers: [SEED_CREDENTIALS.petani.username, SEED_CREDENTIALS.pegawai.username],
    };
  } catch (error) {
    if (!tx.closed) await tx.rollback();
    throw error;
  } finally {
    tx.close();
  }
}
