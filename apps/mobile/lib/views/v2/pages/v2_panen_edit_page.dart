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
  V2PanenEditPage.biasa({Key? key})
    : this(key: key, item: designPanenTerjual);

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

class _V2PanenEditPageState extends State<V2PanenEditPage> {
  late final TextEditingController _beratTotal = TextEditingController(
    text: widget.previewUnderSold
        ? '100'
        : labelBeratKg(widget.item.beratTotal),
  );
  late final TextEditingController _beratReject = TextEditingController(
    text: widget.previewUnderSold ? '20' : labelBeratKg(widget.item.beratReject),
  );
  late final TextEditingController _keterangan = TextEditingController(
    text: widget.item.keterangan ?? '',
  );

  String? _beratError;
  late bool _showKonflik = widget.previewKonflik;

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
    _beratTotal.dispose();
    _beratReject.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  void _simpan() {
    final total = double.tryParse(_beratTotal.text.trim()) ?? 0;
    final reject = double.tryParse(_beratReject.text.trim()) ?? 0;
    final layak = total - reject;

    setState(() {
      _beratError = layak < widget.item.terjual
          ? 'Berat layak ${labelBeratKg(layak < 0 ? 0 : layak)} kg, '
                'sudah terjual ${labelBeratKg(widget.item.terjual)} kg'
          : null;
    });
    if (_beratError != null) return;

    final keterangan = _keterangan.text.trim();
    Navigator.of(context).pop(
      widget.item.copyWith(
        beratTotal: total,
        beratReject: reject,
        keterangan: keterangan.isEmpty ? null : keterangan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          V2TextField(
                            label: 'Berat total (kg)',
                            hint: '0',
                            controller: _beratTotal,
                            error: _beratError,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: V2Space.lg),
                          V2TextField(
                            label: 'Berat reject (kg)',
                            hint: '0',
                            controller: _beratReject,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: V2Space.lg),
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
              body: 'Data ini baru diubah di perangkat lain. Muat ulang untuk '
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