#!/usr/bin/env bash
# HidroSense QA — ukur latensi endpoint backend apa adanya (§5.7).
#
#   BASE_URL=http://127.0.0.1:3100/api/v1 REPS=15 bash qa/perf.sh
#
# Catatan: rate limit server 120 permintaan/menit per IP. Jumlah panggilan =
# RESPONS x REPS + 1 (login). Jaga di bawah 120 atau jalankan ulang setelah
# satu menit. Output: rata-rata, p50, p95, maksimum (ms), dan status HTTP.
set -u
BASE="${BASE_URL:-http://127.0.0.1:3100/api/v1}"
REPS="${REPS:-15}"
TMP="${TMPDIR:-/tmp}/hsqa-perf"; mkdir -p "$TMP"

TOKEN=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
  -d '{"username":"petani","password":"Petani123456!"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["access_token"])')
[ -n "$TOKEN" ] || { echo "login gagal"; exit 1; }

# "nama|METHOD|path"
ENDPOINTS=(
  "meja.list|GET|/meja-tanam?limit=20"
  "inventaris.list|GET|/inventaris?limit=20"
  "penyemaian.list|GET|/penyemaian?limit=20"
  "panen.list|GET|/panen?limit=20"
  "penjualan.list|GET|/penjualan?limit=20"
  "sync.changes|GET|/sync/changes?limit=50"
)

printf '%-18s %8s %8s %8s %8s %6s\n' "endpoint" "avg_ms" "p50_ms" "p95_ms" "max_ms" "http"
for entry in "${ENDPOINTS[@]}"; do
  IFS='|' read -r name method path <<< "$entry"
  : > "$TMP/times"
  code=""
  for _ in $(seq 1 "$REPS"); do
    code=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' -X "$method" \
      -H "Authorization: Bearer $TOKEN" "$BASE$path")
    echo "$code" >> "$TMP/times"
  done
  python3 - "$name" "$TMP/times" <<'PY'
import sys, statistics
name, path = sys.argv[1], sys.argv[2]
rows = [line.split() for line in open(path) if line.strip()]
codes = sorted({r[0] for r in rows})
ms = sorted(float(r[1]) * 1000 for r in rows)
def pct(p):
    i = min(len(ms) - 1, max(0, int(round((p / 100) * (len(ms) - 1)))))
    return ms[i]
print(f"{name:<18} {statistics.fmean(ms):8.1f} {pct(50):8.1f} {pct(95):8.1f} {ms[-1]:8.1f} {'/'.join(codes):>6}")
PY
done