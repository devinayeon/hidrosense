import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_rawat_assets.dart';
import '../components/v2_rawat_data.dart';
import '../components/v2_rawat_foto_card.dart';
import '../components/v2_rawat_option_row.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_select_field.dart';
import 'v2_rawat_hasil_page.dart';

const List<String> _pilihanTanamanRawat = <String>[
  'Meja A2, Romaine',
  'Meja A3, Butterhead',
];

/// Alur foto tanaman page 09: tips (9.5), izin kamera (9.6/9.7), kamera (9.8),
/// pratinjau (9.9), tanpa internet (9.10), mengunggah (9.12), dan menganalisis
/// (9.13).
///
/// Semua keadaan memakai satu kelas supaya galeri bisa membuka frame mana pun.
/// [onSaved] dipanggil setelah perawatan dikonfirmasi agar daftar di belakang
/// langsung memuat baris baru.
class V2RawatFotoPage extends StatefulWidget {
  const V2RawatFotoPage({
    super.key,
    this.mode = V2RawatFotoMode.tips,
    this.auto = false,
    this.onSaved,
  });

  /// Frame `9.5 Tips foto`.
  const V2RawatFotoPage.tips({Key? key})
    : this(key: key);

  /// Frame `9.6 Izin kamera`.
  const V2RawatFotoPage.izin({Key? key})
    : this(key: key, mode: V2RawatFotoMode.izin);

  /// Frame `9.7 Izin kamera ditolak`.
  const V2RawatFotoPage.izinDitolak({Key? key})
    : this(key: key, mode: V2RawatFotoMode.izinDitolak);

  /// Frame `9.8 Kamera`.
  const V2RawatFotoPage.kamera({Key? key})
    : this(key: key, mode: V2RawatFotoMode.kamera);

  /// Frame `9.9 Pratinjau foto`.
  const V2RawatFotoPage.pratinjau({Key? key})
    : this(key: key, mode: V2RawatFotoMode.pratinjau);

  /// Frame `9.10 Foto tanpa internet`.
  const V2RawatFotoPage.tanpaInternet({Key? key})
    : this(key: key, mode: V2RawatFotoMode.tanpaInternet);

  /// Frame `9.12 Mengunggah foto` (tanpa maju otomatis).
  const V2RawatFotoPage.unggah({Key? key})
    : this(key: key, mode: V2RawatFotoMode.unggah);

  /// Frame `9.13 Menganalisis foto` (tanpa maju otomatis).
  const V2RawatFotoPage.analisis({Key? key})
    : this(key: key, mode: V2RawatFotoMode.analisis);

  final V2RawatFotoMode mode;

  /// Menjalankan transisi otomatis: unggah → analisis → hasil.
  final bool auto;

  final ValueChanged<V2RawatItem>? onSaved;

  static Route<V2RawatItem> route({
    ValueChanged<V2RawatItem>? onSaved,
  }) {
    return MaterialPageRoute<V2RawatItem>(
      builder: (_) => V2RawatFotoPage(auto: true, onSaved: onSaved),
    );
  }

  @override
  State<V2RawatFotoPage> createState() => _V2RawatFotoPageState();
  static Route<void> kameraRouteWith(ValueChanged<V2RawatItem>? onSaved) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatFotoPage(
        mode: V2RawatFotoMode.kamera,
        onSaved: onSaved,
      ),
    );
  }

  static Route<void> pratinjauRoute(ValueChanged<V2RawatItem>? onSaved) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatFotoPage(
        mode: V2RawatFotoMode.pratinjau,
        onSaved: onSaved,
      ),
    );
  }

  static Route<void> unggahRoute(ValueChanged<V2RawatItem>? onSaved) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatFotoPage(
        mode: V2RawatFotoMode.unggah,
        auto: true,
        onSaved: onSaved,
      ),
    );
  }
}

/// Keadaan yang punya frame sendiri di alur foto.
enum V2RawatFotoMode {
  tips,
  izin,
  izinDitolak,
  kamera,
  pratinjau,
  tanpaInternet,
  unggah,
  analisis,
}

class _V2RawatFotoPageState extends State<V2RawatFotoPage> {
  Timer? _timer;
  late V2RawatFotoMode _mode = widget.mode;

  @override
  void initState() {
    super.initState();
    if (widget.auto &&
        (_mode == V2RawatFotoMode.unggah || _mode == V2RawatFotoMode.analisis)) {
      _jadwalkan();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _jadwalkan() {
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: _mode == V2RawatFotoMode.unggah ? 900 : 1200),
      () {
        if (!mounted) return;
        if (_mode == V2RawatFotoMode.unggah) {
          setState(() => _mode = V2RawatFotoMode.analisis);
          _jadwalkan();
          return;
        }
        Navigator.of(context).pushReplacement(
          V2RawatHasilPage.route(onSaved: widget.onSaved),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      V2RawatFotoMode.tips => _tips(context),
      V2RawatFotoMode.izin => _izin(context, ditolak: false),
      V2RawatFotoMode.izinDitolak => _izin(context, ditolak: true),
      V2RawatFotoMode.kamera => _kamera(context),
      V2RawatFotoMode.pratinjau => _pratinjau(context, offline: false),
      V2RawatFotoMode.tanpaInternet => _pratinjau(context, offline: true),
      V2RawatFotoMode.unggah => _unggah(context, dianalisis: false),
      V2RawatFotoMode.analisis => _unggah(context, dianalisis: true),
    };
  }

  // ---------------------------------------------------------------- 9.5 tips

  Widget _tips(BuildContext context) {
    return _shell(
      appBar: V2AppBar(
        title: 'Foto tanaman',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: V2ActionBar(
        actions: [
          V2Button(
            label: 'Buka kamera',
            onPressed: () => Navigator.of(
              context,
            ).push(V2RawatFotoPage.kameraRouteWith(widget.onSaved)),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          V2Space.xl,
          V2Space.sm,
          V2Space.xl,
          V2Space.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              V2RawatAssets.itemPlantCare,
              width: 120,
              height: 120,
            ),
            const SizedBox(height: V2Space.sm),
            Text(
              'Foto yang bagus',
              textAlign: TextAlign.center,
              style: V2Type.h1,
            ),
            const SizedBox(height: V2Space.lg),
            const _TipsItem(
              title: 'Dekat dan jelas',
              subtitle: 'Satu daun memenuhi bingkai',
            ),
            const SizedBox(height: V2Space.lg),
            const _TipsItem(
              title: 'Cahaya cukup',
              subtitle: 'Hindari bayangan dan silau',
            ),
            const SizedBox(height: V2Space.lg),
            const _TipsItem(
              title: 'Tanpa goyang',
              subtitle: 'Tahan HP sampai foto diambil',
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------- 9.6/9.7 izin

  Widget _izin(BuildContext context, {required bool ditolak}) {
    final actions = <Widget>[
      V2Button(
        label: ditolak ? 'Buka pengaturan' : 'Izinkan kamera',
        onPressed: () => Navigator.of(
          context,
        ).push(V2RawatFotoPage.kameraRouteWith(widget.onSaved)),
      ),
      V2Button(
        label: 'Pilih dari galeri',
        type: ditolak ? V2ButtonType.tertiary : V2ButtonType.ghost,
        onPressed: () => Navigator.of(
          context,
        ).push(V2RawatFotoPage.pratinjauRoute(widget.onSaved)),
      ),
    ];
    return _shell(
      footer: ditolak
          ? V2ActionBar(actions: actions)
          : _footerDuaDenganGhost(actions: actions),
      child: Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Column(
          children: [
            const SizedBox(height: 142),
            Image.asset(
              ditolak
                  ? V2RawatAssets.offlineNoInternet
                  : V2RawatAssets.itemPlantCare,
              width: 160,
              height: 160,
            ),
            const SizedBox(height: V2Space.lg),
            Text(
              ditolak ? 'Kamera tidak diizinkan' : 'Izinkan kamera',
              textAlign: TextAlign.center,
              style: V2Type.h1,
            ),
            const SizedBox(height: V2Space.lg),
            Text(
              ditolak
                  ? 'Buka pengaturan untuk mengizinkan, atau pilih foto '
                        'dari galeri.'
                  : 'Untuk foto daun dan cek hama. Foto tidak dibagikan.',
              textAlign: TextAlign.center,
              style: V2Type.body.copyWith(color: V2Colors.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 9.8 kamera

  Widget _kamera(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.ink,
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: V2Colors.ink)),
            Positioned(
              top: padding.top + V2Space.sm,
              left: V2Space.lg,
              child: Material(
                color: V2Colors.ink,
                borderRadius: BorderRadius.circular(V2Radius.pill),
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(V2Radius.pill),
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
                      child: Center(
                        child: Text(
                          'Tutup',
                          style: V2Type.label.copyWith(color: V2Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: padding.top + 156,
              left: 40,
              right: 40,
              child: Container(
                height: 310,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(V2Radius.sheet),
                  border: Border.all(color: V2Colors.white, width: 3),
                ),
              ),
            ),
            Positioned(
              top: padding.top + 488,
              left: 75,
              right: 75,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
                decoration: BoxDecoration(
                  color: V2Colors.ink,
                  borderRadius: BorderRadius.circular(V2Radius.pill),
                ),
                child: Center(
                  child: Text(
                    'Dekatkan daun ke bingkai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Type.label.copyWith(color: V2Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: padding.bottom + 40,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: V2Colors.white,
                            width: 3,
                          ),
                        ),
                      ),
                      Material(
                        color: V2Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(
                            context,
                          ).push(V2RawatFotoPage.pratinjauRoute(widget.onSaved)),
                          child: const SizedBox(width: 72, height: 72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------- 9.9 pratinjau / 9.10 offline

  Widget _pratinjau(BuildContext context, {required bool offline}) {
    return _shell(
      appBar: V2AppBar(
        title: 'Foto',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: V2ActionBar(
        actions: [
          V2Button(
            label: offline ? 'Simpan foto' : 'Analisis',
            onPressed: offline
                ? () {
                    widget.onSaved?.call(designRawatFotoAntrean);
                    Navigator.of(context).popUntil(
                      (route) =>
                          route.settings.name == 'v2-rawat-list' ||
                          route.isFirst,
                    );
                  }
                : () => Navigator.of(
                    context,
                  ).push(V2RawatFotoPage.unggahRoute(widget.onSaved)),
          ),
          V2Button(
            label: 'Foto ulang',
            type: V2ButtonType.tertiary,
            onPressed: () => Navigator.of(
              context,
            ).push(V2RawatFotoPage.kameraRouteWith(widget.onSaved)),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          V2Space.xl,
          V2Space.sm,
          V2Space.xl,
          V2Space.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offline) ...[
              const V2Banner(
                message: 'Tanpa internet. Foto disimpan dan dianalisis nanti.',
              ),
              const SizedBox(height: V2Space.lg),
            ],
            V2RawatFotoCard(height: offline ? 200 : 240),
            const SizedBox(height: V2Space.lg),
            const _PilihTanamanField(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------- 9.12 unggah / 9.13 menganalisis

  Widget _unggah(BuildContext context, {required bool dianalisis}) {
    if (dianalisis) {
      return _shell(
        footer: _footerBatal(context),
        child: Padding(
          padding: const EdgeInsets.only(top: 72),
          child: Column(
            children: [
              const SizedBox(height: 154),
                Image.asset(
                  V2RawatAssets.itemPlantCare,
                  width: 160,
                  height: 160,
                ),
                const SizedBox(height: V2Space.lg),
                Text(
                  'Menganalisis foto',
                  textAlign: TextAlign.center,
                  style: V2Type.h1,
                ),
                const SizedBox(height: V2Space.lg),
              Text(
                'Biasanya 10 detik.',
                textAlign: TextAlign.center,
                style: V2Type.body.copyWith(color: V2Colors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return _shell(
      appBar: V2AppBar(
        title: 'Foto',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: V2ActionBar(
        actions: [
          const V2Button(
            label: 'Mengunggah...',
            state: V2ButtonState.loading,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          V2Space.xl,
          V2Space.sm,
          V2Space.xl,
          V2Space.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const V2Banner(
              message: 'Mengunggah foto',
              tone: V2BannerTone.sync,
            ),
            const SizedBox(height: V2Space.lg),
            const V2RawatFotoCard(height: 240),
          ],
        ),
      ),
    );
  }

  /// Footer 162 untuk tombol isi 56 + ghost 48 (frame 9.6): sisa 8 di atas
  /// home indicator, bukan menempel seperti dua tombol isi.
  Widget _footerDuaDenganGhost({required List<Widget> actions}) {
    return Container(
      color: V2Colors.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.xl,
            0,
            V2Space.xl,
            V2Space.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                actions[index],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Footer 98 untuk satu tombol ghost 48 (frame 9.13): jarak 16 di atas home
  /// indicator, bukan 8 seperti tombol isi.
  Widget _footerBatal(BuildContext context) {
    return Container(
      color: V2Colors.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.xl,
            0,
            V2Space.xl,
            V2Space.lg,
          ),
          child: V2Button(
            label: 'Batal',
            type: V2ButtonType.ghost,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  /// Kerangka halaman: AppBar opsional, isi yang bisa menggulir, footer.
  Widget _shell({
    Widget? appBar,
    required Widget child,
    required Widget footer,
  }) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ?appBar,
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: child,
                ),
              ),
              footer,
            ],
          ),
        ),
      ),
    );
  }

}

/// Satu baris tips di 9.5: ikon centang, judul, sub, chevron.
///
/// Chevron diletakkan di atas baris (bukan memakan lebar) supaya teks tetap
/// 246 px seperti frame; kartu memakai bayangan `Shadow/Card`.
class _TipsItem extends StatelessWidget {
  const _TipsItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: V2Colors.blue50,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: V2Icon(V2IconName.check, color: V2Colors.blue700),
                ),
              ),
              const SizedBox(width: V2Space.lg),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: V2Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: V2Type.bodyStrong),
                      const SizedBox(height: V2Space.xs),
                      Text(
                        subtitle,
                        style: V2Type.label.copyWith(
                          color: V2Colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            right: 0,
            top: 28,
            child: V2Icon(V2IconName.chevronRight, color: V2Colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Select “Tanaman” di 9.9/9.10 dengan sheet pilihan seperti 7.9.
class _PilihTanamanField extends StatefulWidget {
  const _PilihTanamanField();

  @override
  State<_PilihTanamanField> createState() => _PilihTanamanFieldState();
}

class _PilihTanamanFieldState extends State<_PilihTanamanField> {
  String _nilai = _pilihanTanamanRawat.first;

  Future<void> _pilih() async {
    final hasil = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: V2Colors.ink.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          var draft = _nilai;
          return V2BottomSheet(
            title: 'Pilih tanaman',
            actions: V2Button(
              label: 'Pilih',
              onPressed: () => Navigator.of(sheetContext).pop(draft),
            ),
            child: Column(
              children: [
                for (var index = 0;
                    index < _pilihanTanamanRawat.length;
                    index++) ...[
                  if (index > 0) const SizedBox(height: V2Space.lg),
                  V2RawatOptionRow(
                    label: _pilihanTanamanRawat[index],
                    selected: _pilihanTanamanRawat[index] == draft,
                    onTap: () => setSheetState(
                      () => draft = _pilihanTanamanRawat[index],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (!mounted || hasil == null) return;
    setState(() => _nilai = hasil);
  }

  @override
  Widget build(BuildContext context) {
    return V2SelectField(
      label: 'Tanaman',
      value: _nilai,
      onTap: _pilih,
    );
  }
}