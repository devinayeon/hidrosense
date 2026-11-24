import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../components/v2_semaian_data.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_stepper.dart';
import '../widgets/v2_text_field.dart';

/// Form "Tambah semaian" (frame 5.7–5.11).
///
/// Susunan siap: tanggal semai, jumlah benih, bahan, jumlah bahan, lalu tombol
/// "Tambah bahan". Saat bahan dan jumlahnya sah, kartu tint "Stok berkurang"
/// memperlihatkan sisa stok setelah disemai (frame 5.7).
///
/// Jarak antarbagian tetap 16, termasuk saat ada galat (frame 5.10/5.11), dan
/// bagian "Jumlah bahan" baru muncul setelah bahan dipilih. Dengan keyboard
/// terbuka (5.9) kartu tint disembunyikan dan tombol berhenti 8 di atas
/// keyboard. Nomor galat mengikuti desain: "Isi jumlah benih", "Pilih bahan",
/// dan "Stok hanya 12 pak".
class V2SemaianFormPage extends StatefulWidget {
  const V2SemaianFormPage({
    super.key,
    this.previewDateSheet = false,
    this.previewKeyboard = false,
    this.previewValidation = false,
    this.previewStokKurang = false,
    this.bahanList,
    this.initialDate,
  });

  /// Frame `5.7 Tambah semaian`.
  const V2SemaianFormPage.create({super.key})
    : previewDateSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null;

  /// Frame `5.8 Pilih tanggal`.
  const V2SemaianFormPage.pilihTanggal({super.key})
    : previewDateSheet = true,
      previewKeyboard = false,
      previewValidation = false,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null;

  /// Frame `5.9 Tambah semaian, keyboard`.
  const V2SemaianFormPage.keyboard({super.key})
    : previewDateSheet = false,
      previewKeyboard = true,
      previewValidation = false,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null;

  /// Frame `5.10 Tambah semaian, validasi`.
  const V2SemaianFormPage.validation({super.key})
    : previewDateSheet = false,
      previewKeyboard = false,
      previewValidation = true,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null;

  /// Frame `5.11 Stok tidak cukup`.
  const V2SemaianFormPage.stokKurang({super.key})
    : previewDateSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewStokKurang = true,
      bahanList = null,
      initialDate = null;

  /// Membuka sheet tanggal begitu form tampil (frame 5.8).
  final bool previewDateSheet;

  /// Kolom "Jumlah benih" tampil terfokus tanpa keyboard nyata (frame 5.9).
  final bool previewKeyboard;

  /// Jumlah benih dan bahan kosong dengan galat menyala (frame 5.10).
  final bool previewValidation;

  /// Jumlah bahan melebihi stok dengan galat menyala (frame 5.11).
  final bool previewStokKurang;

  /// Bahan yang bisa dipilih; null berarti contoh galeri. Halaman tersambung
  /// mengisinya dari inventaris benih backend.
  final List<V2SemaianBahan>? bahanList;

  /// Tanggal semai awal; null berarti tanggal acuan galeri.
  final DateTime? initialDate;

  static Route<V2SemaianItem> route({
    List<V2SemaianBahan>? bahanList,
    DateTime? initialDate,
  }) {
    return MaterialPageRoute<V2SemaianItem>(
      builder: (_) =>
          V2SemaianFormPage(bahanList: bahanList, initialDate: initialDate),
    );
  }

  @override
  State<V2SemaianFormPage> createState() => _V2SemaianFormPageState();
}

class _V2SemaianFormPageState extends State<V2SemaianFormPage> {
  static const double _keyboardBottomSpace = 25;

  late DateTime _tanggal = widget.initialDate ?? DateTime(2026, 11, 15);
  late final List<V2SemaianBahan> _pilihan =
      widget.bahanList?.isNotEmpty == true
      ? widget.bahanList!
      : designBahanSemaian;
  late final TextEditingController _jumlahBenih = TextEditingController(
    text: widget.previewValidation ? '' : '200',
  );
  late V2SemaianBahan? _bahan = widget.previewValidation
      ? null
      : _pilihan.first;
  late int _jumlahBahan = widget.previewStokKurang ? 15 : 2;

  String? _benihError;
  String? _bahanError;
  String? _jumlahError;

  final ScrollController _scroll = ScrollController();

  bool get _keyboard =>
      widget.previewKeyboard || MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  void initState() {
    super.initState();
    if (widget.previewValidation) {
      _benihError = 'Isi jumlah benih';
      _bahanError = 'Pilih bahan';
    }
    if (widget.previewStokKurang) {
      _jumlahError = 'Stok hanya ${designBahanRomaine.labelStok}';
    }
    if (widget.previewDateSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickDate());
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
    _jumlahBenih.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final result = await showV2SemaianDateSheet(context, selected: _tanggal);
    if (!mounted || result == null) return;
    setState(() => _tanggal = result);
  }

  /// Sheet "Pilih bahan"; pilihan baru dipakai setelah tombol "Pilih".
  Future<void> _pickBahan() async {
    var draft = _bahan ?? _pilihan.first;
    final result = await showV2BottomSheet<V2SemaianBahan>(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => V2BottomSheet(
          title: 'Pilih bahan',
          actions: V2Button(
            label: 'Pilih',
            onPressed: () => Navigator.of(sheetContext).pop(draft),
          ),
          child: Column(
            children: [
              for (var index = 0; index < _pilihan.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                V2OptionRow(
                  label: _pilihan[index].nama,
                  state: draft.nama == _pilihan[index].nama
                      ? V2OptionState.selected
                      : V2OptionState.normal,
                  onTap: () => setSheet(() => draft = _pilihan[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _bahan = result;
      _bahanError = null;
      _jumlahBahan = 2;
      _jumlahError = null;
    });
  }

  void _setJumlah(int value) {
    setState(() {
      _jumlahBahan = value;
      _jumlahError = _stokPesan();
    });
  }

  /// Pesan galat bila jumlah bahan melebihi stok bahan terpilih.
  String? _stokPesan() {
    final bahan = _bahan;
    if (bahan == null || _jumlahBahan <= bahan.stok) return null;
    return 'Stok hanya ${bahan.labelStok}';
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final teksBenih = _jumlahBenih.text.trim();
    final benih = int.tryParse(teksBenih);
    setState(() {
      _benihError = teksBenih.isEmpty
          ? 'Isi jumlah benih'
          : benih == null || benih <= 0
          ? 'Jumlah benih harus angka'
          : null;
      _bahanError = _bahan == null ? 'Pilih bahan' : null;
      _jumlahError = _stokPesan();
    });
    final bahan = _bahan;
    if (_benihError != null ||
        _bahanError != null ||
        _jumlahError != null ||
        bahan == null) {
      return;
    }

    Navigator.of(context).pop(
      V2SemaianItem(
        id: 'semaian-${_tanggal.millisecondsSinceEpoch}',
        nama: bahan.nama.replaceFirst('Benih ', ''),
        tanggalSemai: _tanggal,
        jumlahBenih: benih!,
        bahanInventoryId: bahan.inventoryId,
        bahanAmount: '$_jumlahBahan',
        bahanUnit: bahan.satuan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = _keyboard;

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Tambah semaian',
                onBack: () => Navigator.of(context).maybePop(),
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
    final bahan = _bahan;
    return [
      V2SelectField(
        label: 'Tanggal semai',
        value: formatTanggalIndo(_tanggal, singkat: true),
        icon: V2IconName.calendar,
        onTap: _pickDate,
      ),
      const SizedBox(height: V2Space.lg),
      V2TextField(
        label: 'Jumlah benih',
        controller: _jumlahBenih,
        error: _benihError,
        keyboardType: TextInputType.number,
        forceFocus: widget.previewKeyboard,
      ),
      const SizedBox(height: V2Space.lg),
      V2SelectField(
        label: 'Bahan',
        value: bahan?.nama,
        hint: _bahanError == null ? 'Pilih bahan' : '',
        error: _bahanError,
        onTap: _pickBahan,
      ),
      if (bahan != null) ...[
        const SizedBox(height: V2Space.lg),
        _jumlahBahanField(bahan),
      ],
      const SizedBox(height: V2Space.lg),
      V2Button(
        label: 'Tambah bahan',
        type: V2ButtonType.ghost,
        onPressed: _pickBahan,
      ),
      // Kartu tint menjelaskan stok yang berkurang; tidak tampil saat galat
      // (5.11) atau saat keyboard menutup ruangnya (5.9).
      if (bahan != null && !_keyboard && _jumlahError == null) ...[
        const SizedBox(height: V2Space.lg),
        _tintCard(bahan),
      ],
    ];
  }

  /// "Jumlah bahan": label hitam, stepper 56, lalu helper galat bila ada.
  Widget _jumlahBahanField(V2SemaianBahan bahan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jumlah bahan', style: V2Type.label.copyWith(color: V2Colors.ink)),
        const SizedBox(height: V2Space.sm),
        V2QtyField(
          value: _jumlahBahan,
          unit: bahan.satuan,
          error: _jumlahError != null,
          onChanged: _setJumlah,
          onMinus: _jumlahBahan <= 1
              ? null
              : () => _setJumlah(_jumlahBahan - 1),
          onPlus: () => _setJumlah(_jumlahBahan + 1),
        ),
        if (_jumlahError != null) ...[
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              const V2Icon(
                V2IconName.close,
                size: V2Icons.small,
                color: V2Colors.red700,
              ),
              const SizedBox(width: V2Space.sm),
              Text(
                _jumlahError!,
                style: V2Type.label.copyWith(color: V2Colors.red700),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Kartu `Card Type=Tint` (frame 5.7): judul 20/28 dan isi 16/24.
  Widget _tintCard(V2SemaianBahan bahan) {
    final sisa = bahan.stok - _jumlahBahan;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stok berkurang', style: V2Type.h2),
          const SizedBox(height: V2Space.sm),
          Text(
            '${bahan.nama}: ${bahan.labelStok} jadi $sisa ${bahan.satuan}',
            style: V2Type.body.copyWith(color: V2Colors.slate600),
          ),
        ],
      ),
    );
  }
}
