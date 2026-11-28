"""Menyusun dataset kutu daun dan kutu kebul dari hasil crawl registri pestisida Kementan.

Sumber: https://ap-simpel.pertanian.go.id/pestisida?kategori_formula=pestisida_terdaftar
(butuh login pengguna). Berkas mentah tidak disimpan di repo.

Pemakaian: python -I susun_dataset.py <raw.json> <ext.json> <keluaran.csv> <ringkasan.json>
"""
import collections
import csv
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bahan import BAHAN  # noqa: E402

raw_path, ext_path, csv_path, summary_path = sys.argv[1:5]
with open(raw_path, encoding='utf-8') as handle:
    raw = json.load(handle)
with open(ext_path, encoding='utf-8') as handle:
    ext = json.load(handle)['result']['ext']
today = raw['fetchedAt'][:10]

HAMA = {
    'kutu daun': r'aphis|myzus|nasonovia|toxoptera|aphid|kutu ?daun',
    'kutu kebul': r'bemisia|trialeurodes|kutu ?kebul|whitefl',
    'thrips': r'thrips|\btrips\b',
}
HEADER = ['merk_dagang', 'nomor_pendaftaran', 'jenis_pestisida', 'bahan_aktif', 'komoditas', 'hama',
          'hama_latin', 'dosis', 'satuan_dosis', 'tanggal_terbit', 'tanggal_berakhir', 'asal_data']


def load(text):
    return json.loads(text) if text else []


def clean(text):
    return re.sub(r'\s+', ' ', str(text or '')).strip()


products = {row['id']: row for row in raw['rows']}
records = [(row, 'utama') for row in products.values()]
records += [(row, 'perluasan') for rows in ext.values() for row in rows]

out = set()
summary = {name: {h: {'produk': set(), 'komoditas': collections.Counter()} for h in HAMA} for name in BAHAN}
lettuce = 0
for row, origin in records:
    ingredients = {}
    for item in load(row.get('bahanAktif')):
        name = clean(item.get('namaBahan'))
        if name:
            amount = f"{clean(item.get('kadarBahan'))} {clean(item.get('satuanBahan'))}"
            ingredients[name.lower()] = f'{name} {amount}'.strip()
    joined = ' | '.join(sorted(ingredients))
    if re.search(r'selada|lactuca|lettuce', json.dumps(row), re.I):
        lettuce += 1
    for target in load(row.get('Komoditas')):
        crop = clean(target.get('namaKomoditas'))
        pest = clean(target.get('hamaKomoditas'))
        latin = clean(target.get('latinHamaKomoditas'))
        found = [h for h, pattern in HAMA.items() if re.search(pattern, f'{pest} {latin}', re.I)]
        if not found:
            continue
        active = (row.get('TanggalBerakhir') or '') >= today
        # "Cabai (1,5 ml/l)" dan "Cabai:" adalah komoditas yang sama.
        base_crop = clean(re.sub(r'\(.*?\)|:', '', crop)).capitalize()
        for name, pattern in BAHAN.items():
            if active and re.search(pattern, joined, re.I):
                for h in found:
                    summary[name][h]['produk'].add(row['nomorPendaftaran'])
                    summary[name][h]['komoditas'][base_crop] += 1
        if 'kutu daun' in found or 'kutu kebul' in found:
            out.add((
                clean(row['namaProduk']), clean(row['nomorPendaftaran']), clean(row['JenisPestisidaNama']),
                '; '.join(ingredients[k] for k in sorted(ingredients)), base_crop, pest, latin,
                clean(target.get('kadarPestisida')), clean(target.get('satuanPestisida')),
                clean(row.get('TanggalTerbit')), clean(row.get('TanggalBerakhir')), origin,
            ))

with open(csv_path, 'w', encoding='utf-8', newline='') as handle:
    writer = csv.writer(handle, lineterminator='\n')
    writer.writerow(HEADER)
    writer.writerows(sorted(out))

report = {
    'diambil': today,
    'entri_unik': len(products),
    'total_dilaporkan_server': raw['total'],
    'baris_perluasan': sum(len(v) for v in ext.values()),
    'entri_selada': lettuce,
    'baris_csv': len(out),
    'produk_csv': len({r[1] for r in out}),
    'bahan': {
        name: {h: {'produk': len(v['produk']), 'komoditas': [c for c, _ in v['komoditas'].most_common(6)]}
               for h, v in per.items()}
        for name, per in summary.items()
    },
}
with open(summary_path, 'w', encoding='utf-8') as handle:
    json.dump(report, handle, ensure_ascii=False, indent=1)
print({k: v for k, v in report.items() if k != 'bahan'})
for name, per in report['bahan'].items():
    print(name, '|', ' | '.join(f"{h}={v['produk']} {','.join(v['komoditas'][:5])}" for h, v in per.items()))
