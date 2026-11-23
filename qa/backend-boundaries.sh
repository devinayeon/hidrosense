#!/usr/bin/env bash
# HidroSense QA — uji batas persis (inclusive/exclusive) pada aturan domain.
#   BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-boundaries.sh
#
# Membuktikan: umur pindah (14 vs 15 hari), sisa benih tepat, kapasitas meja
# tepat, panen tepat tanaman aktif, dan jual tepat berat layak; satu langkah
# melewati batas harus ditolak.
set -u
BASE="${BASE_URL:-http://127.0.0.1:3100/api/v1}"
TMP="${TMPDIR:-/tmp}/hsqa-bound"; mkdir -p "$TMP"
pass=0; fail=0; total=0
ok()  { total=$((total+1)); pass=$((pass+1)); printf 'PASS %-8s | %s\n' "$1" "$2"; }
bad() { total=$((total+1)); fail=$((fail+1)); printf 'FAIL %-8s | %s | harap [%s] dapat [%s]\n' "$1" "$2" "$4" "$3"; }
eq()  { if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2" "$3" "$4"; fi; }

req() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}" ; shift 4 || true
  local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$method" "$BASE$path" -H 'Content-Type: application/json')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  local haskey=0
  for h in "$@"; do [ "${h%%:*}" = "Idempotency-Key" ] && haskey=1; args+=(-H "$h"); done
  [ "$haskey" = "0" ] && [ "$method" != "GET" ] && args+=(-H "Idempotency-Key: $(uuid)")
  [ -n "$body" ] && args+=(-d "$body")
  curl "${args[@]}"
}
body() { cat "$TMP/body"; }
jget() { python3 -c 'import sys,json
d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d=d[int(k)] if isinstance(d,list) else d[k]
print(d)' "$1" 2>/dev/null; }
uuid() { python3 -c 'import uuid;print(uuid.uuid4())'; }
today() { date +%F; }
days_ago() { date -d "$1 days ago" +%F; }
TAG="BND-$RANDOM$RANDOM"

TOKEN=$(req POST /auth/login '{"username":"petani","password":"Petani123456!"}' "" >/dev/null; body | jget data.access_token)

# Persediaan benih
JID=$(req POST /jenis-inventaris "{\"nama_jenis\":\"$TAG\"}" "$TOKEN" >/dev/null; body | jget data.id_jenis_inventaris)
BID=$(req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Benih $TAG\",\"satuan\":\"pak\",\"stok_minimum\":null}" "$TOKEN" >/dev/null; body | jget data.id_inventaris)
req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"1000.00\",\"satuan\":\"pak\"}]}" "$TOKEN" >/dev/null

sowing() { # days seeds -> id
  req POST /penyemaian "{\"tanggal_semai\":\"$(days_ago "$1")\",\"jumlah_benih\":$2,\"materials\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"1.00\",\"satuan\":\"pak\"}]}" "$TOKEN" >/dev/null
  body | jget data.id_penyemaian
}
table() { # holes -> id
  req POST /meja-tanam "{\"kode_meja\":\"$TAG-$1-$RANDOM\",\"jumlah_lubang\":$1}" "$TOKEN" >/dev/null
  body | jget data.id_meja
}
transfer() { # sowing table qty -> code
  req POST /pemindahan "{\"id_penyemaian\":\"$1\",\"id_meja\":\"$2\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":$3}" "$TOKEN"
}

echo "== PB-03 batas umur pindah (14 vs 15 hari) =="
S14=$(sowing 14 10); TA=$(table 30)
eq BND-01 "umur 14 hari ditolak" "$(transfer "$S14" "$TA" 5)" "400"
S15=$(sowing 15 10)
eq BND-02 "umur 15 hari diterima (batas)" "$(transfer "$S15" "$TA" 5)" "201"

echo "== PB-04 batas sisa benih =="
SB=$(sowing 20 10); TB=$(table 50)
eq BND-03 "pindah tepat sebanyak benih (10) diterima" "$(transfer "$SB" "$TB" 10)" "201"
eq BND-04 "pindah 1 lagi dari benih habis ditolak" "$(transfer "$SB" "$TB" 1)" "409"

echo "== PB-04 batas kapasitas meja =="
TC=$(table 10); SA=$(sowing 20 10); SC=$(sowing 20 10)
eq BND-05 "pindah tepat kapasitas (10/10) diterima" "$(transfer "$SA" "$TC" 10)" "201"
SA_TID=$(body | jget data.id_pemindahan)
eq BND-06 "pindah 1 melebihi kapasitas ditolak" "$(transfer "$SC" "$TC" 1)" "409"
req GET "/meja-tanam/$TC" '' "$TOKEN" >/dev/null
eq BND-07 "status meja penuh di 10/10" "$(body | jget data.status_meja)" "penuh"

echo "== PB-08 batas panen =="
HCODE=$(req POST /panen "{\"tanggal_panen\":\"$(today)\",\"details\":[{\"id_pemindahan\":\"$SA_TID\",\"jumlah_tanaman\":10,\"berat_total\":\"2.00\",\"berat_reject\":\"0.00\"}]}" "$TOKEN")
HID=$(body | jget data.id_panen)
eq BND-08 "panen tepat semua tanaman aktif (10) diterima" "$HCODE" "201"
eq BND-09 "panen 1 lagi setelah habis ditolak" "$(req POST /panen "{\"tanggal_panen\":\"$(today)\",\"details\":[{\"id_pemindahan\":\"$SA_TID\",\"jumlah_tanaman\":1,\"berat_total\":\"1.00\",\"berat_reject\":\"0.00\"}]}" "$TOKEN")" "409"

echo "== PB-09 batas berat terjual =="
eq BND-10 "jual tepat berat layak (2.00) diterima" "$(req POST /penjualan "{\"tanggal_penjualan\":\"$(today)\",\"pembeli\":\"$TAG\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"2.00\",\"harga_per_kg\":\"10000.00\"}" "$TOKEN")" "201"
eq BND-11 "jual 0.01 melebihi layak ditolak" "$(req POST /penjualan "{\"tanggal_penjualan\":\"$(today)\",\"pembeli\":\"$TAG\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"0.01\",\"harga_per_kg\":\"10000.00\"}" "$TOKEN")" "409"

echo "TOTAL=$total PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]