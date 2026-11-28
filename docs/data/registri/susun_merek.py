"""Menyusun migrasi daftar merek insektisida terdaftar beserta bahan aktifnya.

Dipakai server untuk mengenali barang stok bernama merek (mis. "Confidor 200 SL") saat
rekomendasi diterima, supaya riwayat rotasi mencatat cara kerja yang benar-benar disemprot.

Pemakaian: python -I susun_merek.py <raw.json> > ../../../apps/backend/migrations/<nomor>.up.sql
Normalisasi nama di sini harus sama dengan `kunciMerek` di apps/backend/src/features/rotation/material.ts.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bahan import BAHAN  # noqa: E402

JENIS = {'Insektisida', 'Akarisida'}
# Turso membalas HTTP 502 bila satu INSERT memuat terlalu banyak baris bersubquery: 0026 dengan
# 100 baris per pernyataan mematikan upstream. Batasi baris per pernyataan, dan tetap di bawah
# batas 300 baris berkas migrations/.
ROWS_PER_STATEMENT = 50
FORMULASI = {
    'AS', 'CB', 'CS', 'D', 'DP', 'EC', 'EO', 'EW', 'F', 'G', 'GR', 'L', 'ME', 'OD', 'P', 'RB', 'SC',
    'SE', 'SG', 'SL', 'SP', 'WDG', 'WG', 'WP', 'WS', 'WSC', 'ZC',
}


def kunci(nama):
    return ' '.join(re.sub(r'[^A-Z0-9/.,%]+', ' ', nama.upper()).split())


def dasar(key):
    tokens = key.split()
    while len(tokens) > 1 and (tokens[-1] in FORMULASI or re.fullmatch(r'[\d/.,%]+', tokens[-1])):
        tokens.pop()
    return ' '.join(tokens)


def sql(text):
    return "'" + str(text).replace("'", "''") + "'"


def katalog(nama):
    hits = [name for name, pattern in BAHAN.items() if re.search(pattern, nama, re.I)]
    return hits[0] if len(hits) == 1 else None


def main(raw_path):
    with open(raw_path, encoding='utf-8') as handle:
        raw = json.load(handle)
    products = {row['id']: row for row in raw['rows'] if row.get('JenisPestisidaNama') in JENIS}
    merek, bahan = [], []
    for row in sorted(products.values(), key=lambda r: (kunci(r['namaProduk']), r['nomorPendaftaran'])):
        seen = {}
        for item in json.loads(row.get('bahanAktif') or '[]'):
            name = ' '.join(str(item.get('namaBahan') or '').split()).lower().rstrip('.')
            if name and name not in seen:
                seen[name] = katalog(name)
        if not seen:
            continue
        number = len(merek) + 1
        key = kunci(row['namaProduk'])
        merek.append(f"({number}, {sql(' '.join(row['namaProduk'].split()))}, {sql(key)}, {sql(dasar(key))}, "
                     f"{sql(row['nomorPendaftaran'].strip())}, {sql(row.get('TanggalBerakhir') or '')})")
        for name, cat in seen.items():
            target = f"(SELECT id_katalog FROM obat_katalog WHERE bahan_aktif = {sql(cat)})" if cat else 'NULL'
            bahan.append(f'({number}, {sql(name)}, {target})')
    out = [
        '-- Dibuat oleh docs/data/registri/susun_merek.py dari database pestisida terdaftar Kementan',
        f"-- (diambil {raw['fetchedAt'][:10]}). Jangan disunting tangan: ubah skrip lalu buat migrasi baru.",
        f'-- {len(merek)} merek insektisida/akarisida, {len(bahan)} baris bahan aktif.',
    ]
    # Data, bukan kode: beberapa baris data per pernyataan per baris berkas. Batas 50 baris menjaga
    # satu request tetap kecil (Turso 502 untuk INSERT bersubquery yang terlalu besar) sekaligus
    # berkas tetap di bawah batas 300 baris yang berlaku untuk berkas di migrations/.
    for start in range(0, len(merek), ROWS_PER_STATEMENT):
        out.append('INSERT INTO merek_obat (id_merek, nama_merek, kunci, kunci_dasar, nomor_pendaftaran, tanggal_berakhir) VALUES '
                   + ', '.join(merek[start:start + ROWS_PER_STATEMENT]) + ';')
    for start in range(0, len(bahan), ROWS_PER_STATEMENT):
        out.append('INSERT INTO merek_bahan (id_merek, nama_bahan, id_katalog) VALUES '
                   + ', '.join(bahan[start:start + ROWS_PER_STATEMENT]) + ';')
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    print('\n'.join(out))


main(sys.argv[1])
