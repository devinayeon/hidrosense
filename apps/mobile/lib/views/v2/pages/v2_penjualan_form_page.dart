import 'package:flutter/material.dart';

import '../components/v2_penjualan_data.dart';
import '../components/v2_penjualan_tint_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_date_sheet.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_segmented.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_text_field.dart';

/// Form catat/ubah/perbaiki penjualan.
///
/// Satu halaman menangani tiga tugas karena isiannya sama:
/// [V2PenjualanFormPage.create] (frame 8.7, 8.8, 8.10–8.13, 8.23),
/// [V2PenjualanFormPage.edit] (frame 8.21, 8.24), dan
/// [V2PenjualanFormPage.fix] (frame 11.9 "Perbaiki penjualan").
///
/// Bedanya: form baru menampilkan kartu Total biru muda; form ubah menukarnya
/// dengan catatan "Panen, jumlah, dan harga diubah bersama."; form perbaiki
/// tidak menampilkan keduanya dan tombolnya "Simpan dan kirim ulang".
class V2PenjualanFormPage extends StatefulWidget {
  const V2PenjualanFormPage({
    super.key,
    this.initial,
    this.fixing = false,
    this.panenLabel,
    this.previewValidation = false,
    this.previewExceeds = false,
    this.previewDateBefore = false,
    this.previewDiscard = false,
    this.previewConflict = false,
    this.previewPanenSheet = false,
    this.forceJumlahFocus = false,
  });

  /// Frame `8.7 Catat penjualan` (form baru sudah terisi contoh).
  const V2PenjualanFormPage.create({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.8 Catat penjualan, panen baru`: pilihan panen tanggal 15 Nov.
  const V2PenjualanFormPage.panenBaru({super.key})
    : initial = null,
      fixing = false,
      panenLabel = 'Panen 15 Nov, sisa 252 kg',
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.9 Pilih panen`: sheet pilihan panen sudah terbuka.
  const V2PenjualanFormPage.pilihPanen({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = true,
      forceJumlahFocus = false;

  /// Frame `8.10 Catat penjualan, keyboard`: kolom jumlah sedang difokus.
  const V2PenjualanFormPage.keyboard({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = true;

  /// Frame `8.11 Catat penjualan, validasi`.
  const V2PenjualanFormPage.validation({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = true,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.12 Melebihi sisa panen`.
  const V2PenjualanFormPage.exceeds({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = true,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.13 Tanggal sebelum panen`.
  const V2PenjualanFormPage.dateBefore({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = true,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.23 Buang perubahan`: dialog buang sudah terbuka.
  const V2PenjualanFormPage.discard({super.key})
    : initial = null,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = true,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.24 Data sudah berubah`: dialog muat ulang sudah terbuka.
  const V2PenjualanFormPage.conflict(V2Penjualan penjualan, {super.key})
    : initial = penjualan,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = true,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `8.21 Ubah penjualan`.
  const V2PenjualanFormPage.edit(V2Penjualan penjualan, {super.key})
    : initial = penjualan,
      fixing = false,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = false,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Frame `11.9 Perbaiki penjualan`: jumlah melebihi sisa panen, lalu dikirim
  /// ulang.
  const V2PenjualanFormPage.fix(V2Penjualan penjualan, {super.key})
    : initial = penjualan,
      fixing = true,
      panenLabel = null,
      previewValidation = false,
      previewExceeds = true,
      previewDateBefore = false,
      previewDiscard = false,
      previewConflict = false,
      previewPanenSheet = false,
      forceJumlahFocus = false;

  /// Data awal; null berarti mencatat penjualan baru.
  final V2Penjualan? initial;

  /// Mode "Perbaiki penjualan" dari alur sinkron (frame 11.9).
  final bool fixing;

  /// Label panen awal, dipakai frame 8.8 yang memilih panen 15 Nov.
  final String? panenLabel;

  final bool previewValidation;
  final bool previewExceeds;
  final bool previewDateBefore;
  final bool previewDiscard;
  final bool previewConflict;
  final bool previewPanenSheet;

  /// Untuk pratinjau 8.10: kolom jumlah tampil terfokus tanpa keyboard nyata.
  final bool forceJumlahFocus;

  bool get isEdit => initial != null;

  static Route<V2Penjualan> route({V2Penjualan? initial}) {
    return MaterialPageRoute<V2Penjualan>(
      builder: (_) => V2PenjualanFormPage(initial: initial),
    );
  }

  @override
  State<V2PenjualanFormPage> createState() => _V2PenjualanFormPageState();
}

class _V2PenjualanFormPageState extends State<V2PenjualanFormPage> {
  static final DateTime _tanggalPanen = DateTime(2026, 11, 6);

  late final TextEditingController _pembeli;
  late final TextEditingController _jumlah;
  late final TextEditingController _harga;

  /// Frame 8.10: form sudah digulir sampai baris Jumlah/Harga menempel di
  /// bawah AppBar. Gulirannya disamakan dengan ujung bawah daftar isian.
  final ScrollController _scroll = ScrollController();

  /// Frame 8.10 menyisakan 53 kosong antara kartu Total dan tombol Simpan;
  /// ruang itu dipakai sebagai padding bawah supaya form bisa digulir sampai
  /// posisi di frame tersebut.
  static const double _keyboardBottomSpace = 53;

  late DateTime _tanggal;
  String? _panen;
  int _pembayaran = 0;

  String? _tanggalError;
  String? _pembeliError;
  String? _panenError;
  String? _jumlahError;
  String? _hargaError;

  bool _dirty = false;

  bool get _hasError =>
      _tanggalError != null ||
      _pembeliError != null ||
      _panenError != null ||
      _jumlahError != null ||
      _hargaError != null;

  /// Jarak antarbagian form: 12 untuk form baru yang bersih, 16 untuk form
  /// ubah/perbaiki, form bergalat, dan form dengan keyboard terbuka
  /// (frame 8.10) seperti frame 8.11–8.13, 8.21, 8.24, dan 11.9.
  double _gapFor(bool keyboardOpen) =>
      widget.isEdit || widget.fixing || _hasError || keyboardOpen
      ? V2Space.lg
      : V2Space.md;

  String get _title => widget.fixing
      ? 'Perbaiki penjualan'
      : widget.isEdit
      ? 'Ubah penjualan'
      : 'Catat penjualan';

  String get _actionLabel =>
      widget.fixing ? 'Simpan dan kirim ulang' : 'Simpan';

  int get _sisaPanen {
    final label = _panen;
    if (label == null) return 0;
    for (final option in designPanen) {
      if (option.label == label) return option.sisaKg;
    }
    // Panen 15 Nov (frame 8.8) tidak ada di daftar contoh.
    return label.contains('15 Nov') ? 252 : 0;
  }

  int get _total =>
      parseAngkaRibu(_jumlah.text) * parseAngkaRibu(_harga.text);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final empty = widget.previewValidation;

    _tanggal = widget.previewDateBefore
        ? DateTime(2026, 11, 4)
        : initial?.tanggal ?? DateTime(2026, 11, 15);
    _pembeli = TextEditingController(
      text: empty ? '' : initial?.pembeli ?? 'Warung Sari',
    );
    _jumlah = TextEditingController(
      text: empty
          ? ''
          : widget.previewExceeds || widget.fixing
          ? '200'
          : '${initial?.jumlahKg ?? 60}',
    );
    _harga = TextEditingController(
      text: empty
          ? ''
          : formatAngkaRibu(initial?.hargaPerKg ?? 40000),
    );
    _panen = empty
        ? null
        : widget.panenLabel ?? initial?.panen ?? designPanen.first.label;
    _pembayaran = (initial?.pembayaran == V2PenjualanBayar.belumLunas) ? 1 : 0;

    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }

    if (empty) {
      _dirty = true;
      _pembeliError = 'Isi nama pembeli';
      _panenError = 'Pilih panen';
      _jumlahError = 'Isi jumlah';
      _hargaError = 'Isi harga';
    }
    if (widget.previewExceeds) _jumlahError = 'Sisa $_sisaPanen kg';
    if (widget.previewDateBefore) _tanggalError = 'Sebelum panen (6 Nov)';

    if (widget.previewConflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConflict());
    }
    if (widget.previewDiscard) {
      _dirty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirmDiscard());
    }
    if (widget.previewPanenSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickPanen());
    }
    if (widget.forceJumlahFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _pembeli.dispose();
    _jumlah.dispose();
    _harga.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<TextEditingController> get _controllers => [_pembeli, _jumlah, _harga];

  /// Setiap ketikan membangun ulang halaman, supaya kartu Total ikut bergerak;
  /// [_dirty] cukup dinyalakan sekali.
  void _onFieldChanged() {
    setState(() => _dirty = true);
  }

  void _resetToInitial() {
    final initial = widget.initial;
    for (final controller in _controllers) {
      controller.removeListener(_onFieldChanged);
    }
    _dirty = false;
    _pembeli.text = initial?.pembeli ?? 'Warung Sari';
    _jumlah.text = '${initial?.jumlahKg ?? 60}';
    _harga.text = formatAngkaRibu(initial?.hargaPerKg ?? 40000);
    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }
    setState(() {
      _tanggal = initial?.tanggal ?? DateTime(2026, 11, 15);
      _panen = initial?.panen ?? designPanen.first.label;
      _pembayaran =
          (initial?.pembayaran == V2PenjualanBayar.belumLunas) ? 1 : 0;
      _tanggalError = null;
      _pembeliError = null;
      _panenError = null;
      _jumlahError = null;
      _hargaError = null;
    });
  }

  Future<void> _showConflict() async {
    final reload = await showV2Dialog(
      context,
      title: 'Data sudah berubah',
      body: 'Data ini baru diubah di perangkat lain. Muat ulang untuk melihat '
          'versi terbaru, lalu ubah lagi.',
      primaryLabel: 'Muat ulang',
      secondaryLabel: 'Batal',
    );
    if (reload == true && mounted) _resetToInitial();
  }

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

  Future<void> _pickDate() async {
    var day = _tanggal.day;
    await showV2BottomSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => V2DateSheet(
          monthLabel: 'November 2026',
          days: _hariNovember(),
          selectedDay: day,
          onSelect: (value) => setSheet(() => day = value),
          onConfirm: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _tanggal = DateTime(2026, 11, day);
      _tanggalError = null;
      _dirty = true;
    });
  }

  Future<void> _pickPanen() async {
    var picked = _panen;
    await showV2BottomSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => V2BottomSheet(
          title: 'Pilih panen',
          actions: V2Button(
            label: 'Pilih',
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < designPanen.length; index++) ...[
                // Komponen `Sheet/Pilih` merapatkan baris pilihan 16.
                if (index > 0) const SizedBox(height: V2Space.lg),
                V2OptionRow(
                  label: designPanen[index].label,
                  state: !designPanen[index].tersedia
                      ? V2OptionState.disabled
                      : designPanen[index].label == picked
                      ? V2OptionState.selected
                      : V2OptionState.normal,
                  onTap: designPanen[index].tersedia
                      ? () => setSheet(() => picked = designPanen[index].label)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (picked != null && picked != _panen) {
      setState(() {
        _panen = picked;
        _panenError = null;
        _jumlahError = null;
        _dirty = true;
      });
    }
  }

  List<int?> _hariNovember() {
    final first = DateTime(2026, 11, 1);
    final count = DateTime(2026, 12, 0).day;
    return [
      for (var index = 0; index < first.weekday - 1; index++) null,
      for (var day = 1; day <= count; day++) day,
    ];
  }

  void _save() {
    FocusScope.of(context).unfocus();

    final pembeli = _pembeli.text.trim();
    final jumlah = parseAngkaRibu(_jumlah.text);
    final harga = parseAngkaRibu(_harga.text);

    setState(() {
      _tanggalError = _tanggal.isBefore(_tanggalPanen)
          ? 'Sebelum panen (6 Nov)'
          : null;
      _pembeliError = pembeli.isEmpty ? 'Isi nama pembeli' : null;
      _panenError = _panen == null ? 'Pilih panen' : null;
      _jumlahError = jumlah <= 0
          ? 'Isi jumlah'
          : jumlah > _sisaPanen
          ? 'Sisa $_sisaPanen kg'
          : null;
      _hargaError = harga <= 0 ? 'Isi harga' : null;
    });

    if (_hasError) return;

    _dirty = false;
    final initial = widget.initial;
    final panen = _panen!;
    Navigator.of(context).pop(
      V2Penjualan(
        id: initial?.id ?? 'sale-${pembeli.toLowerCase()}',
        pembeli: pembeli,
        tanggal: _tanggal,
        jumlahKg: jumlah,
        hargaPerKg: harga,
        pembayaran: _pembayaran == 0
            ? V2PenjualanBayar.lunas
            : V2PenjualanBayar.belumLunas,
        panen: panen,
        panenAsal: panen.contains('15 Nov')
            ? 'Dari panen 15 Nov, Meja A1'
            : 'Dari panen 6 Nov, Meja A1',
        sync: initial?.sync ?? V2PenjualanSync.terkirim,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen =
        widget.forceJumlahFocus ||
        MediaQuery.viewInsetsOf(context).bottom > 0;

    return Theme(
      data: V2Theme.light,
      child: PopScope<V2Penjualan>(
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
                V2AppBar(title: _title, onBack: _back),
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
                      children: _buildFields(keyboardOpen),
                    ),
                  ),
                ),
                // Dengan keyboard terbuka tombol berhenti 8 di atas keyboard
                // (frame 8.10); tanpa keyboard SafeArea menambah 34 sendiri.
                Padding(
                  padding: EdgeInsets.only(
                    bottom: keyboardOpen ? V2Space.sm : 0,
                  ),
                  child: V2ActionBar(
                    safeBottom: !keyboardOpen,
                    actions: [
                      V2Button(label: _actionLabel, onPressed: _save),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields(bool keyboardOpen) {
    final gap = _gapFor(keyboardOpen);
    return [
      V2SelectField(
        label: 'Tanggal penjualan',
        value: formatTanggalPenjualan(_tanggal),
        icon: V2IconName.calendar,
        error: _tanggalError,
        onTap: _pickDate,
      ),
      SizedBox(height: gap),
      V2TextField(
        label: 'Pembeli',
        controller: _pembeli,
        error: _pembeliError,
      ),
      SizedBox(height: gap),
      V2SelectField(
        label: 'Panen',
        value: _panen,
        hint: '',
        error: _panenError,
        onTap: _pickPanen,
      ),
      SizedBox(height: gap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: V2TextField(
              label: 'Jumlah (kg)',
              controller: _jumlah,
              error: _jumlahError,
              keyboardType: TextInputType.number,
              forceFocus: widget.forceJumlahFocus,
            ),
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: V2TextField(
              label: 'Harga per kg (Rp)',
              controller: _harga,
              error: _hargaError,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
      SizedBox(height: gap),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pembayaran', style: V2Type.label),
          const SizedBox(height: V2Space.sm),
          V2Segmented(
            labels: const ['Lunas', 'Belum lunas'],
            selectedIndex: _pembayaran,
            onChanged: (index) => setState(() {
              _pembayaran = index;
              _dirty = true;
            }),
          ),
        ],
      ),
      // Frame 8.11–8.13 dan 11.9 tidak menggambar kartu Total saat form
      // menampilkan galat, jadi kartu itu hanya muncul di form bersih.
      if (!widget.isEdit && !widget.fixing && !_hasError) ...[
        SizedBox(height: gap),
        V2PenjualanTintCard(
          title: 'Total',
          value: formatRupiahPenuh(_total),
        ),
      ],
      if (widget.isEdit && !widget.fixing) ...[
        SizedBox(height: gap),
        Text(
          'Panen, jumlah, dan harga diubah bersama.',
          style: V2Type.label.copyWith(color: V2Colors.muted),
        ),
      ],
    ];
  }
}
