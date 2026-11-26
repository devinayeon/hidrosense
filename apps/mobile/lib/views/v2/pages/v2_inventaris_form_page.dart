import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../components/v2_inventaris_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_text_field.dart';

/// Form barang (frame 4.10–4.14 untuk tambah, 4.24 untuk ubah).
///
/// Susunan siap: label "Jenis" dengan chip jenis, kolom "Obat" (hanya saat
/// jenis Obat, frame 4.11/4.12), nama barang, satuan, stok awal, dan stok
/// minimum (opsional). Tombolnya "Simpan".
///
/// Mode ubah (frame 4.24) memakai satu kolom lebih sedikit: tanpa "Stok awal",
/// sebagai gantinya ada catatan "Stok diubah lewat Catat stok." Jumlah, riwayat,
/// dan keadaan arsip tidak ikut berubah saat menyimpan.
///
/// Jarak antarbagian 16 saat bersih dan mengeras jadi 12 saat ada galat
/// (frame 4.14). Hint tiap kolom ikut jenis barang dan disembunyikan saat
/// kolomnya bergalat, mengikuti desain. Tombol kembali saat isian sudah
/// disentuh menawarkan "Buang perubahan?" (frame 4.30), dan simpan yang bentrok
/// memakai dialog "Data sudah berubah" (frame 4.31).
class V2InventarisFormPage extends StatefulWidget {
  const V2InventarisFormPage({
    super.key,
    this.initialJenis = V2JenisBarang.benih,
    this.initialItem,
    this.previewObatSheet = false,
    this.previewKeyboard = false,
    this.previewValidation = false,
    this.previewDiscard = false,
    this.previewConflict = false,
    this.obatPilihan = designObatPilihan,
    this.onSubmit,
  });

  /// Frame `4.10 Tambah barang`.
  const V2InventarisFormPage.create({super.key})
    : initialJenis = V2JenisBarang.benih,
      initialItem = null,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewDiscard = false,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.11 Tambah barang, jenis Obat`.
  const V2InventarisFormPage.obat({super.key})
    : initialJenis = V2JenisBarang.obat,
      initialItem = null,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewDiscard = false,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.12 Pilih obat`.
  const V2InventarisFormPage.pilihObat({super.key})
    : initialJenis = V2JenisBarang.obat,
      initialItem = null,
      previewObatSheet = true,
      previewKeyboard = false,
      previewValidation = false,
      previewDiscard = false,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.13 Tambah barang, keyboard`.
  const V2InventarisFormPage.keyboard({super.key})
    : initialJenis = V2JenisBarang.benih,
      initialItem = null,
      previewObatSheet = false,
      previewKeyboard = true,
      previewValidation = false,
      previewDiscard = false,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.14 Tambah barang, validasi`.
  const V2InventarisFormPage.validation({super.key})
    : initialJenis = V2JenisBarang.benih,
      initialItem = null,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = true,
      previewDiscard = false,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.24 Ubah barang`.
  const V2InventarisFormPage.ubah({super.key})
    : initialJenis = V2JenisBarang.benih,
      initialItem = designDetailBiasa,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewDiscard = false,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.30 Buang perubahan`.
  const V2InventarisFormPage.buangPerubahan({super.key})
    : initialJenis = V2JenisBarang.benih,
      initialItem = null,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewDiscard = true,
      previewConflict = false,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Frame `4.31 Data sudah berubah`.
  const V2InventarisFormPage.dataBerubah({super.key})
    : initialJenis = V2JenisBarang.benih,
      initialItem = designDetailBiasa,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewDiscard = false,
      previewConflict = true,
      obatPilihan = designObatPilihan,
      onSubmit = null;

  /// Jenis terpilih saat form dibuka.
  final V2JenisBarang initialJenis;

  /// Barang yang sedang diubah; null berarti menambah barang baru (frame 4.10).
  final V2InventarisItem? initialItem;

  /// Membuka sheet "Pilih obat" begitu form tampil (frame 4.12).
  final bool previewObatSheet;

  /// Untuk pratinjau 4.13: kolom stok awal tampil terfokus tanpa keyboard
  /// nyata, dengan isian yang sudah berisi.
  final bool previewKeyboard;

  /// Untuk pratinjau 4.14: kolom kosong dengan galat sudah menyala.
  final bool previewValidation;

  /// Untuk pratinjau 4.30: dialog "Buang perubahan?" dibuka begitu tampil.
  final bool previewDiscard;

  /// Untuk pratinjau 4.31: dialog "Data sudah berubah" dibuka begitu tampil.
  final bool previewConflict;

  /// Daftar obat untuk sheet "Pilih obat" (frame 4.12). Dari `GET /api/v1/obat`
  /// saat tersambung, atau data contoh di galeri.
  final List<V2ObatPilihan> obatPilihan;

  /// Simpan barang ke backend. Bila diisi, tombol "Simpan" membuka pop-up
  /// konfirmasi ulang dan menampilkan spinner sampai proses selesai, baru form
  /// menutup; galat server tampil sebagai pesan dan form tetap terbuka.
  final Future<void> Function(V2InventarisItem hasil)? onSubmit;

  /// Form sedang mengubah barang yang sudah ada (frame 4.24).
  bool get isEdit => initialItem != null;

  static Route<V2InventarisItem> route({
    V2JenisBarang initialJenis = V2JenisBarang.benih,
    List<V2ObatPilihan> obatPilihan = designObatPilihan,
    Future<void> Function(V2InventarisItem hasil)? onSubmit,
  }) {
    return MaterialPageRoute<V2InventarisItem>(
      builder: (_) => V2InventarisFormPage(
        initialJenis: initialJenis,
        obatPilihan: obatPilihan,
        onSubmit: onSubmit,
      ),
    );
  }

  /// Buka form ubah untuk [item] (frame 4.24).
  static Route<V2InventarisItem> routeUbah(
    V2InventarisItem item, {
    List<V2ObatPilihan> obatPilihan = designObatPilihan,
    Future<void> Function(V2InventarisItem hasil)? onSubmit,
  }) {
    return MaterialPageRoute<V2InventarisItem>(
      builder: (_) => V2InventarisFormPage(
        initialItem: item,
        obatPilihan: obatPilihan,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<V2InventarisFormPage> createState() => _V2InventarisFormPageState();
}

class _V2InventarisFormPageState extends State<V2InventarisFormPage> {
  late V2JenisBarang _jenis = widget.initialItem?.jenis ?? widget.initialJenis;
  V2ObatPilihan? _obat;

  late final TextEditingController _nama;
  late final TextEditingController _satuan;
  late final TextEditingController _stokAwal;
  late final TextEditingController _stokMin;

  /// Frame 4.13 menampilkan form yang sudah digulir sampai kolom "Satuan"
  /// menempel di bawah AppBar; ruang itu dipakai sebagai padding bawah supaya
  /// `jumpTo(maxScrollExtent)` berhenti di posisi frame tersebut.
  final ScrollController _scroll = ScrollController();
  static const double _keyboardBottomSpace = 89;

  String? _namaError;
  String? _satuanError;
  String? _stokAwalError;

  /// Menandai isian sudah disentuh, supaya tombol kembali menawarkan "Buang
  /// perubahan?" (frame 4.30).
  bool _dirty = false;

  bool get _hasError =>
      _namaError != null || _satuanError != null || _stokAwalError != null;

  bool get _showStokMin => _jenis != V2JenisBarang.obat;

  /// `id_obat`/nama obat yang ikut disimpan; hanya untuk jenis Obat.
  String? get _obatId => _jenis == V2JenisBarang.obat ? _obat?.id : null;
  String? get _obatNama => _jenis == V2JenisBarang.obat ? _obat?.nama : null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    final empty = widget.previewValidation;
    final keyboard = widget.previewKeyboard;
    _nama = TextEditingController(text: item?.nama ?? '');
    _satuan = TextEditingController(
      text: item?.satuan ?? (keyboard ? 'pak' : ''),
    );
    _stokAwal = TextEditingController(
      text: keyboard
          ? '12'
          : empty
          ? '-3'
          : '',
    );
    _stokMin = TextEditingController(text: _minimumAwal(item));

    _obat = _obatDariItem(item);

    for (final controller in [_nama, _satuan, _stokAwal, _stokMin]) {
      controller.addListener(_markDirty);
    }

    if (widget.previewValidation) {
      _namaError = 'Isi nama barang';
      _satuanError = 'Isi satuan';
      _stokAwalError = 'Angka tidak boleh negatif';
    }
    if (widget.previewObatSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickObat());
    }
    if (widget.previewKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    if (widget.previewConflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConflict());
    }
    if (widget.previewDiscard) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirmDiscard());
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _satuan.dispose();
    _stokAwal.dispose();
    _stokMin.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Stok minimum awal mode ubah, mis. `3`; kosong saat belum diisi.
  String _minimumAwal(V2InventarisItem? item) {
    final minimum = item?.minimum;
    return minimum == null ? '' : formatAngka(minimum);
  }

  /// Menandai isian sudah disentuh (frame 4.30) sekaligus membersihkan galat
  /// yang sudah diperbaiki, supaya pesan merah hilang begitu isian benar.
  void _markDirty() {
    final namaBaik = _namaError != null && _nama.text.trim().isNotEmpty;
    final satuanBaik = _satuanError != null && _satuan.text.trim().isNotEmpty;
    final stokBaik =
        _stokAwalError != null &&
        _stokAwal.text.trim().isNotEmpty &&
        _parseAngka(_stokAwal.text) >= 0;
    if (_dirty && !namaBaik && !satuanBaik && !stokBaik) return;
    setState(() {
      _dirty = true;
      if (namaBaik) _namaError = null;
      if (satuanBaik) _satuanError = null;
      if (stokBaik) _stokAwalError = null;
    });
  }

  void _pop() {
    _dirty = false;
    Navigator.of(context).pop();
  }

  void _back() {
    if (!_dirty) {
      _pop();
      return;
    }
    _confirmDiscard();
  }

  /// Dialog "Buang perubahan?" (frame 4.30): "Buang" menutup form, "Lanjut
  /// isi" menutup dialog dan kembali ke isian.
  Future<void> _confirmDiscard() async {
    final discard = await showV2Dialog(
      context,
      type: V2DialogType.destructive,
      title: 'Buang perubahan?',
      body: 'Isian yang diubah akan hilang.',
      primaryLabel: 'Buang',
      secondaryLabel: 'Lanjut isi',
    );
    if (discard == true && mounted) _pop();
  }

  /// Dialog "Data sudah berubah" (frame 4.31): "Muat ulang" mengembalikan isian
  /// ke data terakhir, "Batal" menutup dialog.
  Future<void> _showConflict() async {
    final reload = await showV2Dialog(
      context,
      title: 'Data sudah berubah',
      body:
          'Data ini baru diubah di perangkat lain. Muat ulang untuk melihat '
          'versi terbaru, lalu ubah lagi.',
      primaryLabel: 'Muat ulang',
      secondaryLabel: 'Batal',
    );
    if (reload == true && mounted) _resetToInitial();
  }

  void _resetToInitial() {
    final item = widget.initialItem;
    _nama.text = item?.nama ?? '';
    _satuan.text = item?.satuan ?? '';
    _stokAwal.text = '';
    _stokMin.text = _minimumAwal(item);
    setState(() {
      _dirty = false;
      _jenis = item?.jenis ?? widget.initialJenis;
      _obat = _obatDariItem(item);
      _namaError = null;
      _satuanError = null;
      _stokAwalError = null;
    });
  }

  /// Obat awal dari barang yang diubah; null bila tidak tertaut obat atau baru
  /// ditambah. Cocokkan dulu dengan daftar pilihan, kalau tidak ada baru
  /// bangun pilihan dari nama yang tersimpan supaya nilainya tetap tampil.
  V2ObatPilihan? _obatDariItem(V2InventarisItem? item) {
    final medicineId = item?.medicineId;
    if (medicineId == null) return null;
    return widget.obatPilihan
            .where((pilihan) => pilihan.id == medicineId)
            .firstOrNull ??
        V2ObatPilihan(nama: item?.medicineName ?? '', id: medicineId);
  }

  void _setJenis(V2JenisBarang jenis) {
    if (jenis == _jenis) return;
    setState(() {
      _jenis = jenis;
      // Obat hanya berlaku untuk jenis Obat; pilihan lama dibuang supaya
      // `id_obat` tidak ikut terkirim untuk jenis lain.
      if (jenis != V2JenisBarang.obat) _obat = null;
    });
  }

  /// Sheet "Pilih obat" (frame 4.12): pilihan ditahan di dalam sheet dan baru
  /// dipakai setelah "Pilih", mengikuti pola sheet "Jenis barang".
  Future<void> _pickObat() async {
    final pilihan = widget.obatPilihan;
    if (pilihan.isEmpty) return;
    var draft = _obat ?? pilihan.first;
    final result = await showV2BottomSheet<V2ObatPilihan>(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => V2BottomSheet(
          title: 'Pilih obat',
          actions: V2Button(
            label: 'Pilih',
            onPressed: () => Navigator.of(sheetContext).pop(draft),
          ),
          child: Column(
            children: [
              for (var index = 0; index < pilihan.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                V2OptionRow(
                  label: pilihan[index].nama,
                  state: draft.id == pilihan[index].id
                      ? V2OptionState.selected
                      : V2OptionState.normal,
                  onTap: () => setSheet(() => draft = pilihan[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _obat = result);
  }

  /// Angka apa adanya dari isian: `-3` tetap negatif, `1.200` jadi 1200.
  double _parseAngka(String text) {
    final cleaned = text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final item = widget.initialItem;
    final nama = _nama.text.trim();
    final satuan = _satuan.text.trim();

    // Mode ubah (frame 4.24): hanya nama, jenis, satuan, dan stok minimum yang
    // berubah; jumlah, riwayat, dan keadaan arsip tetap.
    if (item != null) {
      final minimumText = _stokMin.text.trim();
      final minimum = minimumText.isEmpty ? null : _parseAngka(minimumText);
      setState(() {
        _namaError = nama.isEmpty ? 'Isi nama barang' : null;
        _satuanError = satuan.isEmpty ? 'Isi satuan' : null;
        _stokAwalError = null;
      });
      if (_hasError) return;

      await _kirim(
        V2InventarisItem(
          id: item.id,
          nama: nama,
          jenis: _jenis,
          jumlah: item.jumlah,
          satuan: satuan,
          status: statusStok(item.jumlah, minimum),
          arsip: item.arsip,
          antrean: item.antrean,
          minimum: minimum,
          riwayat: item.riwayat,
          medicineId: _obatId,
          medicineName: _obatNama,
        ),
        ubah: true,
      );
      return;
    }

    final stokAwal = _stokAwal.text.trim();
    final jumlah = _parseAngka(stokAwal);

    setState(() {
      _namaError = nama.isEmpty ? 'Isi nama barang' : null;
      _satuanError = satuan.isEmpty ? 'Isi satuan' : null;
      _stokAwalError = stokAwal.isEmpty
          ? 'Isi stok awal'
          : jumlah < 0
          ? 'Angka tidak boleh negatif'
          : null;
    });
    if (_hasError) return;

    await _kirim(
      V2InventarisItem(
        id: 'stok-${nama.toLowerCase().replaceAll(' ', '-')}',
        nama: nama,
        jenis: _jenis,
        jumlah: jumlah,
        satuan: satuan,
        medicineId: _obatId,
        medicineName: _obatNama,
      ),
      ubah: false,
    );
  }

  /// Kirim barang ke backend setelah konfirmasi ulang (Sesi 9).
  ///
  /// Bila [V2InventarisFormPage.onSubmit] diisi (alur nyata), pop-up konfirmasi
  /// menampilkan spinner di tombolnya sampai proses selesai, baru form menutup.
  /// Galat server tampil sebagai pesan dan form tetap terbuka supaya isian tidak
  /// hilang. Mode galeri tanpa callback tetap memakai pop-up lama.
  Future<void> _kirim(V2InventarisItem hasil, {required bool ubah}) async {
    final submit = widget.onSubmit;
    if (submit == null) {
      if (ubah) {
        // Konfirmasi ulang sebelum menyimpan perubahan (K-03/K-18, D-35).
        final confirmed = await showV2Dialog(
          context,
          title: 'Simpan perubahan barang?',
          body: 'Perubahan barang akan dikirim ke server.',
          primaryLabel: 'Simpan',
          secondaryLabel: 'Batal',
        );
        if (confirmed != true || !mounted) return;
      }
      _dirty = false;
      Navigator.of(context).pop(hasil);
      return;
    }

    try {
      final done = await showV2ActionDialog(
        context,
        title: ubah ? 'Simpan perubahan barang?' : 'Tambah barang?',
        body: ubah
            ? 'Perubahan barang akan dikirim ke server.'
            : 'Barang baru akan dikirim ke server.',
        primaryLabel: ubah ? 'Simpan' : 'Tambah',
        onConfirm: () => submit(hasil),
      );
      if (!mounted || !done) return;
      _dirty = false;
      Navigator.of(context).pop(hasil);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen =
        widget.previewKeyboard || MediaQuery.viewInsetsOf(context).bottom > 0;

    return Theme(
      data: V2Theme.light,
      child: PopScope<V2InventarisItem>(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _back();
        },
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(
                  title: widget.isEdit ? 'Ubah barang' : 'Tambah barang',
                  onBack: _back,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      V2Space.xl,
                      V2Space.sm,
                      V2Space.xl,
                      keyboardOpen ? _keyboardBottomSpace : V2Space.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildFields(),
                    ),
                  ),
                ),
                // Dengan keyboard terbuka tombol berhenti 8 di atas keyboard.
                Padding(
                  padding: EdgeInsets.only(
                    bottom: keyboardOpen ? V2Space.sm : 0,
                  ),
                  child: V2ActionBar(
                    safeBottom: !keyboardOpen,
                    actions: [V2Button(label: 'Simpan', onPressed: _save)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final hint = hintFormBarang(_jenis);
    final gap = _hasError ? V2Space.md : V2Space.lg;
    final edit = widget.isEdit;
    return [
      _jenisField(),
      SizedBox(height: gap),
      if (_jenis == V2JenisBarang.obat) ...[
        V2SelectField(
          label: 'Obat',
          value: _obatNama,
          hint: 'Pilih obat',
          onTap: _pickObat,
        ),
        SizedBox(height: gap),
      ],
      V2TextField(
        label: 'Nama barang',
        // Hint disembunyikan saat kolom bergalat (frame 4.14).
        hint: _namaError == null ? hint.$1 : '',
        controller: _nama,
        error: _namaError,
      ),
      SizedBox(height: gap),
      V2TextField(
        label: 'Satuan',
        hint: _satuanError == null ? hint.$2 : '',
        controller: _satuan,
        error: _satuanError,
        // Satuan tidak boleh diubah setelah barang dibuat (keputusan SA),
        // supaya riwayat stok tetap konsisten; hanya jenis/nama yang bisa diubah.
        enabled: !edit,
        helper: edit ? 'Satuan tidak bisa diubah.' : null,
      ),
      // Mode ubah tidak menyentuh jumlah, jadi "Stok awal" tidak muncul
      // (frame 4.24).
      if (!edit) ...[
        SizedBox(height: gap),
        V2TextField(
          label: 'Stok awal',
          hint: '0',
          controller: _stokAwal,
          error: _stokAwalError,
          keyboardType: TextInputType.number,
          forceFocus: widget.previewKeyboard,
        ),
      ],
      if (_showStokMin) ...[
        SizedBox(height: gap),
        V2TextField(
          label: 'Stok minimum (opsional)',
          hint: 'Contoh: 3',
          controller: _stokMin,
          keyboardType: TextInputType.number,
        ),
      ],
      if (edit) ...[
        SizedBox(height: gap),
        Text(
          'Stok diubah lewat Catat stok.',
          style: V2Type.label.copyWith(color: V2Colors.muted),
        ),
      ],
    ];
  }

  Widget _jenisField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jenis', style: V2Type.label),
        const SizedBox(height: V2Space.sm),
        Wrap(
          spacing: V2Space.sm,
          runSpacing: V2Space.sm,
          children: [
            for (final jenis in urutanJenisForm)
              V2Chip(
                label: jenis.label,
                selected: _jenis == jenis,
                onTap: () => _setJenis(jenis),
              ),
          ],
        ),
      ],
    );
  }
}
