import { z } from 'zod';

/**
 * Kode hama yang dikenali model (urutan ml/artifacts/labels.txt). Sama dengan tabel `hama` di
 * database dan `PestKind` di aplikasi mobile; ubah ketiganya bersamaan.
 */
export const hamaSchema = z.enum(['thrips', 'whitefly', 'aphids']);
