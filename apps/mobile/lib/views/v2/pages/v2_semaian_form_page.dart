import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../../../core/validators.dart';
import '../components/v2_semaian_data.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
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
/// keyboard. Pesan galat yang dipakai: "Benih harus angka positif", "Pilih
/// bahan", dan "Stok hanya 12 pak".
class V2SemaianFormPage extends StatefulWidget {
  const V2SemaianFormPage({
    super.key,
    this.previewDateSheet = false,
    this.previewKeyboard = false,
    this.previewValidation = false,
    this.previewStokKurang = false,
    this.bahanList,
    this.initialDate,
    this.onSubmit,
  });

  /// Frame `5.7 Tambah semaian`.
  const V2SemaianFormPage.create({super.key})
    : previewDateSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null,
      onSubmit = null;

  /// Frame `5.8 Pilih tanggal`.
  const V2SemaianFormPage.pilihTanggal({super.key})
    : previewDateSheet = true,
      previewKeyboard = false,
      previewValidation = false,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null,
      onSubmit = null;

  /// Frame `5.9 Tambah semaian, keyboard`.
  const V2SemaianFormPage.keyboard({super.key})
    : previewDateSheet = false,
      previewKeyboard = true,
      previewValidation = false,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null,
      onSubmit = null;

  /// Frame `5.10 Tambah semaian, validasi`.
  const V2SemaianFormPage.validation({super.key})
    : previewDateSheet = false,
      previewKeyboard = false,
      previewValidation = true,
      previewStokKurang = false,
      bahanList = null,
      initialDate = null,
      onSubmit = null;

  /// Frame `5.11 Stok tidak cukup`.
  const V2SemaianFormPage.stokKurang({super.key})
    : previewDateSheet = false,
      previewKeyboard = false,
      previewValidation = false,
      previewStokKurang = true,
      bahanList = null,
      initialDate = null,
      onSubmit = null;

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

  /// Simpan semaian ke backend. Bila diisi, tombol "Simpan" membuka pop-up
  /// konfirmasi ulang dan menampilkan spinner sampai proses selesai, baru form
  /// menutup; galat server tampil sebagai pesan dan form tetap terbuka.
  final Future<void> Function(V2SemaianItem hasil)? onSubmit;

  static Route<V2SemaianItem> route({
    List<V2SemaianBahan>? bahanList,
    DateTime? initialDate,
    Future<void> Function(V2SemaianItem hasil)? onSubmit,
  }) {
    return MaterialPageRoute<V2SemaianItem>(
      builder: (_) => V2SemaianFormPage(
        bahanList: bahanList,
        initialDate: initialDate,
        onSubmit: onSubmit,
      ),
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
    text: widget.previewValidation ? '' : '1',
  );
  late final List<_BarisBahan> _baris = <_BarisBahan>[
    _BarisBahan(
      bahan: widget.previewValidation ? null : _pilihan.first,
      jumlah: widget.previewStokKurang ? 15 : 1,
    ),
  ];

  String? _benihError;
  String? _bahanError;

  final ScrollController _scroll = ScrollController();

  /// Kartu tint stok disembunyikan baik saat keyboard nyata terbuka maupun
  /// saat galeri mensimulasikan keyboard (frame 5.9).
  bool get _keyboard =>
      widget.previewKeyboard || MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  void initState() {
    super.initState();
    if (widget.previewValidation) {
      _benihError = 'Benih harus angka positif';
      _bahanError = 'Pilih bahan';
    }
    if (widget.previewStokKurang) {
      _baris.first.error = 'Stok hanya ${designBahanRomaine.labelStok}';
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
  ///
  /// [dilewati] menyingkirkan bahan yang sudah dipakai baris lain karena
  /// kontrak backend meminta `materials[]` berisi baris unik (BUG-38).
  Future<void> _pickBahan({int? baris, Set<String> dilewati = const {}}) async {
    final pilihan = _pilihan
        .where((bahan) => !dilewati.contains(bahan.nama))
        .toList();
    if (pilihan.isEmpty) return;
    final awal = baris == null ? null : _baris[baris].bahan;
    var draft = (awal != null && pilihan.contains(awal)) ? awal : pilihan.first;
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
              for (var index = 0; index < pilihan.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                V2OptionRow(
                  label: pilihan[index].nama,
                  state: draft.nama == pilihan[index].nama
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
    setState(() {
      if (baris == null) {
        _baris.add(_BarisBahan(bahan: result, jumlah: 1));
      } else {
        final ganti = _baris[baris];
        if (ganti.bahan?.nama != result.nama) {
          ganti.bahan = result;
          ganti.jumlah = 1;
        }
        ganti.error = null;
      }
      _bahanError = null;
    });
  }

  /// "Tambah bahan": baris baru, bukan mengganti bahan baris pertama.
  Future<void> _tambahBahan() async {
    final terpakai = <String>{
      for (final baris in _baris)
        if (baris.bahan != null) baris.bahan!.nama,
    };
    if (terpakai.length >= _pilihan.length) return;
    await _pickBahan(dilewati: terpakai);
  }

  void _hapusBahan(int index) {
    if (_baris.length <= 1) return;
    setState(() => _baris.removeAt(index));
  }

  void _setJumlah(int index, int value) {
    setState(() {
      final baris = _baris[index];
      baris.jumlah = value;
      baris.error = _stokPesan(baris);
    });
  }

  /// Pesan galat bila jumlah bahan melebihi stok bahan terpilih.
  String? _stokPesan(_BarisBahan baris) {
    final bahan = baris.bahan;
    if (bahan == null || baris.jumlah <= bahan.stok) return null;
    return 'Stok hanya ${bahan.labelStok}';
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final teksBenih = _jumlahBenih.text.trim();
    final benih = int.tryParse(teksBenih);
    setState(() {
      _benihError = jumlahBenihProblem(teksBenih);
      _bahanError = _baris.first.bahan == null ? 'Pilih bahan' : null;
      for (final baris in _baris) {
        baris.error = _stokPesan(baris);
      }
    });
    final adaGalatJumlah = _baris.any((baris) => baris.error != null);
    if (_benihError != null ||
        _bahanError != null ||
        adaGalatJumlah ||
        _baris.first.bahan == null) {
      return;
    }

    final pakai = <V2SemaianBahanPakai>[
      for (final baris in _baris)
        V2SemaianBahanPakai(
          nama: baris.bahan!.nama.replaceFirst('Benih ', ''),
          jumlah: baris.jumlah,
          satuan: baris.bahan!.satuan,
          inventoryId: baris.bahan!.inventoryId,
        ),
    ];
    final utama = pakai.first;
    _kirim(
      V2SemaianItem(
        id: 'semaian-${_tanggal.millisecondsSinceEpoch}',
        nama: utama.nama,
        tanggalSemai: _tanggal,
        jumlahBenih: benih!,
        jumlahBahan: utama.jumlah,
        bahanInventoryId: utama.inventoryId,
        bahanAmount: '${utama.jumlah}',
        bahanUnit: utama.satuan,
        bahanList: pakai,
      ),
    );
  }

  /// Kirim semaian ke backend setelah konfirmasi ulang (Sesi 9).
  ///
  /// Bila [V2SemaianFormPage.onSubmit] diisi (alur nyata), pop-up konfirmasi
  /// menampilkan spinner di tombolnya sampai proses selesai, baru form menutup.
  /// Galat server tampil sebagai pesan dan form tetap terbuka supaya isian tidak
  /// hilang. Mode galeri tanpa callback langsung menutup form seperti semula.
  Future<void> _kirim(V2SemaianItem hasil) async {
    final submit = widget.onSubmit;
    if (submit == null) {
      Navigator.of(context).pop(hasil);
      return;
    }
    try {
      final done = await showV2ActionDialog(
        context,
        title: 'Simpan semaian?',
        body: 'Semaian baru akan dikirim ke server.',
        primaryLabel: 'Simpan',
        onConfirm: () => submit(hasil),
      );
      if (!mounted || !done) return;
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
    final preview = widget.previewKeyboard;
    final footer = V2ActionBar(
      actions: [V2Button(label: 'Simpan', onPressed: _save)],
    );

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        // Pratinjau galeri tetap menaruh footer di dalam body untuk
        // mensimulasikan frame keyboard; alur nyata memakai footer yang
        // dipaku di dasar layar.
        bottomNavigationBar: preview ? null : footer,
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
                    preview ? _keyboardBottomSpace : V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildFields(),
                  ),
                ),
              ),
              if (preview)
                Padding(
                  padding: const EdgeInsets.only(bottom: V2Space.sm),
                  child: V2ActionBar(
                    safeBottom: false,
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
    final terpakai = <String>{
      for (final baris in _baris)
        if (baris.bahan != null) baris.bahan!.nama,
    };
    final bisaTambah = terpakai.length < _pilihan.length;
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
      for (var index = 0; index < _baris.length; index++) ...[
        if (index > 0) const SizedBox(height: V2Space.xl),
        _barisBahanField(index),
      ],
      const SizedBox(height: V2Space.lg),
      // Menambah baris bahan baru, bukan mengganti bahan baris pertama
      // (BUG-38; kontrak server menerima `materials[]` lebih dari satu).
      V2Button(
        label: 'Tambah bahan',
        type: V2ButtonType.ghost,
        onPressed: bisaTambah ? () => _tambahBahan() : null,
      ),
      // Kartu tint menjelaskan stok yang berkurang, termasuk saat hasilnya
      // minus ("Stok tidak mencukupi"); disembunyikan hanya saat keyboard
      // menutup ruangnya (5.9).
      if (!_keyboard && _baris.any((baris) => baris.bahan != null)) ...[
        const SizedBox(height: V2Space.lg),
        _tintCard(),
      ],
    ];
  }

  /// Satu baris bahan: pilih bahan, jumlah, lalu hapus bila lebih dari satu.
  Widget _barisBahanField(int index) {
    final baris = _baris[index];
    final bahan = baris.bahan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V2SelectField(
          label: index == 0 ? 'Bahan' : 'Bahan ${index + 1}',
          value: bahan?.nama,
          hint: _bahanError == null ? 'Pilih bahan' : '',
          error: index == 0 ? _bahanError : null,
          onTap: () => _pickBahan(
            baris: index,
            dilewati: <String>{
              for (var lain = 0; lain < _baris.length; lain++)
                if (lain != index && _baris[lain].bahan != null)
                  _baris[lain].bahan!.nama,
            },
          ),
        ),
        if (bahan != null) ...[
          const SizedBox(height: V2Space.lg),
          Text(
            'Jumlah bahan',
            style: V2Type.label.copyWith(color: V2Colors.ink),
          ),
          const SizedBox(height: V2Space.sm),
          V2QtyField(
            value: baris.jumlah,
            unit: bahan.satuan,
            error: baris.error != null,
            onChanged: (value) => _setJumlah(index, value),
            onMinus: baris.jumlah <= 1
                ? null
                : () => _setJumlah(index, baris.jumlah - 1),
            onPlus: () => _setJumlah(index, baris.jumlah + 1),
          ),
          if (baris.error != null) ...[
            const SizedBox(height: V2Space.sm),
            Row(
              children: [
                const V2Icon(
                  V2IconName.close,
                  size: V2Icons.small,
                  color: V2Colors.red700,
                ),
                const SizedBox(width: V2Space.sm),
                Expanded(
                  child: Text(
                    baris.error!,
                    style: V2Type.label.copyWith(color: V2Colors.red700),
                  ),
                ),
              ],
            ),
          ],
        ],
        if (_baris.length > 1) ...[
          const SizedBox(height: V2Space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: V2Button(
              label: 'Hapus bahan ${index + 1}',
              type: V2ButtonType.ghost,
              onPressed: () => _hapusBahan(index),
            ),
          ),
        ],
      ],
    );
  }

  /// Kartu `Card Type=Tint` (frame 5.7): judul 20/28 dan isi 16/24.
  ///
  /// Baris yang sisanya minus tidak menampilkan angka negatif; kalimatnya
  /// diganti "Stok tidak mencukupi" supaya penyebabnya jelas di form.
  Widget _tintCard() {
    final baris = _baris.where((item) => item.bahan != null);
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
          for (final item in baris) ...[_barisStok(item)],
        ],
      ),
    );
  }

  /// Satu baris kartu tint; hasil minus diganti "Stok tidak mencukupi".
  Widget _barisStok(_BarisBahan item) {
    final sisa = item.bahan!.stok - item.jumlah;
    return Text(
      sisa < 0
          ? '${item.bahan!.nama}: Stok tidak mencukupi'
          : '${item.bahan!.nama}: ${item.bahan!.labelStok} jadi '
                '$sisa ${item.bahan!.satuan}',
      style: V2Type.body.copyWith(
        color: sisa < 0 ? V2Colors.red700 : V2Colors.slate600,
      ),
    );
  }
}

/// Satu baris bahan di form Tambah semaian.
class _BarisBahan {
  _BarisBahan({this.bahan, this.jumlah = 1});

  V2SemaianBahan? bahan;
  int jumlah;
  String? error;
}
