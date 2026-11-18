import 'package:flutter/material.dart';

import '../components/v2_panen_data.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_stepper.dart';
import '../widgets/v2_text_field.dart';

/// Form "Catat panen" (frame 7.8–7.12) dan dialog buang perubahan (7.22).
///
/// Tanggal dan tanaman duduk di dua `Select` 84, jumlah memakai `QtyField`,
/// lalu berat total dan reject. Kartu "Berat layak" biru muda 120 di bawahnya
/// hanya tampil saat isian sudah cukup. Jarak antarbagian 12 pada keadaan
/// normal, dan 16 saat ada galat (frame 7.11/7.12).
class V2PanenFormPage extends StatefulWidget {
  const V2PanenFormPage({
    super.key,
    this.meja,
    this.varietas,
    this.jumlahTanaman,
    this.previewValidation = false,
    this.previewExceeds = false,
    this.previewKeyboard = false,
    this.previewBuang = false,
    this.openTanamanOnStart = false,
  });

  /// Frame `7.8 Catat panen`: Meja B1, Romaine 240, 270/18 kg.
  const V2PanenFormPage.catat({super.key})
    : meja = 'Meja B1',
      varietas = 'Romaine',
      jumlahTanaman = 240,
      previewValidation = false,
      previewExceeds = false,
      previewKeyboard = false,
      previewBuang = false,
      openTanamanOnStart = false;

  /// Frame `7.9 Pilih tanaman`: sheet pilihan terbuka di atas form.
  const V2PanenFormPage.tanamanSheet({super.key})
    : meja = 'Meja B1',
      varietas = 'Romaine',
      jumlahTanaman = 240,
      previewValidation = false,
      previewExceeds = false,
      previewKeyboard = false,
      previewBuang = false,
      openTanamanOnStart = true;

  /// Frame `7.10 Catat panen, keyboard`: dua isian berat di atas, kartu
  /// "Berat layak" tetap terlihat.
  const V2PanenFormPage.keyboard({super.key})
    : meja = 'Meja B1',
      varietas = 'Romaine',
      jumlahTanaman = 240,
      previewValidation = false,
      previewExceeds = false,
      previewKeyboard = true,
      previewBuang = false,
      openTanamanOnStart = false;

  /// Frame `7.11 Catat panen, validasi`: tanaman belum dipilih, berat total
  /// kosong.
  const V2PanenFormPage.validation({super.key})
    : meja = null,
      varietas = null,
      jumlahTanaman = null,
      previewValidation = true,
      previewExceeds = false,
      previewKeyboard = false,
      previewBuang = false,
      openTanamanOnStart = false;

  /// Frame `7.12 Jumlah melebihi tanaman`: 300 dari 240 tanaman aktif.
  const V2PanenFormPage.melebihi({super.key})
    : meja = 'Meja B1',
      varietas = 'Romaine',
      jumlahTanaman = 240,
      previewValidation = false,
      previewExceeds = true,
      previewKeyboard = false,
      previewBuang = false,
      openTanamanOnStart = false;

  /// Frame `7.22 Buang perubahan`: dialog di atas form yang sudah diisi.
  const V2PanenFormPage.buang({super.key})
    : meja = 'Meja B1',
      varietas = 'Romaine',
      jumlahTanaman = 240,
      previewValidation = false,
      previewExceeds = false,
      previewKeyboard = false,
      previewBuang = true,
      openTanamanOnStart = false;

  /// Meja terpilih; null berarti belum ada tanaman.
  final String? meja;
  final String? varietas;
  final int? jumlahTanaman;

  final bool previewValidation;
  final bool previewExceeds;
  final bool previewKeyboard;
  final bool previewBuang;

  /// Membuka sheet "Pilih tanaman" begitu halaman tampil (frame 7.9).
  final bool openTanamanOnStart;

  static Route<V2PanenItem> route({
    String? meja,
    String? varietas,
    int? jumlahTanaman,
  }) {
    return MaterialPageRoute<V2PanenItem>(
      builder: (_) => V2PanenFormPage(
        meja: meja,
        varietas: varietas,
        jumlahTanaman: jumlahTanaman,
      ),
    );
  }

  @override
  State<V2PanenFormPage> createState() => _V2PanenFormPageState();
}

class _V2PanenFormPageState extends State<V2PanenFormPage> {
  late DateTime _tanggal = v2PanenHariIni;
  late V2PanenEstimasi? _tanaman = widget.meja == null
      ? null
      : V2PanenEstimasi(
          meja: widget.meja!,
          varietas: widget.varietas ?? 'Romaine',
          jumlahTanaman: widget.jumlahTanaman ?? 240,
          hariLagi: 0,
        );
  late int _jumlah = widget.previewExceeds ? 300 : (widget.jumlahTanaman ?? 0);

  late final TextEditingController _beratTotal = TextEditingController(
    text: widget.previewValidation
        ? ''
        : widget.meja == null
        ? ''
        : '270',
  );
  late final TextEditingController _beratReject = TextEditingController(
    text: widget.previewValidation
        ? '0'
        : widget.meja == null
        ? ''
        : '18',
  );

  String? _tanamanError;
  String? _beratError;
  String? _jumlahError;
  late bool _showBuang = widget.previewBuang;

  bool get _adaError =>
      widget.previewValidation ||
      widget.previewExceeds ||
      _tanamanError != null ||
      _beratError != null ||
      _jumlahError != null;

  double get _layak {
    final total = double.tryParse(_beratTotal.text.trim()) ?? 0;
    final reject = double.tryParse(_beratReject.text.trim()) ?? 0;
    return total - reject;
  }

  @override
  void initState() {
    super.initState();
    if (widget.previewValidation) {
      _tanamanError = 'Pilih tanaman';
      _beratError = 'Isi berat total';
    }
    if (widget.previewExceeds) {
      _jumlahError = 'Tanaman aktif hanya ${widget.jumlahTanaman}';
    }
    if (widget.openTanamanOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickTanaman();
      });
    }
    _beratTotal.addListener(_onBeratChanged);
    _beratReject.addListener(_onBeratChanged);
    _scroll = ScrollController(
      initialScrollOffset: widget.previewKeyboard ? 288 : 0,
    );
  }

  late final ScrollController _scroll;

  void _onBeratChanged() => setState(() {});

  @override
  void dispose() {
    _beratTotal.dispose();
    _beratReject.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    final result = await showV2SemaianDateSheet(context, selected: _tanggal);
    if (!mounted || result == null) return;
    setState(() => _tanggal = result);
  }

  Future<void> _pickTanaman() async {
    var draft = _tanaman ?? designPilihanTanamanPanen.first;
    final result = await showModalBottomSheet<V2PanenEstimasi>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: V2Colors.ink.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => V2BottomSheet(
          title: 'Pilih tanaman',
          actions: V2Button(
            label: 'Pilih',
            onPressed: () => Navigator.of(sheetContext).pop(draft),
          ),
          child: Column(
            children: [
              for (var index = 0; index < designPilihanTanamanPanen.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                _PilihanTanamanRow(
                  label:
                      '${designPilihanTanamanPanen[index].meja}, '
                      '${designPilihanTanamanPanen[index].varietas} '
                      '${designPilihanTanamanPanen[index].jumlahTanaman}',
                  selected:
                      designPilihanTanamanPanen[index].meja == draft.meja &&
                      designPilihanTanamanPanen[index].varietas ==
                          draft.varietas,
                  onTap: () => setSheetState(
                    () => draft = designPilihanTanamanPanen[index],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _tanaman = result;
      _jumlah = result.jumlahTanaman;
      _tanamanError = null;
      _jumlahError = null;
    });
  }

  void _simpan() {
    final total = double.tryParse(_beratTotal.text.trim()) ?? 0;
    final reject = double.tryParse(_beratReject.text.trim()) ?? 0;
    final aktif = _tanaman?.jumlahTanaman ?? 0;

    setState(() {
      _tanamanError = _tanaman == null ? 'Pilih tanaman' : null;
      _beratError = total <= 0 ? 'Isi berat total' : null;
      _jumlahError = _tanaman != null && _jumlah > aktif
          ? 'Tanaman aktif hanya $aktif'
          : null;
    });
    if (_tanamanError != null || _beratError != null || _jumlahError != null) {
      return;
    }

    Navigator.of(context).pop(
      V2PanenItem(
        id: 'panen-baru',
        tanggal: _tanggal,
        meja: _tanaman!.meja,
        varietas: _tanaman!.varietas,
        jumlahTanaman: _jumlah,
        beratTotal: total,
        beratReject: reject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = SafeArea(
      bottom: false,
      child: Column(
        children: [
          V2AppBar(
            title: 'Catat panen',
            onBack: () => widget.previewBuang
                ? setState(() => _showBuang = true)
                : _konfirmasiBuang(),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                V2Space.xl,
                V2Space.sm,
                V2Space.xl,
                widget.previewKeyboard ? 108 : V2Space.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  V2SelectField(
                    label: 'Tanggal panen',
                    value: labelTanggalPanenLengkap(_tanggal),
                    icon: V2IconName.calendar,
                    onTap: _pickTanggal,
                  ),
                  SizedBox(height: _gap),
                  V2SelectField(
                    label: 'Tanaman',
                    value: _tanaman == null
                        ? null
                        : '${_tanaman!.meja}, ${_tanaman!.varietas}',
                    hint: 'Pilih tanaman',
                    error: _tanamanError,
                    onTap: _pickTanaman,
                  ),
                  if (_tanaman != null) ...[
                    SizedBox(height: _gap),
                    _fieldJumlah(),
                  ],
                  SizedBox(height: _gap),
                  V2TextField(
                    label: 'Berat total (kg)',
                    hint: '0',
                    controller: _beratTotal,
                    error: _beratError,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: _gap),
                  V2TextField(
                    label: 'Berat reject (kg)',
                    hint: '0',
                    controller: _beratReject,
                    keyboardType: TextInputType.number,
                  ),
                  if (!_adaError) ...[
                    const SizedBox(height: V2Space.md),
                    _kartuLayak(),
                  ],
                ],
              ),
            ),
          ),
          if (widget.previewKeyboard)
            V2ActionBar(
              safeBottom: false,
              actions: [V2Button(label: 'Simpan', onPressed: _simpan)],
            )
          else
            V2ActionBar(
              actions: [V2Button(label: 'Simpan', onPressed: _simpan)],
            ),
        ],
      ),
    );

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: widget.previewKeyboard ? 299 : 0,
              ),
              child: form,
            ),
            if (_showBuang) _lapisanBuang(),
          ],
        ),
      ),
    );
  }

  /// Galat memakai jarak 16 antarbagian supaya posisi frame 7.11/7.12 sama.
  double get _gap => _adaError ? V2Space.lg : V2Space.md;

  Widget _fieldJumlah() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jumlah tanaman', style: V2Type.label.copyWith(
          color: V2Colors.ink,
        )),
        const SizedBox(height: V2Space.sm),
        V2QtyField(
          value: _jumlah,
          unit: 'tanaman',
          error: _jumlahError != null,
          onMinus: () => setState(() {
            if (_jumlah > 1) _jumlah -= 1;
          }),
          onPlus: () => setState(() => _jumlah += 1),
        ),
        if (_jumlahError != null) ...[
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              const V2Icon(
                V2IconName.error,
                size: 16,
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

  /// Kartu "Berat layak" biru muda (frame 7.8): judul 14/20 muted, angka
  /// 28/36 Bold.
  Widget _kartuLayak() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Berat layak',
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
          const SizedBox(height: V2Space.sm),
          Text(
            '${labelBeratKg(_layak < 0 ? 0 : _layak)} kg',
            style: V2Type.value,
          ),
        ],
      ),
    );
  }

  Future<void> _konfirmasiBuang() async {
    final buang = await showV2Dialog(
      context,
      title: 'Buang perubahan?',
      body: 'Isian yang diubah akan hilang.',
      primaryLabel: 'Buang',
      secondaryLabel: 'Lanjut isi',
    );
    if (!mounted || buang != true) return;
    Navigator.of(context).pop();
  }

  /// Lapisan gelap dan dialog buang perubahan (frame 7.22); dialog 342×260
  /// duduk tepat di tengah layar penuh.
  Widget _lapisanBuang() {
    return Positioned.fill(
      child: ColoredBox(
        color: V2Colors.ink.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Dialog(
              title: 'Buang perubahan?',
              body: 'Isian yang diubah akan hilang.',
              type: V2DialogType.destructive,
              primaryLabel: 'Buang',
              onPrimary: () {
                setState(() => _showBuang = false);
                Navigator.of(context).pop();
              },
              secondaryLabel: 'Lanjut isi',
              onSecondary: () => setState(() => _showBuang = false),
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris pilihan tanaman di sheet 7.9.
///
/// Bentuknya sama dengan `OptionRow`, tetapi teks mulai 27 dan bulatan pilihan
/// berjarak 19 dari tepi kanan seperti frame page 07. `V2OptionRow` milik
/// komponen shared dipakai apa adanya oleh halaman lain.
class _PilihanTanamanRow extends StatelessWidget {
  const _PilihanTanamanRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        child: Container(
          height: 56,
          padding: const EdgeInsets.only(left: 25, right: 17),
          decoration: BoxDecoration(
            color: selected ? V2Colors.blue50 : V2Colors.white,
            borderRadius: BorderRadius.circular(V2Radius.pill),
            border: Border.all(
              color: selected ? V2Colors.blue700 : V2Colors.slate400,
              width: selected ? 3 : 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong,
                ),
              ),
              const SizedBox(width: V2Space.md),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? V2Colors.blue500 : V2Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? V2Colors.blue500 : V2Colors.slate400,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const V2Icon(
                        V2IconName.check,
                        size: 16,
                        color: V2Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}