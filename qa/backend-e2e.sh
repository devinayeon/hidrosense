#!/usr/bin/env bash
# HidroSense QA — satu siklus penuh end-to-end (§5.1) dengan angka yang bisa
# direkonsiliasi langkah demi langkah.
#
# Prasyarat: server backend pada BASE_URL memakai database uji yang sudah
# dimigrasi + diseed. Jangan arahkan ke data produksi.
#
#   BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-e2e.sh
#
# Siklus: inventaris (benih+nutrisi) -> semai (konsumsi benih) -> pindah ->
# rusak -> panen -> jual -> rekonsiliasi stok/meja/panen.
set -u
BASE="${BASE_URL:-http://127.0.0.1:3100/api/v1}"
TMP="${TMPDIR:-/tmp}/hsqa-e2e"; mkdir -p "$TMP"
pass=0; fail=0; total=0
ok()  { total=$((total+1)); pass=$((pass+1)); printf 'PASS %-8s | %s\n' "$1" "$2"; }
bad() { total=$((total+1)); fail=$((fail+1)); printf 'FAIL %-8s | %s | harap [%s] dapat [%s]\n' "$1" "$2" "$4" "$3"; }
eq()  { if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2" "$3" "$4"; fi; }

req() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}" ; shift 4 || true
  local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$method" "$BASE$path" -H 'Content-Type: application/json')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  local haskey=0
  for h in "$@"; do
    [ "${h%%:*}" = "Idempotency-Key" ] && haskey=1
    args+=(-H "$h")
  done
  if [ "$haskey" = "0" ] && [ "$method" != "GET" ]; then args+=(-H "Idempotency-Key: $(uuid)"); fi
  [ -n "$body" ] && args+=(-d "$body")
  curl "${args[@]}"
}
body() { cat "$TMP/body"; }
jget() { python3 -c 'import sys,json
d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d[int(k)] if isinstance(d, list) else d[k]
print(d)' "$1" 2>/dev/null; }
uuid() { python3 -c 'import uuid;print(uuid.uuid4())'; }
today() { date +%F; }
days_ago() { date -d "$1 days ago" +%F; }
days_ahead() { date -d "$1 days" +%F; }

TOKEN=$(req POST /auth/login "{\"username\":\"petani\",\"password\":\"Petani123456!\"}" "" >/dev/null; body | jget data.access_token)
eq E2E-00 "login petani" "$([ -n "$TOKEN" ] && echo ok)" "ok"

TAG="E2E-$RANDOM$RANDOM"

# 1) Inventaris: benih dan nutrisi
JCODE=$(req POST /jenis-inventaris "{\"nama_jenis\":\"$TAG bahan\"}" "$TOKEN")
JID=$(body | jget data.id_jenis_inventaris)
eq E2E-01 "buat jenis inventaris" "$JCODE" "201"

BCODE=$(req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Benih $TAG\",\"satuan\":\"pak\",\"stok_minimum\":\"10\"}" "$TOKEN")
BID=$(body | jget data.id_inventaris)
eq E2E-02 "buat barang benih" "$BCODE" "201"

NCODE=$(req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Nutrisi $TAG\",\"satuan\":\"liter\",\"stok_minimum\":null}" "$TOKEN")
NID=$(body | jget data.id_inventaris)
eq E2E-03 "buat barang nutrisi" "$NCODE" "201"

eq E2E-04 "stok masuk benih 50" "$(req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"50.00\",\"satuan\":\"pak\"}]}" "$TOKEN" "Idempotency-Key: $(uuid)")" "201"
eq E2E-05 "stok masuk nutrisi 100" "$(req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$NID\",\"jumlah\":\"100.00\",\"satuan\":\"liter\"}]}" "$TOKEN" "Idempotency-Key: $(uuid)")" "201"

# 2) Penyemaian: 100 benih, konsumsi 5 pak benih
SCODE=$(req POST /penyemaian "{\"tanggal_semai\":\"$(days_ago 20)\",\"jumlah_benih\":100,\"materials\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"5.00\",\"satuan\":\"pak\"}]}" "$TOKEN")
SID=$(body | jget data.id_penyemaian)
eq E2E-06 "buat penyemaian 100 benih" "$SCODE" "201"
req GET "/inventaris/$BID/saldo" '' "$TOKEN" >/dev/null
eq E2E-07 "stok benih 50-5=45" "$(body | jget data.saldo)" "45"
req GET "/penyemaian/$SID" '' "$TOKEN" >/dev/null
eq E2E-08 "sisa benih penyemaian 100" "$(body | jget data.sisa_benih)" "100"

# 3) Meja + pemindahan 40
MCODE=$(req POST /meja-tanam "{\"kode_meja\":\"$TAG-M\",\"jumlah_lubang\":60}" "$TOKEN")
MID=$(body | jget data.id_meja)
eq E2E-09 "buat meja 60 lubang" "$MCODE" "201"
TCODE=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID\",\"id_meja\":\"$MID\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":40}" "$TOKEN")
TID=$(body | jget data.id_pemindahan)
eq E2E-10 "pindah 40 tanaman" "$TCODE" "201"
eq E2E-11 "estimasi panen = pindah+45" "$(body | jget data.estimasi_panen)" "$(days_ahead 45)"
req GET "/penyemaian/$SID" '' "$TOKEN" >/dev/null
eq E2E-12 "sisa benih penyemaian 100-40=60" "$(body | jget data.sisa_benih)" "60"
req GET "/meja-tanam/$MID" '' "$TOKEN" >/dev/null
eq E2E-13 "tanaman aktif meja 40" "$(body | jget data.tanaman_aktif)" "40"
eq E2E-14 "kapasitas tersedia meja 60-40=20" "$(body | jget data.kapasitas_tersedia)" "20"

# 4) Kerusakan 5
DCODE=$(req POST /kerusakan "{\"id_pemindahan\":\"$TID\",\"tanggal_kejadian\":\"$(today)\",\"jumlah_tanaman\":5,\"jenis_kerusakan\":\"busuk\"}" "$TOKEN")
eq E2E-15 "catat 5 tanaman rusak" "$DCODE" "201"
req GET "/meja-tanam/$MID" '' "$TOKEN" >/dev/null
eq E2E-16 "tanaman aktif meja 40-5=35" "$(body | jget data.tanaman_aktif)" "35"

# 5) Panen 30, berat total 3.00 / reject 0.50 -> layak 2.50
HCODE=$(req POST /panen "{\"tanggal_panen\":\"$(today)\",\"details\":[{\"id_pemindahan\":\"$TID\",\"jumlah_tanaman\":30,\"berat_total\":\"3.00\",\"berat_reject\":\"0.50\"}]}" "$TOKEN")
HID=$(body | jget data.id_panen)
eq E2E-17 "panen 30 tanaman" "$HCODE" "201"
req GET "/panen/$HID" '' "$TOKEN" >/dev/null
eq E2E-18 "berat layak panen 3.00-0.50=2.50" "$(body | jget data.berat_layak)" "2.50"
eq E2E-19 "berat total panen 3.00" "$(body | jget data.berat_total)" "3.00"
req GET "/meja-tanam/$MID" '' "$TOKEN" >/dev/null
eq E2E-20 "tanaman aktif meja 35-30=5" "$(body | jget data.tanaman_aktif)" "5"

# 6) Penjualan 2.00 kg @ 20000 = 40000.00
SLCODE=$(req POST /penjualan "{\"tanggal_penjualan\":\"$(today)\",\"pembeli\":\"$TAG\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"2.00\",\"harga_per_kg\":\"20000.00\"}" "$TOKEN")
SLID=$(body | jget data.id_penjualan)
eq E2E-21 "jual 2.00 kg" "$SLCODE" "201"
eq E2E-22 "total harga 2.00x20000=40000.00" "$(body | jget data.details.0.total_harga)" "40000.00"
req GET "/penjualan/$SLID" '' "$TOKEN" >/dev/null
eq E2E-23 "detail penjualan 2.00 kg" "$(body | jget data.details.0.jumlah_kg)" "2.00"

# 7) Rekonsiliasi akhir
req GET "/inventaris/$BID/saldo" '' "$TOKEN" >/dev/null
eq E2E-24 "stok benih akhir tetap 45 (tidak ikut panen/jual)" "$(body | jget data.saldo)" "45"
req GET "/inventaris/$NID/saldo" '' "$TOKEN" >/dev/null
eq E2E-25 "stok nutrisi tetap 100" "$(body | jget data.saldo)" "100"
req GET "/meja-tanam/$MID" '' "$TOKEN" >/dev/null
eq E2E-26 "rekonsiliasi meja: 40-5-30=5" "$(body | jget data.tanaman_aktif)" "5"
req GET "/penyemaian/$SID" '' "$TOKEN" >/dev/null
eq E2E-27 "rekonsiliasi penyemaian: pindah 40 <= benih 100" "$(body | jget data.sisa_benih)" "60"

echo "TOTAL=$total PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]