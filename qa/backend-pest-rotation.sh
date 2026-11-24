#!/usr/bin/env bash
# HidroSense QA — fitur baru backend: pindai hama, rotasi obat, unggahan foto.
#
#   BASE_URL=http://127.0.0.1:3100/api/v1 \
#   CLOUDINARY_API_SECRET=... bash qa/backend-pest-rotation.sh
#
# Prasyarat: server backend pada BASE_URL memakai database uji yang sudah
# dimigrasi + diseed, DAN dikonfigurasi Cloudinary (CLOUDINARY_CLOUD_NAME,
# CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET) — tanpa itu pindaian/unggahan
# membalas 503. Jangan arahkan ke data produksi.
#
# Cakupan: unggahan tanda tangan (§5.5), pindaian foto (§5.5), mesin rotasi
# MoA + terima/tolak + potong stok (§5.8). Bukti: respons HTTP nyata, bukan
# klaim test unit.
set -u
BASE="${BASE_URL:-http://127.0.0.1:3100/api/v1}"
TMP="${TMPDIR:-/tmp}/hsqa-pest"; mkdir -p "$TMP"
pass=0; fail=0; total=0; skips=0
ok()   { total=$((total+1)); pass=$((pass+1)); printf 'PASS %-6s | %s\n' "$1" "$2"; }
bad()  { total=$((total+1)); fail=$((fail+1)); printf 'FAIL %-6s | %s | harap [%s] dapat [%s]\n' "$1" "$2" "$4" "$3"; }
skip() { total=$((total+1)); skips=$((skips+1)); printf 'SKIP %-6s | %s\n' "$1" "$2"; }
eq()   { if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2" "$3" "$4"; fi; }
ne()   { if [ "$3" != "$4" ]; then ok "$1" "$2"; else bad "$1" "$2" "$3" "bukan $4"; fi; }

# Body kosong: JANGAN kirim Content-Type JSON (Fastify menolak body JSON kosong
# dengan 400). Ini meniru ApiClient mobile: header itu hanya dikirim bila ada body.
req() { # METHOD PATH BODY TOKEN [EXTRA_HEADER...]
  local method="$1" path="$2" body="${3:-}" token="${4:-}" ; shift 4 || true
  local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$method" "$BASE$path")
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  local haskey=0
  for h in "$@"; do [ "${h%%:*}" = "Idempotency-Key" ] && haskey=1; args+=(-H "$h"); done
  [ "$haskey" = "0" ] && [ "$method" != "GET" ] && args+=(-H "Idempotency-Key: $(uuid)")
  curl "${args[@]}"
}
reqnokey() { # METHOD PATH BODY TOKEN  -> no Idempotency-Key at all
  local method="$1" path="$2" body="${3:-}" token="${4:-}"
  local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$method" "$BASE$path")
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
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
days_ahead() { date -d "$1 days" +%F; }
days_ago() { date -d "$1 days ago" +%F; }
sha1() { python3 -c 'import hashlib,sys;print(hashlib.sha1(sys.argv[1].encode()).hexdigest())' "$1"; }

# --- login ---
TP=$(req POST /auth/login '{"username":"petani","password":"Petani123456!"}' "" >/dev/null; body | jget data.access_token)
TE=$(req POST /auth/login '{"username":"pegawai","password":"Pegawai123456!"}' "" >/dev/null; body | jget data.access_token)
[ -n "$TP" ] || { echo "login petani gagal (rate limit? hapus tabel auth_rate_limits lalu ulangi)"; exit 1; }
[ -n "$TE" ] || { echo "login pegawai gagal"; exit 1; }
PETANI_ID=$(req GET /auth/me '' "$TP" >/dev/null; body | jget data.id_user)

# --- fixture: unggahan -> cloud_name, folder, signature ---
req POST /unggahan/tanda-tangan '' "$TP" >/dev/null
CLOUD=$(body | jget data.cloud_name)
FOLDER=$(body | jget data.folder)
SIG=$(body | jget data.signature)
TS=$(body | jget data.timestamp)
UPURL=$(body | jget data.upload_url)

echo "== A. Unggahan tanda tangan (§5.5) =="
eq "UP-01" "petani dapat tanda tangan (200)" "$(req POST /unggahan/tanda-tangan '' "$TP")" "200"
eq "UP-02" "folder terkunci per pengguna" "$FOLDER" "hidrosense/pindai/$PETANI_ID"
eq "UP-03" "signature sha1 40 heks" "$(printf '%s' "$SIG" | grep -cE '^[0-9a-f]{40}$')" "1"
eq "UP-04" "upload_url menunjuk endpoint Cloudinary akun ini" "$UPURL" "https://api.cloudinary.com/v1_1/$CLOUD/image/upload"
if [ -n "${CLOUDINARY_API_SECRET:-}" ]; then
  EXPECT="$(sha1 "folder=$FOLDER&timestamp=$TS$CLOUDINARY_API_SECRET")"
  eq "UP-05" "signature = sha1(folder,timestamp + secret)" "$SIG" "$EXPECT"
else
  skip "UP-05" "verifikasi signature butuh CLOUDINARY_API_SECRET di env"
fi
eq "UP-06" "pegawai ditolak (tanpa deteksi:write)" "$(req POST /unggahan/tanda-tangan '' "$TE")" "403"
eq "UP-07" "tanpa token ditolak" "$(req POST /unggahan/tanda-tangan '' '')" "401"

echo "== B. Pindaian foto hama (§5.5) =="
# Fixture: jenis + benih + penyemaian + dua meja/pemindahan.
JID=$(req POST /jenis-inventaris "{\"nama_jenis\":\"PESTQA-$RANDOM\"}" "$TP" >/dev/null; body | jget data.id_jenis_inventaris)
BID=$(req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Benih QA\",\"satuan\":\"pak\",\"stok_minimum\":null}" "$TP" >/dev/null; body | jget data.id_inventaris)
req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"50.00\",\"satuan\":\"pak\"}]}" "$TP" >/dev/null
BAHAN=$(req POST /inventaris "{\"id_jenis_inventaris\":\"$JID\",\"nama_barang\":\"Bahan QA\",\"satuan\":\"liter\",\"stok_minimum\":null}" "$TP" >/dev/null; body | jget data.id_inventaris)
req POST /stok "{\"jenis_stok\":\"masuk\",\"details\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"10.00\",\"satuan\":\"liter\"}]}" "$TP" >/dev/null
SID=$(req POST /penyemaian "{\"tanggal_semai\":\"$(days_ago 20)\",\"jumlah_benih\":100,\"materials\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"5.00\",\"satuan\":\"pak\"}]}" "$TP" >/dev/null; body | jget data.id_penyemaian)
MF=$(req POST /meja-tanam "{\"kode_meja\":\"PQ-F-$RANDOM\",\"jumlah_lubang\":60}" "$TP" >/dev/null; body | jget data.id_meja)
MIDS=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID\",\"id_meja\":\"$MF\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":40}" "$TP" >/dev/null; body | jget data.id_pemindahan)
MX=$(req POST /meja-tanam "{\"kode_meja\":\"PQ-X-$RANDOM\",\"jumlah_lubang\":60}" "$TP" >/dev/null; body | jget data.id_meja)
MIDX=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID\",\"id_meja\":\"$MX\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":20}" "$TP" >/dev/null; body | jget data.id_pemindahan)
MF2=$(req POST /meja-tanam "{\"kode_meja\":\"PQ-R-$RANDOM\",\"jumlah_lubang\":60}" "$TP" >/dev/null; body | jget data.id_meja)
MID2=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID\",\"id_meja\":\"$MF2\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":20}" "$TP" >/dev/null; body | jget data.id_pemindahan)

IMG="https://res.cloudinary.com/$CLOUD/image/upload/v1712345678/hidrosense/pindai/$PETANI_ID/foto-$RANDOM.jpg"
PUB="hidrosense/pindai/$PETANI_ID/foto-$RANDOM.jpg"
SCANBODY="{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"cloudinary_public_id\":\"$PUB\",\"versi_model\":\"yolo11n-fp16-cd388bda\",\"deteksi\":[{\"hama\":\"thrips\",\"jumlah\":3,\"confidence_maks\":0.91}]}"

eq "SC-01" "buat pindaian valid -> 201" "$(req POST /pindaian "$SCANBODY" "$TP")" "201"
SID_SCAN=$(body | jget data.id_hasil_deteksi)
eq "SC-02" "deteksi per kelas tersimpan" "$(body | jget data.deteksi.0.hama)" "thrips"
eq "SC-03" "jumlah deteksi tersimpan" "$(body | jget data.deteksi.0.jumlah)" "3"
eq "SC-04" "id_meja ikut dari pemindahan" "$(body | jget data.id_meja)" "$MF"

eq "SC-05" "deteksi kosong (tak ada hama) tetap 201" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "201"
eq "SC-06" "deteksi kosong -> []" "$(body | jget data.deteksi)" "[]"
eq "SC-07" "hama ganda dalam satu foto -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[{\"hama\":\"thrips\",\"jumlah\":1},{\"hama\":\"thrips\",\"jumlah\":2}]}" "$TP")" "400"
eq "SC-08" "lebih dari 3 kelas -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[{\"hama\":\"thrips\",\"jumlah\":1},{\"hama\":\"whitefly\",\"jumlah\":1},{\"hama\":\"aphids\",\"jumlah\":1},{\"hama\":\"thrips\",\"jumlah\":1}]}" "$TP")" "400"
eq "SC-09" "jumlah 0 -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[{\"hama\":\"thrips\",\"jumlah\":0}]}" "$TP")" "400"
eq "SC-10" "confidence > 1 -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[{\"hama\":\"thrips\",\"jumlah\":1,\"confidence_maks\":1.5}]}" "$TP")" "400"
eq "SC-11" "hama di luar daftar -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[{\"hama\":\"ulat\",\"jumlah\":1}]}" "$TP")" "400"
eq "SC-12" "versi_model kosong -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"versi_model\":\"\",\"deteksi\":[]}" "$TP")" "400"

FOREIGN="https://res.cloudinary.com/$CLOUD/image/upload/v1/hidrosense/pindai/999999/foto.jpg"
eq "SC-13" "foto folder pengguna lain -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$FOREIGN\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "400"
eq "SC-14" "skema http (bukan https) -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"http://res.cloudinary.com/$CLOUD/image/upload/v1/hidrosense/pindai/$PETANI_ID/f.jpg\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "400"
eq "SC-15" "host bukan res.cloudinary.com -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"https://evil.example.com/$CLOUD/image/upload/v1/hidrosense/pindai/$PETANI_ID/f.jpg\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "400"
eq "SC-16" "URL ber-query -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG?x=1\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "400"
eq "SC-17" "public_id di luar folder -> 400" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG\",\"cloudinary_public_id\":\"hidrosense/pindai/999999/x.jpg\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "400"
eq "SC-18" "id_pemindahan tak ada -> 422" "$(req POST /pindaian "{\"id_pemindahan\":\"999999\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP")" "422"
eq "SC-19" "kode TRANSFER_NOT_FOUND" "$(body | jget error.code)" "TRANSFER_NOT_FOUND"
eq "SC-20" "tanpa Idempotency-Key -> 400" "$(reqnokey POST /pindaian "$SCANBODY" "$TP")" "400"

KEY=$(uuid)
eq "SC-21" "kiriman pertama dengan kunci tetap" "$(req POST /pindaian "$SCANBODY" "$TP" "Idempotency-Key: $KEY")" "201"
FIRST_ID=$(body | jget data.id_hasil_deteksi)
eq "SC-22" "ulang kunci+isi sama -> 200" "$(req POST /pindaian "$SCANBODY" "$TP" "Idempotency-Key: $KEY")" "200"
eq "SC-23" "ditandai replayed" "$(body | jget replayed)" "True"
eq "SC-24" "id sama (tidak membuat baris baru)" "$(body | jget data.id_hasil_deteksi)" "$FIRST_ID"

req GET "/pindaian/$SID_SCAN" '' "$TP" >/dev/null
eq "SC-25" "GET detail pindaian" "$(body | jget data.id_hasil_deteksi)" "$SID_SCAN"
req GET "/pindaian?id_pemindahan=$MIDS&limit=100" '' "$TP" >/dev/null
eq "SC-26" "GET daftar memuat pindaian itu" "$(body | python3 -c "import sys,json;d=json.load(sys.stdin);print(any(x['id_hasil_deteksi']=='$SID_SCAN' for x in d['data']))")" "True"
eq "SC-27" "GET pindaian tak ada -> 404" "$(req GET /pindaian/999999 '' "$TP")" "404"
eq "SC-28" "pegawai baca pindaian ditolak" "$(req GET /pindaian '' "$TE")" "403"
eq "SC-29" "pegawai buat pindaian ditolak" "$(req POST /pindaian "$SCANBODY" "$TE")" "403"

echo "== C. Mesin rotasi obat (§5.8) =="
eq "RC-01" "berat tanpa riwayat -> 201, kimia" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\"}" "$TP")" "201"
RA=$(body | jget data.id_rekomendasi)
eq "RC-02" "rule ROT-MOA" "$(body | jget data.rule_id)" "ROT-MOA"
eq "RC-03" "obat kimia" "$(body | jget data.obat.jenis)" "kimia"
eq "RC-04" "tanpa riwayat: alasan menyebut belum ada riwayat MoA" "$(body | python3 -c 'import sys,json;print("Belum ada riwayat MoA" in json.load(sys.stdin)["data"]["alasan"])')" "True"
eq "RC-05" "ulang penilaian sama -> 200 replayed" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\"}" "$TP")" "200"
eq "RC-06" "replayed true" "$(body | jget replayed)" "True"
eq "RC-07" "tingkat baru -> hitung ulang (replayed false)" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"ringan\"}" "$TP")" "200"
eq "RC-08" "tingkat ringan -> cara nonkimia (ROT-PHT)" "$(body | jget data.rule_id)" "ROT-PHT"
eq "RC-09" "obat ringan bukan kimia" "$(body | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["obat"]["jenis"]!="kimia")')" "True"
eq "RC-10" "kembali ke berat (recomputed)" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\"}" "$TP")" "200"
eq "RC-11" "id_meja tak ada -> 422" "$(req POST /rekomendasi-obat '{"id_meja":"999999","hama":"thrips","tingkat":"berat"}' "$TP")" "422"
eq "RC-12" "kode TABLE_NOT_FOUND" "$(body | jget error.code)" "TABLE_NOT_FOUND"
# Scan milik MX dipakai pada meja MF -> harus mismatch.
req POST /pindaian "{\"id_pemindahan\":\"$MIDX\",\"gambar\":\"$IMG\",\"versi_model\":\"v\",\"deteksi\":[{\"hama\":\"aphids\",\"jumlah\":2}]}" "$TP" >/dev/null
SCANX=$(body | jget data.id_hasil_deteksi)
eq "RC-13" "foto dari meja lain -> 422" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\",\"id_hasil_deteksi\":\"$SCANX\"}" "$TP")" "422"
eq "RC-14" "kode DETECTION_TABLE_MISMATCH" "$(body | jget error.code)" "DETECTION_TABLE_MISMATCH"
eq "RC-15" "id_hasil_deteksi tak ada -> 422" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\",\"id_hasil_deteksi\":\"999999\"}" "$TP")" "422"
eq "RC-16" "kode DETECTION_NOT_FOUND" "$(body | jget error.code)" "DETECTION_NOT_FOUND"
eq "RC-17" "pakai foto meja sendiri -> diterima" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\",\"id_hasil_deteksi\":\"$SID_SCAN\"}" "$TP")" "200"
eq "RC-18" "obat tetap terisi" "$(body | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["data"]["obat"]["bahan_aktif"])>0)')" "True"
eq "RC-19" "hama di luar daftar -> 400" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"ulat\",\"tingkat\":\"berat\"}" "$TP")" "400"
eq "RC-20" "pegawai buat rekomendasi ditolak" "$(req POST /rekomendasi-obat "{\"id_meja\":\"$MF\",\"hama\":\"thrips\",\"tingkat\":\"berat\"}" "$TE")" "403"
eq "RC-21" "GET rekomendasi id tak ada -> 404" "$(req GET /rekomendasi-obat/999999 '' "$TP")" "404"
eq "RC-22" "GET daftar status=menunggu memuat saran" "$(req GET "/rekomendasi-obat?status=menunggu&id_meja=$MF" '' "$TP")" "200"

echo "== D. Terima / tolak + potong stok (§5.8) =="
# Storyline terima+pemotongan stok pada MX (aphids).
req POST /rekomendasi-obat "{\"id_meja\":\"$MX\",\"hama\":\"aphids\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
RB=$(body | jget data.id_rekomendasi)
MOA_B=$(body | jget data.obat.kode_moa)
eq "DC-01" "saran aphids dibuat" "$([ -n "$RB" ] && echo ok)" "ok"
eq "DC-02" "tolak tanpa alasan -> 400" "$(req POST "/rekomendasi-obat/$RB/tolak" '{}' "$TP")" "400"
eq "DC-03" "tolak alasan 'lainnya' tanpa catatan -> 400" "$(req POST "/rekomendasi-obat/$RB/tolak" '{"alasan":"lainnya"}' "$TP")" "400"
eq "DC-04" "stok kurang membatalkan terima -> 409" "$(req POST "/rekomendasi-obat/$RB/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"999.00\",\"satuan\":\"liter\"}]}" "$TP")" "409"
eq "DC-05" "kode INSUFFICIENT_STOCK" "$(body | jget error.code)" "INSUFFICIENT_STOCK"
req GET "/rekomendasi-obat/$RB" '' "$TP" >/dev/null
eq "DC-06" "setelah gagal, status tetap menunggu (rollback)" "$(body | jget data.status)" "menunggu"
req GET "/inventaris/$BAHAN/saldo" '' "$TP" >/dev/null
eq "DC-07" "saldo bahan tidak berkurang setelah gagal" "$(body | jget data.saldo)" "10"
eq "DC-08" "satuan salah -> 422" "$(req POST "/rekomendasi-obat/$RB/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1.00\",\"satuan\":\"pak\"}]}" "$TP")" "422"
eq "DC-09" "kode UNIT_MISMATCH" "$(body | jget error.code)" "UNIT_MISMATCH"
eq "DC-10" "barang ganda dalam bahan -> 400" "$(req POST "/rekomendasi-obat/$RB/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1.00\",\"satuan\":\"liter\"},{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1.00\",\"satuan\":\"liter\"}]}" "$TP")" "400"
eq "DC-11" "lebih dari 5 baris bahan -> 400" "$(req POST "/rekomendasi-obat/$RB/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1\",\"satuan\":\"liter\"},{\"id_inventaris\":\"$BID\",\"jumlah\":\"1\",\"satuan\":\"pak\"},{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1\",\"satuan\":\"liter\"},{\"id_inventaris\":\"$BID\",\"jumlah\":\"1\",\"satuan\":\"pak\"},{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1\",\"satuan\":\"liter\"},{\"id_inventaris\":\"$BID\",\"jumlah\":\"1\",\"satuan\":\"pak\"}]}" "$TP")" "400"

# Terima sebenarnya dengan pemotongan stok 2 liter.
KEYA=$(uuid)
eq "DC-12" "terima dengan bahan 2 liter -> 200" "$(req POST "/rekomendasi-obat/$RB/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"2.00\",\"satuan\":\"liter\"}]}" "$TP" "Idempotency-Key: $KEYA")" "200"
eq "DC-13" "status diterima" "$(body | jget data.status)" "diterima"
eq "DC-14" "tanggal_aplikasi terisi hari ini" "$(body | jget data.tanggal_aplikasi)" "$(today)"
eq "DC-15" "bahan_terpakai memuat barang" "$(body | jget data.bahan_terpakai.0.id_inventaris)" "$BAHAN"
eq "DC-16" "jumlah bahan terpakai 2.00" "$(body | jget data.bahan_terpakai.0.jumlah)" "2"
req GET "/inventaris/$BAHAN/saldo" '' "$TP" >/dev/null
eq "DC-17" "saldo bahan 10-2=8" "$(body | jget data.saldo)" "8"

eq "DC-18" "ulang terima dengan isi sama -> 200 replayed" "$(req POST "/rekomendasi-obat/$RB/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"2.0\",\"satuan\":\"liter\"}]}" "$TP")" "200"
eq "DC-19" "replayed true" "$(body | jget replayed)" "True"
req GET "/inventaris/$BAHAN/saldo" '' "$TP" >/dev/null
eq "DC-20" "saldo tidak terpotong dua kali" "$(body | jget data.saldo)" "8"
eq "DC-21" "terima dengan catatan berbeda -> 409" "$(req POST "/rekomendasi-obat/$RB/terima" '{"catatan":"berbeda"}' "$TP")" "409"
eq "DC-22" "kode RECOMMENDATION_ALREADY_DECIDED" "$(body | jget error.code)" "RECOMMENDATION_ALREADY_DECIDED"
eq "DC-23" "tolak yang sudah diterima -> 409" "$(req POST "/rekomendasi-obat/$RB/tolak" '{"alasan":"sudah_ditangani"}' "$TP")" "409"
eq "DC-24" "pegawai terima rekomendasi ditolak" "$(req POST "/rekomendasi-obat/$RB/terima" '{}' "$TE")" "403"

# Jendela MoA: saran berikutnya tidak boleh memakai MoA yang baru dipakai.
req POST /rekomendasi-obat "{\"id_meja\":\"$MX\",\"hama\":\"aphids\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
MOA_B2=$(body | jget data.obat.kode_moa)
echo "    (MoA diterima=$MOA_B, saran berikut=$MOA_B2)"
ne "MO-01" "saran berikut tidak memakai MoA terakhir" "$MOA_B2" "$MOA_B"

# Tolak karena tidak tersedia -> obat itu tidak disarankan lagi (R4).
req POST /rekomendasi-obat "{\"id_meja\":\"$MF2\",\"hama\":\"whitefly\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
RC=$(body | jget data.id_rekomendasi)
DRUG=$(body | jget data.obat.id_katalog)
eq "DC-25" "tolak alasan tidak_tersedia -> 200" "$(req POST "/rekomendasi-obat/$RC/tolak" '{"alasan":"tidak_tersedia"}' "$TP")" "200"
eq "DC-26" "status ditolak" "$(body | jget data.status)" "ditolak"
eq "DC-27" "ulang tolak sama -> 200 replayed" "$(req POST "/rekomendasi-obat/$RC/tolak" '{"alasan":"tidak_tersedia"}' "$TP")" "200"
eq "DC-28" "tolak beda alasan -> 409" "$(req POST "/rekomendasi-obat/$RC/tolak" '{"alasan":"harga"}' "$TP")" "409"
eq "DC-29" "terima yang sudah ditolak -> 409" "$(req POST "/rekomendasi-obat/$RC/terima" '{}' "$TP")" "409"
req POST /rekomendasi-obat "{\"id_meja\":\"$MF2\",\"hama\":\"whitefly\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
eq "DC-30" "saran baru dibuat setelah penolakan" "$(body | jget replayed)" "False"
ne "MO-02" "obat yang ditolak tidak disarankan lagi" "$(body | jget data.obat.id_katalog)" "$DRUG"

echo "== E. Kasus tepi & balapan (§5.8) =="
SID2=$(req POST /penyemaian "{\"tanggal_semai\":\"$(days_ago 10)\",\"jumlah_benih\":100,\"materials\":[{\"id_inventaris\":\"$BID\",\"jumlah\":\"1.00\",\"satuan\":\"pak\"}]}" "$TP" >/dev/null; body | jget data.id_penyemaian)
ME1=$(req POST /meja-tanam "{\"kode_meja\":\"PQ-E1-$RANDOM\",\"jumlah_lubang\":60}" "$TP" >/dev/null; body | jget data.id_meja)
MIDE1=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID2\",\"id_meja\":\"$ME1\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":20}" "$TP" >/dev/null; body | jget data.id_pemindahan)
ME2=$(req POST /meja-tanam "{\"kode_meja\":\"PQ-E2-$RANDOM\",\"jumlah_lubang\":60}" "$TP" >/dev/null; body | jget data.id_meja)
MIDE2=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID2\",\"id_meja\":\"$ME2\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":20}" "$TP" >/dev/null; body | jget data.id_pemindahan)
ME3=$(req POST /meja-tanam "{\"kode_meja\":\"PQ-E3-$RANDOM\",\"jumlah_lubang\":60}" "$TP" >/dev/null; body | jget data.id_meja)
MIDE3=$(req POST /pemindahan "{\"id_penyemaian\":\"$SID2\",\"id_meja\":\"$ME3\",\"tanggal_pemindahan\":\"$(today)\",\"jumlah_tanaman\":20}" "$TP" >/dev/null; body | jget data.id_pemindahan)

# R4 berlaku di seluruh kebun: obat yang ditolak di MF2 tidak boleh muncul di meja baru tanpa riwayat.
req POST /rekomendasi-obat "{\"id_meja\":\"$ME1\",\"hama\":\"whitefly\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
ne "E-01" "penolakan tidak_tersedia berlaku lintas meja" "$(body | jget data.obat.id_katalog)" "$DRUG"
ME1R=$(body | jget data.id_rekomendasi)
PAST=$(days_ago 5)
eq "E-02" "terima dengan tanggal lampau -> 200" "$(req POST "/rekomendasi-obat/$ME1R/terima" "{\"tanggal_aplikasi\":\"$PAST\"}" "$TP")" "200"
eq "E-03" "tanggal_aplikasi = tanggal lampau" "$(body | jget data.tanggal_aplikasi)" "$PAST"

req POST /rekomendasi-obat "{\"id_meja\":\"$ME2\",\"hama\":\"thrips\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
ME2R=$(body | jget data.id_rekomendasi)
eq "E-04" "bahan_barang tak ada -> 422" "$(req POST "/rekomendasi-obat/$ME2R/terima" '{"bahan":[{"id_inventaris":"999999","jumlah":"1.00","satuan":"liter"}]}' "$TP")" "422"
eq "E-05" "kode INVENTARIS_NOT_AVAILABLE" "$(body | jget error.code)" "INVENTARIS_NOT_AVAILABLE"
eq "E-06" "jumlah bahan 0 -> 400" "$(req POST "/rekomendasi-obat/$ME2R/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"0\",\"satuan\":\"liter\"}]}" "$TP")" "400"
eq "E-07" "jumlah bahan negatif -> 400" "$(req POST "/rekomendasi-obat/$ME2R/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"-1\",\"satuan\":\"liter\"}]}" "$TP")" "400"

# Atomik: satu baris bahan kurang -> tidak ada yang terpotong.
eq "E-08" "salah satu bahan kurang -> 409, seluruhnya batal" "$(req POST "/rekomendasi-obat/$ME2R/terima" "{\"bahan\":[{\"id_inventaris\":\"$BAHAN\",\"jumlah\":\"1.00\",\"satuan\":\"liter\"},{\"id_inventaris\":\"$BID\",\"jumlah\":\"9999\",\"satuan\":\"pak\"}]}" "$TP")" "409"
req GET "/inventaris/$BAHAN/saldo" '' "$TP" >/dev/null
eq "E-09" "bahan pertama tidak ikut terpotong" "$(body | jget data.saldo)" "8"
req GET "/rekomendasi-obat/$ME2R" '' "$TP" >/dev/null
eq "E-10" "status tetap menunggu setelah gagal" "$(body | jget data.status)" "menunggu"

# Balapan: lima terima paralel pada satu saran -> satu efek nyata, tanpa 5xx.
req POST /rekomendasi-obat "{\"id_meja\":\"$ME3\",\"hama\":\"aphids\",\"tingkat\":\"berat\"}" "$TP" >/dev/null
ME3R=$(body | jget data.id_rekomendasi)
rm -f "$TMP"/acc_* "$TMP"/code_*
for i in $(seq 1 5); do
  curl -s -o "$TMP/acc_$i" -w '%{http_code}' -X POST "$BASE/rekomendasi-obat/$ME3R/terima" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $TP" \
    -H "Idempotency-Key: $(uuid)" -d '{}' > "$TMP/code_$i" &
done
wait
APPLIED=0; REPLAYED=0; CONFLICT=0; ODD=0
for i in $(seq 1 5); do
  code=$(cat "$TMP/code_$i")
  rp=$(python3 -c 'import sys,json
try: print(json.load(open(sys.argv[1])).get("replayed"))
except Exception: print("ODD")' "$TMP/acc_$i")
  if [ "$code" = "200" ] && [ "$rp" = "False" ]; then APPLIED=$((APPLIED+1))
  elif [ "$code" = "200" ] && [ "$rp" = "True" ]; then REPLAYED=$((REPLAYED+1))
  elif [ "$code" = "409" ]; then CONFLICT=$((CONFLICT+1))
  else ODD=$((ODD+1)); fi
done
eq "E-11" "tepat satu terima yang berefek nyata" "$APPLIED" "1"
eq "E-12" "sisanya replay atau 409, tanpa galat 5xx" "$((REPLAYED+CONFLICT))" "4"
eq "E-13" "tidak ada jawaban rusak/5xx" "$ODD" "0"

# Idempotensi pindaian: kunci sama, isi beda -> 409.
KEYC=$(uuid)
IMG2="https://res.cloudinary.com/$CLOUD/image/upload/v1/hidrosense/pindai/$PETANI_ID/c-$RANDOM.jpg"
req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"$IMG2\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP" "Idempotency-Key: $KEYC" >/dev/null
eq "E-14" "kunci pindaian sama + isi beda -> 409" "$(req POST /pindaian "{\"id_pemindahan\":\"$MIDS\",\"gambar\":\"https://res.cloudinary.com/$CLOUD/image/upload/v1/hidrosense/pindai/$PETANI_ID/d.jpg\",\"versi_model\":\"v\",\"deteksi\":[]}" "$TP" "Idempotency-Key: $KEYC")" "409"
eq "E-15" "kode OPERATION_CONFLICT" "$(body | jget error.code)" "OPERATION_CONFLICT"

# Sinkronisasi mencakup entitas baru.
req GET "/sync/changes?cursor=0&limit=200" '' "$TP" >/dev/null
eq "E-16" "sync memuat hasil_deteksi" "$(body | python3 -c 'import sys,json;d=json.load(sys.stdin);print(any(r["resource_type"]=="hasil_deteksi" for r in d["data"]))')" "True"
eq "E-17" "sync memuat rekomendasi_perawatan" "$(body | python3 -c 'import sys,json;d=json.load(sys.stdin);print(any(r["resource_type"]=="rekomendasi_perawatan" for r in d["data"]))')" "True"
eq "E-18" "batas daftar pindaian: limit 0 -> 400" "$(req GET '/pindaian?limit=0' '' "$TP")" "400"
eq "E-19" "batas daftar pindaian: limit 201 -> 400" "$(req GET '/pindaian?limit=201' '' "$TP")" "400"

echo "== Ringkasan =="
echo "TOTAL=$total PASS=$pass FAIL=$fail SKIP=$skips"
[ "$fail" -eq 0 ]
