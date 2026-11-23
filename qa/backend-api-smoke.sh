#!/usr/bin/env bash
# HidroSense QA — smoke & adversarial API tests.
#
# Prasyarat: server backend berjalan pada BASE_URL dengan database yang sudah
# dimigrasi + diseed (lihat qa/run-backend-api.sh untuk versi otomatis).
# Jalankan:  BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-api-smoke.sh
#
# Script ini hanya membaca/menulis ke database uji yang ditunjuk server.
# Jangan arahkan ke data produksi.

set -u
BASE="${BASE_URL:-http://127.0.0.1:3100/api/v1}"
TMP="${TMPDIR:-/tmp}/hsqa-smoke"
mkdir -p "$TMP"

pass=0; fail=0; total=0
ok()   { total=$((total+1)); pass=$((pass+1)); printf 'PASS %-22s | %s\n' "$1" "$2"; }
bad()  { total=$((total+1)); fail=$((fail+1)); printf 'FAIL %-22s | %s | %s\n' "$1" "$2" "$3"; }
eq()   { if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2" "expected [$4] got [$3]"; fi; }

# request METHOD PATH BODY TOKEN [EXTRA_HEADERS...] -> prints "<code>\n<body>"
req() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}" ; shift 4 || true
  local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$method" "$BASE$path")
  args+=(-H 'Content-Type: application/json')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  for h in "$@"; do args+=(-H "$h"); done
  [ -n "$body" ] && args+=(-d "$body")
  local code
  code=$(curl "${args[@]}")
  printf '%s' "$code"
}
body() { cat "$TMP/body"; }
jget() { python3 -c 'import sys,json;d=json.load(sys.stdin);
import functools,operator as o
p=sys.argv[1].split(".")
for k in p: d=d[int(k)] if isinstance(d,list) else d[k]
print(d)' "$1" 2>/dev/null; }
uuid() { python3 -c 'import uuid;print(uuid.uuid4())'; }
mklogin() { python3 -c 'import json,sys;print(json.dumps({"username":sys.argv[1],"password":sys.argv[2]}))' "$1" "$2"; }

login() { # username password -> token on stdout
  local code
  code=$(req POST /auth/login "{\"username\":\"$1\",\"password\":\"$2\"}" "")
  [ "$code" = "200" ] || { echo ""; return 1; }
  body | jget data.access_token
}

echo "== Health =="
eq "HC-01" "GET /health/live" "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health/live)" "200"
eq "HC-02" "GET /health/ready" "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health/ready)" "200"

echo "== PB-01 Auth =="
TP=$(login petani 'Petani123456!');  eq "AU-01" "login petani valid" "$([ -n "$TP" ] && echo ok)" "ok"
TE=$(login pegawai 'Pegawai123456!'); eq "AU-02" "login pegawai valid" "$([ -n "$TE" ] && echo ok)" "ok"
eq "AU-03" "login casing/Unicode: 'PETANI'" "$(login PETANI 'Petani123456!' >/dev/null && echo ok)" "ok"
eq "AU-04" "password salah" "$(req POST /auth/login "$(mklogin petani salah)" "")" "401"
eq "AU-05" "username tak ada (tidak membocorkan)" "$(req POST /auth/login "$(mklogin tidakada 'Salah123456!')" "")" "401"
eq "AU-06" "username kosong" "$(req POST /auth/login "$(mklogin '' x)" "")" "400"
eq "AU-07" "username hanya spasi" "$(req POST /auth/login "$(mklogin '   ' x)" "")" "400"
eq "AU-08" "username 1000+ karakter" "$(req POST /auth/login "$(mklogin "$(python3 -c 'print("a"*1001)')" x)" "")" "400"
eq "AU-09" "unicode/emoji username" "$(req POST /auth/login "$(mklogin 'pëtani🌱' x)" "")" "401"
eq "AU-10" "SQL injection ' OR 1=1" "$(req POST /auth/login "$(mklogin "' OR '1'='1" x)" "")" "401"
eq "AU-11" "SQL injection DROP TABLE" "$(req POST /auth/login "$(mklogin '"; DROP TABLE users;--' x)" "")" "401"
eq "AU-12" "field ekstra ditolak (strict)" "$(req POST /auth/login '{"username":"petani","password":"Petani123456!","role":"petani"}' "")" "400"
eq "AU-13" "akses tanpa token" "$(req GET /inventaris '' '')" "401"
eq "AU-14" "token sampah" "$(req GET /inventaris '' 'bukan-token')" "401"

echo "== PB-01 Otorisasi dua lapis (pegawai) =="
eq "AZ-01" "pegawai GET /penjualan" "$(req GET /penjualan '' "$TE")" "403"
eq "AZ-02" "pegawai POST /penjualan" "$(req POST /penjualan '{}' "$TE" "Idempotency-Key: $(uuid)")" "403"
eq "AZ-03" "pegawai GET /employees" "$(req GET /employees '' "$TE")" "403"
eq "AZ-04" "pegawai GET /profile" "$(req GET /profile '' "$TE")" "403"
eq "AZ-05" "pegawai PATCH /profile (escalation)" "$(req PATCH /profile '{"role":"petani"}' "$TE")" "403"
eq "AZ-06" "pegawai GET /inventaris (boleh)" "$(req GET /inventaris '' "$TE")" "200"
eq "AZ-07" "pegawai GET /panen (boleh)" "$(req GET /panen '' "$TE")" "200"
eq "AZ-08" "pegawai GET /penyemaian (boleh)" "$(req GET /penyemaian '' "$TE")" "200"
eq "AZ-09" "pegawai GET /meja-tanam (boleh)" "$(req GET /meja-tanam '' "$TE")" "200"
eq "AZ-10" "petani PATCH /profile role escalation" "$(req PATCH /profile '{"role":"petani"}' "$TP")" "400"

echo "== PB-11 Akun =="
U="qa_$RANDOM$RANDOM"
eq "AC-01" "petani buat pegawai" "$(req POST /employees "{\"nama\":\"QA Satu\",\"username\":\"$U\",\"password\":\"Rahasia123456!\"}" "$TP")" "201"
EID=$(body | jget data.id_user)
eq "AC-02" "username duplikat beda kasus" "$(req POST /employees "{\"nama\":\"QA Dua\",\"username\":\"$(echo "$U" | tr '[:lower:]' '[:upper:]')\",\"password\":\"Rahasia123456!\"}" "$TP")" "409"
eq "AC-03" "password < 12 karakter" "$(req POST /employees '{"nama":"QA Tiga","username":"qa_pendek","password":"pendek"}' "$TP")" "400"
eq "AC-04" "email format salah" "$(req POST /employees '{"nama":"QA Empat","username":"qa_email","password":"Rahasia123456!","email":"bukan-email"}' "$TP")" "400"
eq "AC-05" "no_telepon tanpa angka" "$(req POST /employees '{"nama":"QA Lima","username":"qa_telp","password":"Rahasia123456!","no_telepon":"abc"}' "$TP")" "400"
XSSU="qa_xss_$RANDOM$RANDOM"
eq "AC-06" "nama berisi <script> diterima literal (bukan 5xx)" "$(req POST /employees "{\"nama\":\"<script>alert(1)</script>\",\"username\":\"$XSSU\",\"password\":\"Rahasia123456!\"}" "$TP" | cut -c1)" "2"
eq "AC-06b" "nilai <script> tersimpan apa adanya (JSON, bukan HTML)" "$(req GET '/employees?q=script' '' "$TP" >/dev/null; body | python3 -c 'import sys,json;d=json.load(sys.stdin);print("ok" if any("<script>" in e.get("nama","") for e in d["data"]) else "no")')" "ok"
TE2=$(login "$U" 'Rahasia123456!')
eq "AC-07" "pegawai baru bisa login" "$([ -n "$TE2" ] && echo ok)" "ok"
eq "AC-08" "nonaktifkan akun" "$(req POST "/employees/$EID/deactivate" '' "$TP")" "204"
eq "AC-09" "akun nonaktif login (password benar)" "$(req POST /auth/login "{\"username\":\"$U\",\"password\":\"Rahasia123456!\"}" "")" "403"
eq "AC-10" "akun nonaktif login (password salah)" "$(req POST /auth/login "{\"username\":\"$U\",\"password\":\"salah\"}" "")" "401"
eq "AC-11" "sesi lama akun nonaktif ditolak" "$(req GET /inventaris '' "$TE2")" "401"
eq "AC-12" "data akun nonaktif tetap ada" "$(req GET "/employees/$EID" '' "$TP")" "200"

echo "== PB-02 Inventaris & stok =="
eq "ST-01" "stok keluar > saldo ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"999","satuan":"botol"}]}' "$TP" "Idempotency-Key: $(uuid)")" "409"
SALDO=$(req GET /inventaris/4/saldo '' "$TP" >/dev/null; body | jget data.saldo)
eq "ST-02" "saldo tidak berubah (20)" "$SALDO" "20"
eq "ST-03" "jumlah 0 ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"0","satuan":"botol"}]}' "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "ST-04" "jumlah negatif ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"-1","satuan":"botol"}]}' "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "ST-05" "jumlah non-angka ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"abc","satuan":"botol"}]}' "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "ST-06" "jumlah NaN ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"NaN","satuan":"botol"}]}' "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "ST-07" "satuan salah ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"1","satuan":"kg"}]}' "$TP" "Idempotency-Key: $(uuid)")" "422"
eq "ST-08" "tanpa Idempotency-Key ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"4","jumlah":"1","satuan":"botol"}]}' "$TP")" "400"
eq "ST-09" "inventaris nonaktif ditolak" "$(req POST /stok '{"jenis_stok":"keluar","details":[{"id_inventaris":"9999","jumlah":"1","satuan":"botol"}]}' "$TP" "Idempotency-Key: $(uuid)")" "422"

echo "== PB-07 Idempotensi =="
K=$(uuid)
CODE="QA-$(uuid | cut -c1-8)"
BODY_T="{\"kode_meja\":\"$CODE\",\"jumlah_lubang\":10}"
C1=$(req POST /meja-tanam "$BODY_T" "$TP" "Idempotency-Key: $K")
MID=$(body | jget data.id_meja)
C2=$(req POST /meja-tanam "$BODY_T" "$TP" "Idempotency-Key: $K")
R2=$(body | jget replayed)
eq "ID-01" "kirim pertama 201" "$C1" "201"
eq "ID-02" "replay kunci+isi sama -> replayed true" "$R2" "True"
eq "ID-03" "replay memakai id yang sama" "$(body | jget data.id_meja)" "$MID"
eq "ID-04" "kunci sama isi beda -> 409" "$(req POST /meja-tanam '{"kode_meja":"QA-BEDA","jumlah_lubang":10}' "$TP" "Idempotency-Key: $K")" "409"

echo "== PB-04 Meja & pemindahan =="
eq "TB-01" "kode meja duplikat" "$(req POST /meja-tanam '{"kode_meja":"M-01","jumlah_lubang":10}' "$TP" "Idempotency-Key: $(uuid)")" "409"
eq "TB-02" "jumlah_lubang 0 ditolak" "$(req POST /meja-tanam '{"kode_meja":"QA-ZERO","jumlah_lubang":0}' "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "TB-03" "status penuh dari klien ditolak" "$(req POST /meja-tanam '{"kode_meja":"QA-FULL","jumlah_lubang":10,"status_meja":"penuh"}' "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "TB-04" "pindah bibit terlalu muda ditolak" "$(req POST /pemindahan "{\"id_penyemaian\":\"2\",\"id_meja\":\"2\",\"tanggal_pemindahan\":\"$(date +%F)\",\"jumlah_tanaman\":1}" "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "TB-05" "pindah melebihi sisa bibit ditolak" "$(req POST /pemindahan "{\"id_penyemaian\":\"1\",\"id_meja\":\"2\",\"tanggal_pemindahan\":\"$(date +%F)\",\"jumlah_tanaman\":9999}" "$TP" "Idempotency-Key: $(uuid)")" "409"
eq "TB-06" "pindah melebihi kapasitas meja ditolak" "$(req POST /pemindahan "{\"id_penyemaian\":\"1\",\"id_meja\":\"1\",\"tanggal_pemindahan\":\"$(date +%F)\",\"jumlah_tanaman\":100}" "$TP" "Idempotency-Key: $(uuid)")" "409"
eq "TB-07" "meja perbaikan tidak bisa dipakai" "$(req POST /pemindahan "{\"id_penyemaian\":\"1\",\"id_meja\":\"4\",\"tanggal_pemindahan\":\"$(date +%F)\",\"jumlah_tanaman\":1}" "$TP" "Idempotency-Key: $(uuid)")" "409"

echo "== PB-08/PB-09 Panen & penjualan =="
eq "HV-01" "panen melebihi tanaman aktif ditolak" "$(req POST /panen "{\"tanggal_panen\":\"$(date +%F)\",\"details\":[{\"id_pemindahan\":\"1\",\"jumlah_tanaman\":99999,\"berat_total\":\"1.00\",\"berat_reject\":\"0.00\"}]}" "$TP" "Idempotency-Key: $(uuid)")" "409"
eq "HV-02" "panen berat negatif ditolak" "$(req POST /panen "{\"tanggal_panen\":\"$(date +%F)\",\"details\":[{\"id_pemindahan\":\"1\",\"jumlah_tanaman\":1,\"berat_total\":\"-1.00\",\"berat_reject\":\"0.00\"}]}" "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "HV-03" "panen tanggal masa depan ditolak" "$(req POST /panen '{"tanggal_panen":"2099-01-01","details":[{"id_pemindahan":"1","jumlah_tanaman":1,"berat_total":"1.00","berat_reject":"0.00"}]}' "$TP" "Idempotency-Key: $(uuid)")" "400"
# panen sukses untuk uji jual
HK=$(uuid)
HC=$(req POST /panen "{\"tanggal_panen\":\"$(date +%F)\",\"details\":[{\"id_pemindahan\":\"1\",\"jumlah_tanaman\":5,\"berat_total\":\"5.00\",\"berat_reject\":\"0.50\"}]}" "$TP" "Idempotency-Key: $HK")
eq "HV-04" "panen valid dibuat" "$HC" "201"
HID=$(body | jget data.id_panen)
eq "SL-01" "jual melebihi berat layak ditolak" "$(req POST /penjualan "{\"tanggal_penjualan\":\"$(date +%F)\",\"pembeli\":\"QA\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"999.00\",\"harga_per_kg\":\"20000.00\"}" "$TP" "Idempotency-Key: $(uuid)")" "409"
eq "SL-02" "jual berat 0 ditolak" "$(req POST /penjualan "{\"tanggal_penjualan\":\"$(date +%F)\",\"pembeli\":\"QA\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"0.00\",\"harga_per_kg\":\"20000.00\"}" "$TP" "Idempotency-Key: $(uuid)")" "400"
eq "SL-03" "jual tanggal sebelum panen ditolak" "$(req POST /penjualan "{\"tanggal_penjualan\":\"2020-01-01\",\"pembeli\":\"QA\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"1.00\",\"harga_per_kg\":\"20000.00\"}" "$TP" "Idempotency-Key: $(uuid)")" "400"
SK=$(uuid); SC=$(req POST /penjualan "{\"tanggal_penjualan\":\"$(date +%F)\",\"pembeli\":\"QA\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"2.00\",\"harga_per_kg\":\"20000.00\"}" "$TP" "Idempotency-Key: $SK")
eq "SL-04" "jual valid dibuat" "$SC" "201"
eq "SL-05" "total harga 2.00x20000 = 40000.00" "$(body | jget data.details.0.total_harga)" "40000.00"
eq "SL-06" "replay penjualan tidak menduplikasi" "$(req POST /penjualan "{\"tanggal_penjualan\":\"$(date +%F)\",\"pembeli\":\"QA\",\"status_pembayaran\":\"lunas\",\"id_panen\":\"$HID\",\"jumlah_kg\":\"2.00\",\"harga_per_kg\":\"20000.00\"}" "$TP" "Idempotency-Key: $SK" >/dev/null; body | jget replayed)" "True"

echo "== Validasi daftar & parameter =="
eq "QS-01" "limit > 100 ditolak" "$(req GET '/meja-tanam?limit=101' '' "$TP")" "400"
eq "QS-02" "query tak dikenal ditolak" "$(req GET '/meja-tanam?foo=1' '' "$TP")" "400"
eq "QS-03" "halaman valid" "$(req GET '/meja-tanam?page=1&limit=2' '' "$TP")" "200"
eq "QS-04" "404 record tak ada" "$(req GET '/meja-tanam/999999' '' "$TP")" "404"

echo "== Ringkasan =="
echo "TOTAL=$total PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]