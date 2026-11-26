import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_panen_assets.dart';
import '../components/v2_panen_data.dart';
import '../components/v2_penjualan_data.dart';
import '../components/v2_penjualan_info_card.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_panen_edit_page.dart';
import 'v2_penjualan_form_page.dart';

/// Detail satu catatan panen (frame 7.14, 7.16–7.18, 7.21).
///
/// Kartu ringkasan biru memuat tanggal panen, status penjualan, berat layak,
/// meja, jumlah tanaman, dan sisa. Kartu putih di bawahnya merinci berat total,
/// reject, dan layak.
///
/// Petani mendapat "Catat penjualan" + "Ubah"; pegawai hanya "Ubah" (7.18).
/// Panen yang belum tersimpan di server menampilkan catatan dan menonaktifkan
/// "Catat penjualan" (7.16). Setelah ubah tersimpan, muncul toast
/// "Perubahan tersimpan" (7.21).
class V2PanenDetailPage extends StatefulWidget {
  const V2PanenDetailPage({
    super.key,
    required this.item,
    this.role = V2BerandaRole.petani,
    this.toast,
    this.onUbah,
    this.onCatatPenjualan,
  });

  /// Frame `7.17 Detail panen`: panen 6 Nov, sebagian terjual.
  V2PanenDetailPage.biasa({Key? key})
    : this(key: key, item: designPanenTerjual);

  /// Frame `7.18 Detail panen (Pegawai)`: tanpa aksi catat penjualan.
  V2PanenDetailPage.pegawai({Key? key})
    : this(key: key, item: designPanenTerjual, role: V2BerandaRole.pegawai);

  /// Frame `7.14 Detail panen baru`: panen 15 Nov, belum terjual.
  V2PanenDetailPage.baru({Key? key}) : this(key: key, item: designPanenBaru);

  /// Frame `7.16 Detail panen, antrean`: panen belum tersimpan di server.
  V2PanenDetailPage.antrean({Key? key})
    : this(key: key, item: designPanenAntrean);

  /// Frame `7.21 Perubahan tersimpan`: detail dengan toast.
  V2PanenDetailPage.tersimpan({Key? key})
    : this(key: key, item: designPanenTerjual, toast: 'Perubahan tersimpan');

  final V2PanenItem item;
  final V2BerandaRole role;

  /// Toast yang sudah tampil saat halaman dibuka (frame 7.21).
  final String? toast;

  /// Simpan koreksi ke backend; null berarti perubahan hanya di layar.
  final Future<V2PanenItem> Function(V2PanenItem item)? onUbah;

  /// Handler "Catat penjualan" dari aplikasi tersambung; null berarti alur
  /// pratinjau galeri (form hanya di memori). (BUG-42)
  final Future<void> Function()? onCatatPenjualan;

  static Route<V2PanenItem> route(V2PanenItem item) {
    return MaterialPageRoute<V2PanenItem>(
      builder: (_) => V2PanenDetailPage(item: item),
    );
  }

  @override
  State<V2PanenDetailPage> createState() => _V2PanenDetailPageState();
}

class _V2PanenDetailPageState extends State<V2PanenDetailPage> {
  late V2PanenItem _item = widget.item;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
  }

  /// Salinan lokal disamakan saat induk mengirim data terbaru (mis. angka
  /// terjual/sisa setelah penjualan, BUG-43).
  @override
  void didUpdateWidget(covariant V2PanenDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.item, oldWidget.item)) {
      _item = widget.item;
    }
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

  Future<void> _ubah() async {
    final updated = await Navigator.of(
      context,
    ).push<V2PanenItem>(V2PanenEditPage.route(_item));
    if (!mounted || updated == null) return;
    final simpan = widget.onUbah;
    V2PanenItem hasil = updated;
    if (simpan != null) {
      try {
        hasil = await simpan(updated);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$error')));
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _item = hasil;
      _toast = 'Perubahan tersimpan';
    });
    _scheduleToastDismiss();
  }

  Future<void> _catatPenjualan() async {
    final handler = widget.onCatatPenjualan;
    if (handler != null) {
      await handler();
      return;
    }
    await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanFormPage.route(
        panen: <V2PenjualanPanen>[
          V2PenjualanPanen(
            id: _item.id,
            tanggalPanen: _item.tanggal,
            sisaKg: _item.sisa,
          ),
        ],
      ),
    );
  }

  bool get _pegawai => widget.role == V2BerandaRole.pegawai;

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
                title: 'Detail panen',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ringkasan(),
                      const SizedBox(height: V2Space.lg),
                      _info(),
                      // Keterangan panen yang diisi saat mencatat (keputusan SA).
                      if ((_item.keterangan ?? '').isNotEmpty) ...[
                        const SizedBox(height: V2Space.lg),
                        V2PenjualanInfoCard(
                          rows: <V2PenjualanInfoRow>[
                            V2PenjualanInfoRow(
                              label: 'Keterangan',
                              value: _item.keterangan!,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ringkasan() {
    return V2SummaryCard(
      kicker: _item.labelPanen,
      badge: _badge(),
      value: _item.labelBerat,
      meta: _item.labelMeta,
      extra: _item.labelSisa,
    );
  }

  Widget _badge() {
    if (_item.status == V2PanenStatus.antrean) {
      return const V2Badge(label: 'Antrean', status: V2BadgeStatus.pending);
    }
    return V2Badge(
      label: _item.status == V2PanenStatus.terjualSebagian
          ? 'Terjual sebagian'
          : 'Belum terjual',
      status: V2BadgeStatus.info,
    );
  }

  Widget _info() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(
            label: 'Berat total',
            value: '${labelBeratKg(_item.beratTotal)} kg',
          ),
          const SizedBox(height: V2Space.md),
          _InfoRow(
            label: 'Berat reject',
            value: '${labelBeratKg(_item.beratReject)} kg',
          ),
          const SizedBox(height: V2Space.md),
          _InfoRow(label: 'Berat layak', value: _item.labelBerat),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_pegawai) {
      return V2ActionBar(
        toast: _toast,
        actions: [
          V2Button(
            label: 'Ubah',
            type: V2ButtonType.tertiary,
            onPressed: _ubah,
          ),
        ],
      );
    }

    if (_item.antrean) {
      return V2ActionBar(
        note: 'Panen belum sinkron. Penjualan bisa dicatat setelah sinkron.',
        toast: _toast,
        actions: [
          const V2Button(
            label: 'Catat penjualan',
            state: V2ButtonState.disabled,
          ),
          V2Button(
            label: 'Ubah',
            type: V2ButtonType.tertiary,
            onPressed: _ubah,
          ),
        ],
      );
    }

    return V2ActionBar(
      toast: _toast,
      actions: [
        V2Button(label: 'Catat penjualan', onPressed: _catatPenjualan),
        V2Button(label: 'Ubah', type: V2ButtonType.tertiary, onPressed: _ubah),
      ],
    );
  }
}

/// Satu baris kartu info: label 14/20 muted di kiri, nilai 16/24 di kanan.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ),
        const SizedBox(width: V2Space.sm),
        Text(value, style: V2Type.bodyStrong),
      ],
    );
  }
}

/// Halaman hasil "Panen dicatat" (frame 7.13).
///
/// Tanpa AppBar: ilustrasi panen di tengah atas, judul "Panen dicatat", lalu
/// berat layak dan meja asalnya. Footer menyediakan "Catat penjualan" dan
/// "Selesai".
class V2PanenSavedPage extends StatelessWidget {
  const V2PanenSavedPage({
    super.key,
    this.beratLayak = 252,
    this.meja = 'Meja B1',
    this.onCatatPenjualan,
  });

  final double beratLayak;
  final String meja;
  final VoidCallback? onCatatPenjualan;

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const V2PanenSavedPage());
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
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 72),
                  child: Column(
                    children: [
                      const SizedBox(height: 154),
                      Image.asset(
                        V2PanenAssets.harvestLettuce,
                        width: 160,
                        height: 160,
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text('Panen dicatat', style: V2Type.h1),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        '${labelBeratKg(beratLayak)} kg layak dari $meja.',
                        textAlign: TextAlign.center,
                        style: V2Type.body.copyWith(color: V2Colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Footer 162: primary 56, jarak 16, ghost 48, sisa 8 di atas home
  /// indicator. `V2ActionBar` berhenti di 8+48+16+56+34 = 162 hanya untuk dua
  /// tombol 56, jadi baris ini disusun sendiri.
  Widget _footer(BuildContext context) {
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
              V2Button(
                label: 'Catat penjualan',
                onPressed: onCatatPenjualan ?? () {},
              ),
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: 'Selesai',
                type: V2ButtonType.ghost,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
