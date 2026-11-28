"""Pemetaan nama bahan aktif di registri Kementan ke bahan di katalog obat aplikasi."""
import re

# Ejaan di registri tidak seragam; setiap bahan katalog dicocokkan dengan variannya.
BAHAN = {
    'Abamektin': r'aba(m|n)e[ck]tin',
    'Asetamiprid': r'a(s|c|ce)etamiprid|acetamiprid',
    'Azadirachtin (neem)': r'azadira',
    'Beauveria bassiana': r'beauveria|beuveria|bauveria',
    'Buprofezin': r'buprofezin',
    'Diafentiuron': r'diafent|diafenth',
    'Dimpropiridaz': r'dimprop[iy]ridaz',
    'Dinotefuran': r'dinotefu',
    'Flonikamid': r'floni[ck]amid',
    'Flupiradifuron': r'flup[iy]radifur',
    'Imidakloprid': r'imida[ck]lo?p?r?o?r?p?id|imidaklorid|imidaclorpid',
    'Lambda-sihalotrin': r'lam(b)?da.{0,3}(sihalotrin|cyhalothrin|sihalothrin)',
    'Lecanicillium lecanii': r'lecanii|lecanicillium',
    'Metarhizium anisopliae': r'metarhizium anisopliae',
    'Pimetrozin': r'ph?[iy]metro[zs]in',
    'Siantraniliprol': r'(s|c)[iy]antraniliprol',
    'Spinosad': r'spinosad',
    'Spiromesifen': r'spiromesifen',
    'Spirotetramat': r'spirotetramat',
    'Tiametoksam': r'th?iameth?o(x|ks)am|tiamektosam',
    'Sabun insektisida': r'\bsabun\b|potassium salts? of fatty',
}
# Ejaan nyata yang ditemukan di registri; gagal lebih baik daripada diam-diam kurang hitung.
for _name, _variants in {
    'Abamektin': ['abamectin', 'abamektin', 'abamectine'],
    'Asetamiprid': ['acetamiprid', 'asetamiprid'],
    'Azadirachtin (neem)': ['azadirachtan', 'azadiraktin'],
    'Imidakloprid': ['imidacloprid', 'imidakloprid', 'imidaclorpid', 'imidaklorid'],
    'Lambda-sihalotrin': ['lambda cyhalothrin', 'lamda sihalotrin', 'lamdasihalotrin', 'lambda-cyhalothrin'],
    'Pimetrozin': ['pimetrozin', 'pymetrozine', 'phymetrozine'],
    'Tiametoksam': ['thiamethoxam', 'thiametoxam', 'tiametoksam', 'tiamektosam'],
}.items():
    _missed = [v for v in _variants if not re.search(BAHAN[_name], v)]
    assert not _missed, f'{_name} tidak mencocokkan {_missed}'
