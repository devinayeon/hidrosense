#!/usr/bin/env bash
# HidroSense QA — bangun ulang database uji deterministik.
#
# Selalu memakai SQLite lokal di QA_DIR (default /tmp/opencode/hsqa). Script ini
# TIDAK menyentuh apps/backend/data/hidrosense.db maupun Turso/remote.
#
# Pakai:
#   bash qa/reset-backend-qa.sh            # buat ulang qa.db + seed
#   QA_DIR=/tmp/opencode/hsqa bash qa/reset-backend-qa.sh
set -euo pipefail

QA_DIR="${QA_DIR:-/tmp/opencode/hsqa}"
DB_FILE="$QA_DIR/qa.db"
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apps/backend" && pwd)"

mkdir -p "$QA_DIR"

case "$DB_FILE" in
  /tmp/*) ;;
  *) echo "QA_DIR harus di bawah /tmp agar data asli aman: $DB_FILE" >&2; exit 2 ;;
esac

echo "==> Menghapus database uji lama: $DB_FILE"
rm -f "$DB_FILE" "$DB_FILE-shm" "$DB_FILE-wal"

cd "$BACKEND_DIR"
echo "==> Migrasi"
DATABASE_URL="file:$DB_FILE" NODE_ENV=development npm run db:migrate

echo "==> Seed"
DATABASE_URL="file:$DB_FILE" NODE_ENV=development npm run db:seed

echo "==> Selesai. Database uji siap di $DB_FILE"
echo "    Jalankan server: PORT=3100 DATABASE_URL=file:$DB_FILE npm run dev"
