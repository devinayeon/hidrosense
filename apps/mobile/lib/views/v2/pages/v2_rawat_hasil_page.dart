import 'package:flutter/material.dart';

import '../components/v2_rawat_ai_banner.dart';
import '../components/v2_rawat_assets.dart';
import '../components/v2_rawat_data.dart';
import '../components/v2_rawat_foto_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_stock_item.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_rawat_foto_page.dart';
import 'v2_rawat_obat_page.dart';

/// Hasil analisis AI (frame 9.14–9.18).
///
/// [hama] berisi satu hama (9.14) atau beberapa (9.15). [rendah] memakai kartu
/// keyakinan rendah (9.16), [sehat] halaman tanpa hama (9.17), dan [gagal]
/// keadaan galat analisis (9.18).
class V2RawatHasilPage extends StatelessWidget {
  const V2RawatHasilPage({
    super.key,
    this.hama = const <V2Hama>[designHamaThrips],
    this.rendah = false,
    this.sehat = false,
    this.gagal = false,
    this.onSaved,
  });

  /// Frame `9.14 Hasil: hama ditemukan`: Thrips 87%.
  const V2RawatHasilPage.hama({Key? key}) : this(key: key);

  /// Frame `9.15 Hasil: beberapa hama`: Thrips 87% dan Kutu daun 64%.
  const V2RawatHasilPage.beberapa({Key? key})
    : this(
        key: key,
        hama: const <V2Hama>[designHamaThrips, designHamaKutuDaun],
      );

  /// Frame `9.16 Hasil: keyakinan rendah`: 42%, “Mungkin Thrips”.
  const V2RawatHasilPage.rendah({Key? key})
    : this(key: key, hama: const <V2Hama>[designHamaRendah], rendah: true);

  /// Frame `9.17 Hasil: tanaman sehat`.
  const V2RawatHasilPage.sehat({Key? key})
    : this(key: key, hama: const <V2Hama>[], sehat: true);

  /// Frame `9.18 Analisis gagal`.
  const V2RawatHasilPage.gagal({Key? key})
    : this(key: key, hama: const <V2Hama>[], gagal: true);

  final List<V2Hama> hama;
  final bool rendah;
  final bool sehat;
  final bool gagal;
  final ValueChanged<V2RawatItem>? onSaved;

  static Route<void> route({ValueChanged<V2RawatItem>? onSaved}) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatHasilPage(onSaved: onSaved),
    );
  }

  bool get _banyak => hama.length > 1;

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
              if (!sehat)
                V2AppBar(
                  title: 'Hasil deteksi',
                  onBack: () => Navigator.of(context).pop(),
                ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      V2Space.xl,
                      sehat ? 72 : V2Space.sm,
                      V2Space.xl,
                      V2Space.xl,
                    ),
                    child: gagal
                        ? _gagal(context)
                        : sehat
                        ? _sehat()
                        : _hasil(context),
                  ),
                ),
              ),
              if (!gagal) _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hasil(BuildContext context) {
    if (_banyak) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const V2RawatFotoCard(height: 140),
          const SizedBox(height: V2Space.lg),
          Text('${hama.length} hama ditemukan', style: V2Type.h2),
          const SizedBox(height: V2Space.lg),
          V2GroupList(
            children: [
              for (final item in hama)
                V2StockItem(
                  title: item.nama,
                  subtitle: item.labelKeyakinan,
                  quantity: item.labelPersen,
                  icon: V2IconName.care,
                  iconSize: 24,
                  badge: const V2Badge(
                    label: 'Tindakan',
                    status: V2BadgeStatus.warning,
                  ),
                  withCard: false,
                ),
            ],
          ),
          const SizedBox(height: V2Space.lg),
          const V2RawatAiBanner(),
        ],
      );
    }

    final utama = hama.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const V2RawatFotoCard(height: 140),
        const SizedBox(height: V2Space.lg),
        V2SummaryCard(
          kicker: rendah ? 'Hasil kurang yakin' : 'Meja A2, 15 Nov',
          badge: rendah
              ? const V2Badge(label: 'Rendah', status: V2BadgeStatus.warning)
              : const V2Badge(
                  label: 'Perlu tindakan',
                  status: V2BadgeStatus.warning,
                ),
          value: rendah ? utama.labelPersen : utama.nama,
          meta: rendah
              ? 'Mungkin ${utama.nama}'
              : 'Keyakinan ${utama.labelPersen}',
          extra: rendah
              ? 'Foto kurang jelas. Coba foto lebih dekat.'
              : 'Hasil AI. Periksa tanaman langsung.',
        ),
        const SizedBox(height: V2Space.lg),
        const V2RawatAiBanner(),
      ],
    );
  }

  Widget _sehat() {
    return Column(
      children: [
        const SizedBox(height: 124),
        Image.asset(V2RawatAssets.harvestLettuce, width: 160, height: 160),
        const SizedBox(height: V2Space.lg),
        Text(
          'Tanaman tampak sehat',
          textAlign: TextAlign.center,
          style: V2Type.h1,
        ),
        const SizedBox(height: V2Space.lg),
        Text(
          'Keyakinan 93%. Pantau lagi minggu depan.',
          textAlign: TextAlign.center,
          style: V2Type.body.copyWith(color: V2Colors.muted),
        ),
      ],
    );
  }

  Widget _gagal(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: V2Space.xl),
      child: V2ErrorState(
        title: 'Analisis gagal',
        body: 'Foto tetap tersimpan. Coba lagi.',
        actionLabel: 'Coba lagi',
        onAction: () =>
            Navigator.of(context).push(V2RawatFotoPage.unggahRoute(onSaved)),
        illustration: Image.asset(
          V2RawatAssets.offlineNoInternet,
          width: 160,
          height: 160,
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (sehat) {
      return V2ActionBar(
        actions: [
          V2Button(
            label: 'Selesai',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    }

    if (_banyak) {
      return V2ActionBar(
        actions: [
          V2Button(
            label: 'Lihat obat Thrips',
            onPressed: () => Navigator.of(
              context,
            ).push(V2RawatObatPage.thripsRoute(onSaved)),
          ),
          V2Button(
            label: 'Lihat obat Kutu daun',
            type: V2ButtonType.tertiary,
            onPressed: () => Navigator.of(
              context,
            ).push(V2RawatObatPage.kutuDaunRoute(onSaved)),
          ),
        ],
      );
    }

    if (rendah) {
      return V2ActionBar(
        actions: [
          V2Button(
            label: 'Foto ulang',
            onPressed: () => Navigator.of(
              context,
            ).push(V2RawatFotoPage.kameraRouteWith(onSaved)),
          ),
          V2Button(
            label: 'Tetap lihat obat',
            type: V2ButtonType.tertiary,
            onPressed: () => Navigator.of(
              context,
            ).push(V2RawatObatPage.thripsRoute(onSaved)),
          ),
        ],
      );
    }

    return V2ActionBar(
      actions: [
        V2Button(
          label: 'Lihat obat',
          onPressed: () =>
              Navigator.of(context).push(V2RawatObatPage.thripsRoute(onSaved)),
        ),
        V2Button(
          label: 'Foto ulang',
          type: V2ButtonType.tertiary,
          onPressed: () => Navigator.of(
            context,
          ).push(V2RawatFotoPage.kameraRouteWith(onSaved)),
        ),
      ],
    );
  }
}
