#!/usr/bin/env bash
# HidroSense QA — uji tabrakan dua pengguna (konkurensi) & idempotensi.
#   BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-concurrency.sh
#
# Membuktikan perilaku nyata backend saat dua sesi (petani & pegawai) menyentuh
# baris yang sama: last-write-wins tanpa versi, 409 VERSION_CONFLICT dengan versi
# basi, idempotensi kunci yang sama, dan stok yang habis karena dua pengguna.
set -u
BASE="${BASE_URL:-http://127.0.0.1:3100/api/v1}"
TMP="${TMPDIR:-/tmp}/hsqa-conc"; mkdir -p "$TMP"
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
TAG="CONC-$RANDOM$RANDOM"

TOKEN_A=$(req POST /auth/login '{"username":"petani","password":"Petani123456!"}' "" >/dev/null; body | jget data.access_token)
TOKEN_B=$(req POST /auth/login '{"username":"pegawai","password":"Pegawai123456!"}' "" >/dev/null; body | jget data.access_token)

echo "== dua pengguna mengubah barang yang sama (tanpa expected_version) =="
JID=$(req POST /jenis-inventaris "{\"nama_jenis\":\"$TAG\"}" "$TOKEN_A" >/dev/null; body | jget data.id_jenis_inventaris)
req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Barang $TAG\",\"satuan\":\"pak\",\"stok_minimum\":null}" "$TOKEN_A" >/dev/null
IID=$(body | jget data.id_inventaris)
eq CONC-01 "user A ubah nama tanpa versi -> diterima" "$(req PATCH "/inventaris/$IID" "{\"nama_barang\":\"$TAG A\"}" "$TOKEN_A")" "200"
eq CONC-02 "user B ubah nama tanpa versi -> diterima (tulis terakhir menang)" "$(req PATCH "/inventaris/$IID" "{\"nama_barang\":\"$TAG B\"}" "$TOKEN_B")" "200"
req GET "/inventaris/$IID" '' "$TOKEN_A" >/dev/null
eq CONC-03 "nama akhir = milik B (last write wins, terdokumentasi)" "$(body | jget data.nama_barang)" "$TAG B"

echo "== dua pengguna memakai versi yang sama (optimistic concurrency) =="
req GET "/inventaris/$IID" '' "$TOKEN_A" >/dev/null
IV1=$(body | jget data.version)
eq CONC-04 "user A pakai versi terkini -> diterima" "$(req PATCH "/inventaris/$IID" "{\"nama_barang\":\"$TAG C\",\"expected_version\":\"$IV1\"}" "$TOKEN_A")" "200"
CODE_STALE=$(req PATCH "/inventaris/$IID" "{\"nama_barang\":\"$TAG D\",\"expected_version\":\"$IV1\"}" "$TOKEN_B")
eq CONC-05 "user B pakai versi basi -> 409" "$CODE_STALE" "409"
eq CONC-06 "kode penolakan VERSION_CONFLICT" "$(body | jget error.code)" "VERSION_CONFLICT"

echo "== idempotensi kunci operasi =="
KEY=$(uuid)
BODY_E="{\"nama_barang\":\"$TAG E\"}"
# Kiriman pertama memakai kunci $KEY lewat helper.
req PATCH "/inventaris/$IID" "$BODY_E" "$TOKEN_A" "Idempotency-Key: $KEY" >/dev/null
# Kiriman kedua: kunci dan isi sama -> replay, bukan tulis kedua.
CODE2=$(curl -s -o "$TMP/b2" -w '%{http_code}' -X PATCH "$BASE/inventaris/$IID" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN_A" -H "Idempotency-Key: $KEY" -d "$BODY_E")
eq CONC-07 "kunci sama + isi sama -> 200" "$CODE2" "200"
eq CONC-08 "ditandai replayed" "$(python3 -c 'import json;print(json.load(open("'"$TMP"'/b2"))["replayed"])' 2>/dev/null)" "True"
CODE3=$(curl -s -o "$TMP/b3" -w '%{http_code}' -X PATCH "$BASE/inventaris/$IID" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN_A" -H "Idempotency-Key: $KEY" -d "{\"nama_barang\":\"$TAG F\"}")
eq CONC-09 "kunci sama + isi beda -> 409" "$CODE3" "409"
eq CONC-10 "kode OPERATION_CONFLICT" "$(python3 -c 'import json;print(json.load(open("'"$TMP"'/b3"))["error"]["code"])' 2>/dev/null)" "OPERATION_CONFLICT"

echo "== dua pengguna mengoreksi panen yang sama =="
req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$IID\",\"jumlah\":\"100.00\",\"satuan\":\"pak\"}]}" "$TOKEN_A" >/dev/null
req POST /penyemaian "{\"tanggal_semai\":\"$(days_ago 20)\",\"jumlah_benih\":10,\"materials\":[{\"id_inventaris\":\"$IID\",\"jumlah\":\"1.00\",\"satuan\":\"pak\"}]}" "$TOKEN_A" >/dev/null
SID=$(body | jget data.id_penyemaian)
req POST /meja-tanam "{\"kode_meja\":\"$TAG-$RANDOM\",\"jumlah_lubang\":20}" "$TOKEN_A" >/dev/null
TID=$(body | jget data.id_meja)
req POST /pemindahan "{\"id_penyemaian\":\"$SID\",\"id_meja\":\"$TID\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":10}" "$TOKEN_A" >/dev/null
MID=$(body | jget data.id_pemindahan)
req POST /panen "{\"tanggal_panen\":\"$(today)\",\"details\":[{\"id_pemindahan\":\"$MID\",\"jumlah_tanaman\":10,\"berat_total\":\"2.00\",\"berat_reject\":\"0.00\"}]}" "$TOKEN_A" >/dev/null
HID=$(body | jget data.id_panen)
HV1=$(body | jget data.version)
CODEH=$(req PATCH "/panen/$HID" "{\"expected_version\":\"$HV1\",\"keterangan\":\"koreksi A\"}" "$TOKEN_A")
eq CONC-11 "koreksi panen pakai versi terkini -> diterima" "$CODEH" "200"
CODEH2=$(req PATCH "/panen/$HID" "{\"expected_version\":\"$HV1\",\"keterangan\":\"koreksi B\"}" "$TOKEN_B")
eq CONC-12 "koreksi panen versi basi -> 409" "$CODEH2" "409"
eq CONC-13 "kode HARVEST_VERSION_CONFLICT" "$(body | jget error.code)" "HARVEST_VERSION_CONFLICT"

echo "== dua pengguna mengoreksi penjualan yang sama =="
req POST /penjualan "{\"tanggal_penjualan\":\"$(today)\",\"pembeli\":\"$TAG\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"1.00\",\"harga_per_kg\":\"10000.00\"}" "$TOKEN_A" >/dev/null
SALEID=$(body | jget data.id_penjualan)
SV1=$(body | jget data.version)
CODES=$(req PATCH "/penjualan/$SALEID" "{\"expected_version\":\"$SV1\",\"keterangan\":\"ubah A\"}" "$TOKEN_A")
eq CONC-14 "koreksi penjualan pakai versi terkini -> diterima" "$CODES" "200"
CODES2=$(req PATCH "/penjualan/$SALEID" "{\"expected_version\":\"$SV1\",\"keterangan\":\"ubah B\"}" "$TOKEN_A")
eq CONC-15 "koreksi penjualan versi basi -> 409" "$CODES2" "409"
eq CONC-16 "kode SALE_VERSION_CONFLICT" "$(body | jget error.code)" "SALE_VERSION_CONFLICT"

echo "== stok habis karena dua pengguna memakai barang yang sama =="
req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Stok $TAG\",\"satuan\":\"pak\",\"stok_minimum\":null}" "$TOKEN_A" >/dev/null
SID2=$(body | jget data.id_inventaris)
req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$SID2\",\"jumlah\":\"10.00\",\"satuan\":\"pak\"}]}" "$TOKEN_A" >/dev/null
OUT="{\"jenis_stok\":\"keluar\",\"details\":[{\"id_inventaris\":\"$SID2\",\"jumlah\":\"10.00\",\"satuan\":\"pak\"}]}"
eq CONC-17 "user A keluar 10 dari saldo 10 -> diterima" "$(req POST /stok "$OUT" "$TOKEN_B")" "201"
eq CONC-18 "user B keluar 10 lagi -> ditolak" "$(req POST /stok "$OUT" "$TOKEN_A")" "409"

echo "== dua perangkat mengirim kunci idempoten yang sama bersamaan =="
req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Race $TAG\",\"satuan\":\"pak\",\"stok_minimum\":null}" "$TOKEN_A" >/dev/null
RID=$(body | jget data.id_inventaris)
req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$RID\",\"jumlah\":\"50.00\",\"satuan\":\"pak\"}]}" "$TOKEN_A" >/dev/null
RKEY=$(uuid)
RBODY="{\"jenis_stok\":\"keluar\",\"details\":[{\"id_inventaris\":\"$RID\",\"jumlah\":\"1.00\",\"satuan\":\"pak\"}]}"
rm -f "$TMP"/race_*
for i in $(seq 1 8); do
  curl -s -o "$TMP/race_$i" -X POST "$BASE/stok" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN_A" \
    -H "Idempotency-Key: $RKEY" -d "$RBODY" &
done
wait
APPLIED=0; REPLAYED=0; ODD=0
for i in $(seq 1 8); do
  case "$(python3 -c 'import sys,json
try:
  d=json.load(open(sys.argv[1]))
  print(d.get("replayed", d.get("operation",{}).get("replayed")))
except Exception:
  print("ODD")' "$TMP/race_$i" 2>/dev/null)" in
    False) APPLIED=$((APPLIED+1)) ;;
    True) REPLAYED=$((REPLAYED+1)) ;;
    *) ODD=$((ODD+1)) ;;
  esac
done
eq CONC-19 "kunci sama, 8 kiriman paralel -> tepat satu efek nyata" "$APPLIED" "1"
eq CONC-20 "sisanya dilaporkan replay, tanpa galat" "$REPLAYED" "7"
eq CONC-21 "tanpa jawaban rusak/5xx" "$ODD" "0"
req GET "/inventaris/$RID" '' "$TOKEN_A" >/dev/null
eq CONC-22 "saldo hanya berkurang sekali (50 - 1)" "$(body | jget data.saldo)" "49"

echo "TOTAL=$total PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
