# HidroSense — Persediaan

Istilah berikut merujuk pada pencatatan persediaan HidroSense. Definisi mengikuti kontrak B006 yang sudah disepakati.

## Bahasa domain

**Transaksi stok (Stock movement)**:
Catatan penerimaan atau pemakaian satu atau beberapa barang inventaris, dengan jumlah dan satuan masing-masing.
_Avoid_: perubahan saldo langsung.

**Saldo stok (Stock balance)**:
Jumlah barang inventaris yang tersedia setelah seluruh penerimaan, pemakaian, dan reversal diperhitungkan.
_Avoid_: jumlah penerimaan total.

**Reversal**:
Transaksi stok baru yang membalik seluruh transaksi stok asal dengan jumlah dan satuan yang sama serta arah berlawanan. Reversal mempertahankan catatan asal.
_Avoid_: penghapusan transaksi asal, perubahan transaksi asal, reversal sebagian.

**Koreksi stok**:
Pembetulan transaksi stok melalui reversal dan, bila diperlukan, transaksi pengganti yang dicatat terpisah.
_Avoid_: mengubah catatan historis.

**Asal konsumsi (Consumption origin)**:
Kegiatan penyemaian atau perawatan yang menjadi alasan pemakaian persediaan. Koreksi pemakaian tersebut harus menjaga konsistensi kegiatan asalnya.
_Avoid_: keputusan perawatan yang belum dilaksanakan.
