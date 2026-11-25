import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_meja_data.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_stepper.dart';
import '../widgets/v2_text_field.dart';

/// Daftar kerusakan tanaman pada satu meja (frame 6.24, 6.27, 6.29).
///
/// Satu catatan tampil sebagai kartu `ListItem` sendiri (6.24); dua catatan
/// atau lebih duduk dalam satu `Grup daftar` (6.27). Footer "Catat rusak"
/// membuka form 6.25 dan menyisipkan catatan baru di paling atas, sedangkan
/// ketukan baris membuka form ubah 6.28.
class V2TanamanRusakPage extends StatefulWidget {
  const V2TanamanRusakPage({
    super.key,
    required this.item,
    this.rusak,
    this.toast,
    this.transferId,
    this.onCatat,
    this.onUbah,
  });

  /// Frame `6.24 Daftar rusak`: satu catatan busuk akar.
  V2TanamanRusakPage.biasa({Key? key}) : this(key: key, item: designMejaA2);

  /// Frame `6.27 Kerusakan dicatat`: layu 15 Nov di atas busuk akar 10 Nov.
  V2TanamanRusakPage.setelahCatat({Key? key})
    : this(
        key: key,
        item: designMejaA2,
        rusak: designDaftarRusakSetelahCatat,
        toast: 'Kerusakan dicatat',
      );

  /// Frame `6.29 Kerusakan diubah`: satu catatan dan toast.
  V2TanamanRusakPage.diubah({Key? key})
    : this(
        key: key,
        item: designMejaA2,
        rusak: designDaftarRusak,
        toast: 'Perubahan tersimpan',
      );

  final V2MejaItem item;
  final List<V2KerusakanItem>? rusak;

  /// Toast yang sudah tampil saat halaman dibuka.
  final String? toast;

  /// Batch tanaman tempat "Catat rusak" baru dibuat; null berarti data contoh.
  final String? transferId;

  /// Simpan kerusakan baru ke backend; null berarti perubahan hanya di layar.
  final Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onCatat;

  /// Simpan perubahan kerusakan ke backend; null berarti hanya di layar.
  final Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onUbah;

  static Route<void> route({
    required V2MejaItem item,
    String? transferId,
    Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onCatat,
    Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onUbah,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2TanamanRusakPage(
        item: item,
        transferId: transferId,
        onCatat: onCatat,
        onUbah: onUbah,
      ),
    );
  }

  @override
  State<V2TanamanRusakPage> createState() => _V2TanamanRusakPageState();
}

class _V2TanamanRusakPageState extends State<V2TanamanRusakPage> {
  late List<V2KerusakanItem> _rusak = widget.rusak ?? widget.item.rusak;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _scheduleToastDismiss();
  }

  Future<void> _catat() async {
    final hasil = await Navigator.of(context).push<V2KerusakanItem>(
      V2CatatRusakPage.route(meja: widget.item, transferId: widget.transferId),
    );
    if (!mounted || hasil == null) return;
    final simpan = widget.onCatat;
    if (simpan == null) {
      setState(() => _rusak = [hasil, ..._rusak]);
      _showToast('Kerusakan dicatat');
      return;
    }
    try {
      final tersimpan = await simpan(hasil);
      if (!mounted) return;
      setState(() => _rusak = [tersimpan, ..._rusak]);
      _showToast('Kerusakan dicatat');
    } catch (error) {
      if (!mounted) return;
      _pesan('$error');
    }
  }

  Future<void> _ubah(V2KerusakanItem rusak) async {
    final hasil = await Navigator.of(context).push<V2KerusakanItem>(
      V2CatatRusakPage.route(
        meja: widget.item,
        kerusakan: rusak,
        transferId: widget.transferId,
      ),
    );
    if (!mounted || hasil == null) return;
    final simpan = widget.onUbah;
    if (simpan != null) {
      try {
        final tersimpan = await simpan(hasil);
        if (!mounted) return;
        setState(() => _rusak = _ganti(rusak, tersimpan));
        _showToast('Perubahan tersimpan');
      } catch (error) {
        if (!mounted) return;
        _pesan('$error');
      }
      return;
    }
    setState(() => _rusak = _ganti(rusak, hasil));
    _showToast('Perubahan tersimpan');
  }

  List<V2KerusakanItem> _ganti(V2KerusakanItem lama, V2KerusakanItem baru) => [
    for (final baris in _rusak)
      if (identical(baris, lama)) baru else baris,
  ];

  void _pesan(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  V2ListItem _row(V2KerusakanItem rusak) {
    return V2ListItem(
      title: rusak.judul,
      subtitle: rusak.subjudul,
      icon: V2IconName.warning,
      iconTone: V2ListItemIconTone.warning,
      onTap: () => _ubah(rusak),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Tanaman rusak',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: _rusak.length == 1
                      ? _row(_rusak.first)
                      : V2GroupList(
                          children: [for (final rusak in _rusak) _row(rusak)],
                        ),
                ),
              ),
              V2ActionBar(
                toast: _toast,
                actions: [V2Button(label: 'Catat rusak', onPressed: _catat)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form "Catat rusak" (frame 6.25/6.26) dan "Ubah kerusakan" (6.28).
///
/// Isian: tanggal kejadian, jumlah tanaman dengan unit "tanaman", pilihan jenis
/// kerusakan dalam dua baris chip, lalu keterangan opsional. Galat jumlah
/// menambah baris pesan 28 di bawah stepper; galat jenis menambah 28 di bawah
/// chip (frame 6.26).
class V2CatatRusakPage extends StatefulWidget {
  const V2CatatRusakPage({
    super.key,
    this.meja,
    this.kerusakan,
    this.previewValidation = false,
    this.transferId,
  });

  /// Frame `6.25 Catat rusak`.
  V2CatatRusakPage.catat({Key? key}) : this(key: key, meja: designMejaA2);

  /// Frame `6.26 Catat rusak, validasi`: 45 tanaman dan jenis belum dipilih.
  V2CatatRusakPage.validation({Key? key})
    : this(key: key, meja: designMejaA2, previewValidation: true);

  /// Frame `6.28 Ubah kerusakan`: busuk akar 10 Nov dengan catatan.
  V2CatatRusakPage.ubah({Key? key})
    : this(key: key, meja: designMejaA2, kerusakan: designKerusakanBusukAkar);

  final V2MejaItem? meja;
  final V2KerusakanItem? kerusakan;
  final bool previewValidation;

  /// Batch tanaman tujuan laporan baru; dipakai mengirim ke backend.
  final String? transferId;

  static Route<V2KerusakanItem> route({
    V2MejaItem? meja,
    V2KerusakanItem? kerusakan,
    String? transferId,
  }) {
    return MaterialPageRoute<V2KerusakanItem>(
      builder: (_) => V2CatatRusakPage(
        meja: meja,
        kerusakan: kerusakan,
        transferId: transferId,
      ),
    );
  }

  @override
  State<V2CatatRusakPage> createState() => _V2CatatRusakPageState();
}

class _V2CatatRusakPageState extends State<V2CatatRusakPage> {
  static const List<String> _jenis = <String>[
    'Busuk akar',
    'Layu',
    'Hama',
    'Lainnya',
  ];

  late DateTime _tanggal = widget.previewValidation
      ? DateTime(2026, 11, 15)
      : widget.kerusakan?.tanggal ?? DateTime(2026, 11, 15);
  late int _jumlah = widget.previewValidation
      ? 45
      : widget.kerusakan?.jumlah ?? 2;
  late String? _jenisDipilih = widget.previewValidation
      ? null
      : widget.kerusakan?.jenis ?? 'Busuk akar';
  late final TextEditingController _keterangan = TextEditingController(
    text: widget.kerusakan?.keterangan ?? '',
  );

  String? _jumlahError;
  String? _jenisError;

  bool get _ubah => widget.kerusakan != null;

  /// Banyak tanaman aktif di meja; batas atas jumlah yang bisa dicatat rusak.
  int get _aktif =>
      widget.meja?.tanaman.fold<int>(
        0,
        (total, tanaman) => total + tanaman.jumlahAktif,
      ) ??
      40;

  @override
  void initState() {
    super.initState();
    if (widget.previewValidation) {
      _jumlahError = 'Tanaman aktif hanya $_aktif';
      _jenisError = 'Pilih jenis kerusakan';
    }
  }

  @override
  void dispose() {
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showV2SemaianDateSheet(context, selected: _tanggal);
    if (!mounted || hasil == null) return;
    setState(() => _tanggal = hasil);
  }

  void _simpan() {
    setState(() {
      _jumlahError = _jumlah > _aktif ? 'Tanaman aktif hanya $_aktif' : null;
      _jenisError = _jenisDipilih == null ? 'Pilih jenis kerusakan' : null;
    });
    if (_jumlahError != null || _jenisError != null) return;

    final lama = widget.kerusakan;
    final dasar =
        lama ??
        V2KerusakanItem(
          jumlah: _jumlah,
          jenis: 'Busuk akar',
          tanggal: _tanggal,
          varietas: widget.meja?.tanaman.firstOrNull?.varietas ?? 'Romaine',
          meja: widget.meja?.kode ?? 'A2',
          transferId: widget.transferId,
        );
    Navigator.of(context).pop(
      dasar.copyWith(
        jumlah: _jumlah,
        jenis: _jenisDipilih,
        tanggal: _tanggal,
        keterangan: _keterangan.text.trim(),
        transferId: lama?.transferId ?? widget.transferId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: _ubah ? 'Ubah kerusakan' : 'Catat rusak',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2SelectField(
                        label: 'Tanggal kejadian',
                        value: labelTanggalLengkap(_tanggal),
                        icon: V2IconName.calendar,
                        onTap: _pilihTanggal,
                      ),
                      const SizedBox(height: V2Space.lg),
                      _jumlahField(),
                      const SizedBox(height: V2Space.lg),
                      _jenisField(),
                      const SizedBox(height: V2Space.lg),
                      V2TextField(
                        label: 'Keterangan (opsional)',
                        hint: 'Contoh: akar berlendir',
                        controller: _keterangan,
                      ),
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                actions: [V2Button(label: 'Simpan', onPressed: _simpan)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jumlahField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Jumlah tanaman',
          style: V2Type.label.copyWith(color: V2Colors.ink),
        ),
        const SizedBox(height: V2Space.sm),
        V2QtyField(
          value: _jumlah,
          unit: 'tanaman',
          error: _jumlahError != null,
          onMinus: () {
            if (_jumlah > 1) setState(() => _jumlah--);
          },
          onPlus: () => setState(() => _jumlah++),
        ),
        if (_jumlahError != null) ...[
          const SizedBox(height: V2Space.sm),
          _helper(_jumlahError!),
        ],
      ],
    );
  }

  Widget _jenisField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Jenis kerusakan',
          style: V2Type.label.copyWith(color: V2Colors.ink),
        ),
        const SizedBox(height: V2Space.sm),
        Wrap(
          spacing: V2Space.sm,
          runSpacing: V2Space.sm,
          children: [
            for (final jenis in _jenis)
              V2Chip(
                label: jenis,
                selected: _jenisDipilih == jenis,
                onTap: () => setState(() => _jenisDipilih = jenis),
              ),
          ],
        ),
        if (_jenisError != null) ...[
          const SizedBox(height: V2Space.sm),
          _helper(_jenisError!),
        ],
      ],
    );
  }

  Widget _helper(String pesan) {
    return Row(
      children: [
        const V2Icon(V2IconName.error, size: 16, color: V2Colors.red700),
        const SizedBox(width: V2Space.sm),
        Expanded(
          child: Text(
            pesan,
            style: V2Type.label.copyWith(color: V2Colors.red700),
          ),
        ),
      ],
    );
  }
}
