import 'package:flutter/material.dart';

import '../components/v2_panen_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_text_field.dart';

/// Form "Ubah panen" (frame 7.19), galat berat di bawah yang terjual (7.20),
/// dan dialog data sudah berubah (7.23).
///
/// Satu panen bisa memuat beberapa rincian batch. Bila hanya ada satu rincian
/// (atau data contoh galeri tanpa rincian), yang tampil satu isian berat
/// seperti frame 7.19. Bila lebih dari satu, tiap rincian punya isian beratnya
/// sendiri supaya koreksinya dikirim per `id_detail_panen`.
///
/// Hanya berat total, berat reject, dan keterangan yang bisa diubah; jumlah
/// tanaman dan tanggal dikunci dengan catatan di bawah isian. Catatan itu
/// hilang saat ada galat (7.20) karena baris galat sudah mengisi ruangnya.
class V2PanenEditPage extends StatefulWidget {
  const V2PanenEditPage({
    super.key,
    required this.item,
    this.previewUnderSold = false,
    this.previewKonflik = false,
  });

  /// Frame `7.19 Ubah panen`: 255 kg total, 15 kg reject, "Panen pagi".
  V2PanenEditPage.biasa({Key? key}) : this(key: key, item: designPanenTerjual);

  /// Frame `7.20 Berat di bawah yang terjual`: 100 total, 20 reject, padahal
  /// 90 kg sudah terjual.
  V2PanenEditPage.bawahTerjual({Key? key})
    : this(key: key, item: designPanenTerjual, previewUnderSold: true);

  /// Frame `7.23 Data sudah berubah`: dialog konflik di atas form.
  V2PanenEditPage.konflik({Key? key})
    : this(key: key, item: designPanenTerjual, previewKonflik: true);

  final V2PanenItem item;
  final bool previewUnderSold;
  final bool previewKonflik;

  static Route<V2PanenItem> route(V2PanenItem item) {
    return MaterialPageRoute<V2PanenItem>(
      builder: (_) => V2PanenEditPage(item: item),
    );
  }

  @override
  State<V2PanenEditPage> createState() => _V2PanenEditPageState();
}

/// Pasangan pengendali berat untuk satu rincian panen.
class _RincianEdit {
  _RincianEdit({
    required this.rincian,
    required this.total,
    required this.reject,
  });

  final V2PanenRincian rincian;
  final TextEditingController total, reject;
}

class _V2PanenEditPageState extends State<V2PanenEditPage> {
  /// Satu pasang pengendali berat untuk tiap rincian. Data contoh galeri yang
  /// tidak punya rincian memakai satu rincian tiruan dari berat panen.
  late final List<_RincianEdit> _rincian = _rincianAwal();

  late final TextEditingController _keterangan = TextEditingController(
    text: widget.item.keterangan ?? '',
  );

  String? _beratError;
  late bool _showKonflik = widget.previewKonflik;

  List<_RincianEdit> _rincianAwal() {
    final sumber = widget.item.rincian.isEmpty
        ? <V2PanenRincian>[
            V2PanenRincian(
              detailId: '',
              label: widget.item.meja,
              beratTotal: widget.item.beratTotal,
              beratReject: widget.item.beratReject,
            ),
          ]
        : widget.item.rincian;
    return [
      for (var index = 0; index < sumber.length; index++)
        _RincianEdit(
          rincian: sumber[index],
          total: TextEditingController(
            text: widget.previewUnderSold && index == 0
                ? '100'
                : labelBeratKg(sumber[index].beratTotal),
          ),
          reject: TextEditingController(
            text: widget.previewUnderSold && index == 0
                ? '20'
                : labelBeratKg(sumber[index].beratReject),
          ),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (widget.previewUnderSold) {
      _beratError =
          'Berat layak 80 kg, sudah terjual ${labelBeratKg(widget.item.terjual)} kg';
    }
  }

  @override
  void dispose() {
    for (final baris in _rincian) {
      baris.total.dispose();
      baris.reject.dispose();
    }
    _keterangan.dispose();
    super.dispose();
  }

  double _berat(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  void _simpan() {
    final layak = _rincian.fold<double>(
      0,
      (total, baris) => total + (_berat(baris.total) - _berat(baris.reject)),
    );

    setState(() {
      _beratError = layak < widget.item.terjual
          ? 'Berat layak ${labelBeratKg(layak < 0 ? 0 : layak)} kg, '
                'sudah terjual ${labelBeratKg(widget.item.terjual)} kg'
          : null;
    });
    if (_beratError != null) return;

    final keterangan = _keterangan.text.trim();
    final rincian = [
      for (final baris in _rincian)
        baris.rincian.copyWith(
          beratTotal: _berat(baris.total),
          beratReject: _berat(baris.reject),
        ),
    ];
    Navigator.of(context).pop(
      widget.item.copyWith(
        beratTotal: rincian.fold<double>(0, (a, b) => a + b.beratTotal),
        beratReject: rincian.fold<double>(0, (a, b) => a + b.beratReject),
        keterangan: keterangan.isEmpty ? null : keterangan,
        // Data contoh galeri tidak punya rincian; jangan munculkan rincian
        // tiruan ke data yang ditampilkan.
        rincian: widget.item.rincian.isEmpty ? null : rincian,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multi = _rincian.length > 1;
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  V2AppBar(
                    title: 'Ubah panen',
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
                          for (
                            var index = 0;
                            index < _rincian.length;
                            index++
                          ) ...[
                            if (multi) ...[
                              if (index > 0) const SizedBox(height: V2Space.xl),
                              Text(
                                _rincian[index].rincian.label,
                                style: V2Type.bodyStrong,
                              ),
                              const SizedBox(height: V2Space.md),
                            ],
                            V2TextField(
                              label: 'Berat total (kg)',
                              hint: '0',
                              controller: _rincian[index].total,
                              error: index == 0 ? _beratError : null,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: V2Space.lg),
                            V2TextField(
                              label: 'Berat reject (kg)',
                              hint: '0',
                              controller: _rincian[index].reject,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: V2Space.lg),
                          ],
                          V2TextField(
                            label: 'Keterangan (opsional)',
                            hint: 'Contoh: Panen pagi',
                            controller: _keterangan,
                          ),
                          if (_beratError == null) ...[
                            const SizedBox(height: V2Space.lg),
                            Text(
                              'Jumlah tanaman dan tanggal tidak bisa diubah.',
                              style: V2Type.label.copyWith(
                                color: V2Colors.muted,
                              ),
                            ),
                          ],
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
            if (_showKonflik) _lapisanKonflik(),
          ],
        ),
      ),
    );
  }

  /// Scrim 60% dan dialog 342×308 tepat di tengah layar penuh (frame 7.23).
  Widget _lapisanKonflik() {
    return Positioned.fill(
      child: ColoredBox(
        color: V2Colors.ink.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Dialog(
              title: 'Data sudah berubah',
              body:
                  'Data ini baru diubah di perangkat lain. Muat ulang untuk '
                  'melihat versi terbaru, lalu ubah lagi.',
              primaryLabel: 'Muat ulang',
              onPrimary: () => setState(() => _showKonflik = false),
              secondaryLabel: 'Batal',
              onSecondary: () => setState(() => _showKonflik = false),
            ),
          ),
        ),
      ),
    );
  }
}
