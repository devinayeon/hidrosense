import 'package:flutter/material.dart';

import '../components/v2_inventaris_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_text_field.dart';

/// Form "Tambah barang" (frame 4.10–4.14).
///
/// Susunan siap: label "Jenis" dengan chip jenis, kolom "Obat" (hanya saat
/// jenis Obat, frame 4.11/4.12), lalu nama barang, satuan, stok awal, dan
/// stok minimum (opsional). Tombolnya "Simpan".
///
/// Jarak antarbagian 16 saat bersih dan mengeras jadi 12 saat ada galat
/// (frame 4.14). Hint tiap kolom ikut jenis barang dan disembunyikan saat
/// kolomnya bergalat, mengikuti desain.
class V2InventarisFormPage extends StatefulWidget {
  const V2InventarisFormPage({
    super.key,
    this.initialJenis = V2JenisBarang.benih,
    this.previewObatSheet = false,
    this.previewKeyboard = false,
    this.previewValidation = false,
  });

  /// Frame `4.10 Tambah barang`.
  const V2InventarisFormPage.create({super.key})
    : initialJenis = V2JenisBarang.benih,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false;

  /// Frame `4.11 Tambah barang, jenis Obat`.
  const V2InventarisFormPage.obat({super.key})
    : initialJenis = V2JenisBarang.obat,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = false;

  /// Frame `4.12 Pilih obat`.
  const V2InventarisFormPage.pilihObat({super.key})
    : initialJenis = V2JenisBarang.obat,
      previewObatSheet = true,
      previewKeyboard = false,
      previewValidation = false;

  /// Frame `4.13 Tambah barang, keyboard`.
  const V2InventarisFormPage.keyboard({super.key})
    : initialJenis = V2JenisBarang.benih,
      previewObatSheet = false,
      previewKeyboard = true,
      previewValidation = false;

  /// Frame `4.14 Tambah barang, validasi`.
  const V2InventarisFormPage.validation({super.key})
    : initialJenis = V2JenisBarang.benih,
      previewObatSheet = false,
      previewKeyboard = false,
      previewValidation = true;

  /// Jenis terpilih saat form dibuka.
  final V2JenisBarang initialJenis;

  /// Membuka sheet "Pilih obat" begitu form tampil (frame 4.12).
  final bool previewObatSheet;

  /// Untuk pratinjau 4.13: kolom stok awal tampil terfokus tanpa keyboard
  /// nyata, dengan isian yang sudah berisi.
  final bool previewKeyboard;

  /// Untuk pratinjau 4.14: kolom kosong dengan galat sudah menyala.
  final bool previewValidation;

  static Route<V2InventarisItem> route({
    V2JenisBarang initialJenis = V2JenisBarang.benih,
  }) {
    return MaterialPageRoute<V2InventarisItem>(
      builder: (_) => V2InventarisFormPage(initialJenis: initialJenis),
    );
  }

  @override
  State<V2InventarisFormPage> createState() => _V2InventarisFormPageState();
}

class _V2InventarisFormPageState extends State<V2InventarisFormPage> {
  late V2JenisBarang _jenis = widget.initialJenis;
  String? _obat;

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

  bool get _hasError =>
      _namaError != null || _satuanError != null || _stokAwalError != null;

  bool get _showStokMin => _jenis != V2JenisBarang.obat;

  @override
  void initState() {
    super.initState();
    final empty = widget.previewValidation;
    final keyboard = widget.previewKeyboard;
    _nama = TextEditingController(text: '');
    _satuan = TextEditingController(text: keyboard ? 'pak' : '');
    _stokAwal = TextEditingController(
      text: keyboard
          ? '12'
          : empty
          ? '-3'
          : '',
    );
    _stokMin = TextEditingController(text: '');

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

  void _pop() => Navigator.of(context).pop();

  void _setJenis(V2JenisBarang jenis) {
    if (jenis == _jenis) return;
    setState(() => _jenis = jenis);
  }

  /// Sheet "Pilih obat" (frame 4.12): pilihan ditahan di dalam sheet dan baru
  /// dipakai setelah "Pilih", mengikuti pola sheet "Jenis barang".
  Future<void> _pickObat() async {
    var draft = _obat ?? designObat.first;
    final result = await showV2BottomSheet<String>(
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
              for (var index = 0; index < designObat.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                V2OptionRow(
                  label: designObat[index],
                  state: draft == designObat[index]
                      ? V2OptionState.selected
                      : V2OptionState.normal,
                  onTap: () => setSheet(() => draft = designObat[index]),
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

  void _save() {
    FocusScope.of(context).unfocus();
    final nama = _nama.text.trim();
    final satuan = _satuan.text.trim();
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

    Navigator.of(context).pop(
      V2InventarisItem(
        id: 'stok-${nama.toLowerCase().replaceAll(' ', '-')}',
        nama: nama,
        jenis: _jenis,
        jumlah: jumlah,
        satuan: satuan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen =
        widget.previewKeyboard || MediaQuery.viewInsetsOf(context).bottom > 0;

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(title: 'Tambah barang', onBack: _pop),
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
                padding: EdgeInsets.only(bottom: keyboardOpen ? V2Space.sm : 0),
                child: V2ActionBar(
                  safeBottom: !keyboardOpen,
                  actions: [V2Button(label: 'Simpan', onPressed: _save)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final hint = hintFormBarang(_jenis);
    final gap = _hasError ? V2Space.md : V2Space.lg;
    return [
      _jenisField(),
      SizedBox(height: gap),
      if (_jenis == V2JenisBarang.obat) ...[
        V2SelectField(
          label: 'Obat',
          value: _obat,
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
      ),
      SizedBox(height: gap),
      V2TextField(
        label: 'Stok awal',
        hint: '0',
        controller: _stokAwal,
        error: _stokAwalError,
        keyboardType: TextInputType.number,
        forceFocus: widget.previewKeyboard,
      ),
      if (_showStokMin) ...[
        SizedBox(height: gap),
        V2TextField(
          label: 'Stok minimum (opsional)',
          hint: 'Contoh: 3',
          controller: _stokMin,
          keyboardType: TextInputType.number,
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
