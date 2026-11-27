import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/business_date.dart';
import '../components/v2_meja_data.dart';
import '../components/v2_penjualan_info_card.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_stepper.dart';
import '../widgets/v2_summary_card.dart';
import '../widgets/v2_text_field.dart';

/// Jam perangkat untuk halaman "Catat rusak".
///
/// Bisa diganti lewat [V2CatatRusakPage.clock] saat uji supaya "hari ini"
/// tidak bergantung pada jam nyata.
DateTime _v2CatatRusakSekarang() => DateTime.now();

/// Jam contoh galeri: frame 6.25 tetap menampilkan 15 Nov 2026.
DateTime _v2CatatRusakJamContoh() => DateTime.utc(2026, 11, 15, 5);

/// Daftar kerusakan tanaman pada satu meja (frame 6.24, 6.27, 6.29).
///
/// Satu catatan tampil sebagai kartu `ListItem` sendiri (6.24); dua catatan
/// atau lebih duduk dalam satu `Grup daftar` (6.27). Footer "Catat rusak"
/// membuka form 6.25 dan menyisipkan catatan baru di paling atas, sedangkan
/// ketukan baris membuka detail kerusakan lebih dulu; tombol "Ubah kerusakan"
/// di halaman detail itulah yang membuka form ubah 6.28.
class V2TanamanRusakPage extends StatefulWidget {
  const V2TanamanRusakPage({
    super.key,
    required this.item,
    this.rusak,
    this.toast,
    this.transferId,
    this.onCatat,
    this.onUbah,
    this.onChanged,
  });

  /// Frame `6.24 Daftar rusak`: satu catatan penyakit.
  V2TanamanRusakPage.biasa({Key? key}) : this(key: key, item: designMejaA2);

  /// Frame `6.27 Kerusakan dicatat`: layu 15 Nov di atas penyakit 10 Nov.
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

  /// Kabari halaman pemanggil setiap daftar berubah (catat/ubah), supaya
  /// "Detail tanaman" tidak menyimpan daftar rusak yang basi (BUG-73).
  final ValueChanged<List<V2KerusakanItem>>? onChanged;

  static Route<void> route({
    required V2MejaItem item,
    String? transferId,
    Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onCatat,
    Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onUbah,
    ValueChanged<List<V2KerusakanItem>>? onChanged,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2TanamanRusakPage(
        item: item,
        transferId: transferId,
        onCatat: onCatat,
        onUbah: onUbah,
        onChanged: onChanged,
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

  void _notify() =>
      widget.onChanged?.call(List<V2KerusakanItem>.unmodifiable(_rusak));

  Future<void> _catat() async {
    final hasil = await Navigator.of(context).push<V2KerusakanItem>(
      V2CatatRusakPage.route(
        meja: widget.item,
        transferId: widget.transferId,
        onSubmit: widget.onCatat,
      ),
    );
    if (!mounted || hasil == null) return;
    setState(() => _rusak = [hasil, ..._rusak]);
    _notify();
    _showToast('Kerusakan dicatat');
  }

  /// Buka detail satu kerusakan; form ubah baru terbuka dari halaman itu.
  Future<void> _bukaDetail(V2KerusakanItem rusak) async {
    final hasil = await Navigator.of(context).push<V2KerusakanItem>(
      V2DetailKerusakanPage.route(
        kerusakan: rusak,
        meja: widget.item,
        transferId: widget.transferId,
        onUbah: widget.onUbah,
      ),
    );
    if (!mounted || hasil == null) return;
    setState(() => _rusak = _ganti(rusak, hasil));
    _notify();
    _showToast('Perubahan tersimpan');
  }

  List<V2KerusakanItem> _ganti(V2KerusakanItem lama, V2KerusakanItem baru) => [
    for (final baris in _rusak)
      if (identical(baris, lama)) baru else baris,
  ];

  V2ListItem _row(V2KerusakanItem rusak) {
    return V2ListItem(
      title: rusak.judul,
      subtitle: rusak.subjudul,
      icon: V2IconName.warning,
      iconTone: V2ListItemIconTone.warning,
      onTap: () => _bukaDetail(rusak),
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

/// Detail satu laporan kerusakan sebelum diubah.
///
/// Ketukan baris di daftar rusak membuka halaman ini lebih dulu; tombol
/// "Ubah kerusakan" di footer barulah membuka form ubah 6.28. Halaman
/// mengembalikan laporan terbaru lewat `pop` supaya baris di daftar ikut
/// berubah.
class V2DetailKerusakanPage extends StatefulWidget {
  const V2DetailKerusakanPage({
    super.key,
    required this.kerusakan,
    this.meja,
    this.transferId,
    this.onUbah,
  });

  /// Pratinjau galeri: penyakit 10 Nov dengan catatan.
  V2DetailKerusakanPage.biasa({Key? key})
    : this(key: key, kerusakan: designKerusakanPenyakit);

  final V2KerusakanItem kerusakan;

  /// Meja asal laporan; dipakai form ubah untuk batas jumlah tanaman.
  final V2MejaItem? meja;

  /// Batch tanaman pemilik laporan; diteruskan ke form ubah.
  final String? transferId;

  /// Simpan perubahan ke backend; null berarti hanya di layar.
  final Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onUbah;

  static Route<V2KerusakanItem> route({
    required V2KerusakanItem kerusakan,
    V2MejaItem? meja,
    String? transferId,
    Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onUbah,
  }) {
    return MaterialPageRoute<V2KerusakanItem>(
      builder: (_) => V2DetailKerusakanPage(
        kerusakan: kerusakan,
        meja: meja,
        transferId: transferId,
        onUbah: onUbah,
      ),
    );
  }

  @override
  State<V2DetailKerusakanPage> createState() => _V2DetailKerusakanPageState();
}

class _V2DetailKerusakanPageState extends State<V2DetailKerusakanPage> {
  late V2KerusakanItem _kerusakan = widget.kerusakan;
  String? _toast;
  Timer? _toastTimer;

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

  /// Buka form ubah 6.28; hasilnya menggantikan laporan di halaman ini.
  Future<void> _ubah() async {
    final hasil = await Navigator.of(context).push<V2KerusakanItem>(
      V2CatatRusakPage.route(
        meja: widget.meja,
        kerusakan: _kerusakan,
        transferId: widget.transferId,
        onSubmit: widget.onUbah,
      ),
    );
    if (!mounted || hasil == null) return;
    setState(() {
      _kerusakan = hasil;
      _toast = 'Perubahan tersimpan';
    });
    _scheduleToastDismiss();
  }

  void _tutup() => Navigator.of(context).pop(_kerusakan);

  @override
  Widget build(BuildContext context) {
    final keterangan = _kerusakan.keterangan?.trim() ?? '';
    return Theme(
      data: V2Theme.light,
      child: PopScope<V2KerusakanItem>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _tutup();
        },
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(title: 'Detail kerusakan', onBack: _tutup),
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
                        V2SummaryCard(
                          kicker:
                              '${_kerusakan.varietas}, Meja ${_kerusakan.meja}',
                          value: '${_kerusakan.jumlah} tanaman',
                          meta: _kerusakan.jenis,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2PenjualanInfoCard(
                          rows: <V2PenjualanInfoRow>[
                            V2PenjualanInfoRow(
                              label: 'Jumlah tanaman',
                              value: '${_kerusakan.jumlah} tanaman',
                            ),
                            V2PenjualanInfoRow(
                              label: 'Tanggal kejadian',
                              value: labelTanggalLengkap(_kerusakan.tanggal),
                            ),
                            if (keterangan.isNotEmpty)
                              V2PenjualanInfoRow(
                                label: 'Keterangan',
                                value: keterangan,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                V2ActionBar(
                  toast: _toast,
                  actions: [
                    V2Button(label: 'Ubah kerusakan', onPressed: _ubah),
                  ],
                ),
              ],
            ),
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
    this.clock = _v2CatatRusakSekarang,
    this.onSubmit,
  });

  /// Frame `6.25 Catat rusak`.
  V2CatatRusakPage.catat({Key? key})
    : this(key: key, meja: designMejaA2, clock: _v2CatatRusakJamContoh);

  /// Frame `6.26 Catat rusak, validasi`: 45 tanaman dan jenis belum dipilih.
  V2CatatRusakPage.validation({Key? key})
    : this(key: key, meja: designMejaA2, previewValidation: true);

  /// Frame `6.28 Ubah kerusakan`: penyakit 10 Nov dengan catatan.
  V2CatatRusakPage.ubah({Key? key})
    : this(key: key, meja: designMejaA2, kerusakan: designKerusakanPenyakit);

  final V2MejaItem? meja;
  final V2KerusakanItem? kerusakan;
  final bool previewValidation;

  /// Batch tanaman tujuan laporan baru; dipakai mengirim ke backend.
  final String? transferId;

  /// Jam yang bisa disuntik; halaman menghitung "hari ini" WIB dari sini
  /// supaya form tanggal tidak memaku 15 Nov (BUG-27).
  final DateTime Function() clock;

  /// Simpan kerusakan ke backend. Bila diisi, tombol "Simpan" membuka pop-up
  /// konfirmasi ulang dan menampilkan spinner sampai proses selesai, baru form
  /// menutup; galat server tampil sebagai pesan dan form tetap terbuka.
  final Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onSubmit;

  static Route<V2KerusakanItem> route({
    V2MejaItem? meja,
    V2KerusakanItem? kerusakan,
    String? transferId,
    Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onSubmit,
  }) {
    return MaterialPageRoute<V2KerusakanItem>(
      builder: (_) => V2CatatRusakPage(
        meja: meja,
        kerusakan: kerusakan,
        transferId: transferId,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<V2CatatRusakPage> createState() => _V2CatatRusakPageState();
}

class _V2CatatRusakPageState extends State<V2CatatRusakPage> {
  static const List<String> _jenis = <String>[
    'Penyakit',
    'Layu',
    'Hama',
    'Lainnya',
  ];

  late DateTime _tanggal = widget.previewValidation
      ? DateTime(2026, 11, 15)
      : widget.kerusakan?.tanggal ?? jakartaToday(widget.clock());
  late int _jumlah = widget.previewValidation
      ? 45
      : widget.kerusakan?.jumlah ?? 2;
  late String? _jenisDipilih = widget.previewValidation
      ? null
      : widget.kerusakan?.jenis ?? 'Penyakit';
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

  /// Ubah jumlah lewat minus/plus atau ketik langsung (BUG-37).
  void _setJumlah(int value) {
    if (value < 1) return;
    setState(() {
      _jumlah = value;
      if (_jumlahError != null) {
        _jumlahError = value > _aktif ? 'Tanaman aktif hanya $_aktif' : null;
      }
    });
  }

  Future<void> _simpan() async {
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
          jenis: 'Penyakit',
          tanggal: _tanggal,
          varietas: widget.meja?.tanaman.firstOrNull?.varietas ?? 'Romaine',
          meja: widget.meja?.kode ?? 'A2',
          transferId: widget.transferId,
        );
    final hasil = dasar.copyWith(
      jumlah: _jumlah,
      jenis: _jenisDipilih,
      tanggal: _tanggal,
      keterangan: _keterangan.text.trim(),
      transferId: lama?.transferId ?? widget.transferId,
    );

    final submit = widget.onSubmit;
    if (submit == null) {
      Navigator.of(context).pop(hasil);
      return;
    }

    V2KerusakanItem? tersimpan;
    try {
      final done = await showV2ActionDialog(
        context,
        title: _ubah ? 'Simpan perubahan kerusakan?' : 'Catat kerusakan?',
        body: _ubah
            ? 'Perubahan laporan kerusakan akan dikirim ke server.'
            : 'Laporan kerusakan akan dikirim ke server.',
        primaryLabel: _ubah ? 'Simpan' : 'Catat',
        type: _ubah ? V2DialogType.confirm : V2DialogType.destructive,
        onConfirm: () async {
          tersimpan = await submit(hasil);
        },
      );
      if (!mounted || !done) return;
      Navigator.of(context).pop(tersimpan ?? hasil);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        // Tombol Simpan dipaku di dasar layar; keyboard tidak menggesernya.
        bottomNavigationBar: V2ActionBar(
          actions: [V2Button(label: 'Simpan', onPressed: _simpan)],
        ),
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
          onChanged: _setJumlah,
          onMinus: () => _setJumlah(_jumlah - 1),
          onPlus: () => _setJumlah(_jumlah + 1),
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
