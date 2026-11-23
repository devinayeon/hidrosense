import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../viewmodels/connected_table_viewmodel.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../../../views/v2/theme/v2_tokens.dart';
import '../../../../views/v2/widgets/v2_banner.dart';
import '../../../../views/v2/widgets/v2_button.dart';
import '../../../../views/v2/widgets/v2_card.dart';
import '../../domain/pest_summary.dart';
import '../viewmodels/pest_scan_viewmodel.dart';
import '../widgets/decision_sheets.dart';
import 'rotation_history_page.dart';

/// Foto tanaman → deteksi hama di perangkat → saran rotasi obat per hama.
///
/// Analisis berjalan offline. Foto baru diunggah setelah pengguna menekan Simpan.
class PestScanPage extends ConsumerStatefulWidget {
  const PestScanPage({super.key, this.pickPhoto});

  /// Diganti di tes; bawaannya kamera atau galeri lewat image_picker.
  final Future<Uint8List?> Function(ImageSource source)? pickPhoto;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const PestScanPage());

  @override
  ConsumerState<PestScanPage> createState() => _PestScanPageState();
}

class _PestScanPageState extends ConsumerState<PestScanPage> {
  String? _tableId;
  String? _pickError;

  Future<Uint8List?> _pick(ImageSource source) async {
    final custom = widget.pickPhoto;
    if (custom != null) return custom(source);
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    return file?.readAsBytes();
  }

  Future<void> _capture(ImageSource source) async {
    setState(() => _pickError = null);
    try {
      final bytes = await _pick(source);
      if (bytes == null || !mounted) return;
      await ref.read(pestScanProvider.notifier).analyze(bytes);
    } on PlatformException {
      if (mounted) setState(() => _pickError = 'Akses kamera atau galeri ditolak. Izinkan lewat pengaturan perangkat.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final allowed = user?.permissions.contains('deteksi:write') ?? false;
    final state = ref.watch(pestScanProvider);
    final notifier = ref.read(pestScanProvider.notifier);
    final tables = ref.watch(connectedTableProvider).records.where((t) => !t.isInactive && t.activePlants > 0).toList();
    final busy = state.phase == ScanPhase.analyzing || state.phase == ScanPhase.saving;
    final tableId = state.tableId ?? _tableId;
    void save() => notifier.save(tableId: tableId!);

    return Scaffold(
      backgroundColor: V2Colors.canvas,
      appBar: AppBar(
        title: const Text('Foto tanaman'),
        actions: [
          IconButton(
            tooltip: 'Riwayat rotasi obat',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(RotationHistoryPage.route()),
          ),
        ],
      ),
      body: !allowed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(V2Space.xl),
                child: Text('Fitur ini hanya untuk akun petani.', style: V2Type.body, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(V2Space.lg),
              children: [
                const V2Banner(
                  message: 'Deteksi berjalan di HP dan hanya saran. Anda yang memutuskan.',
                  tone: V2BannerTone.ai,
                ),
                const SizedBox(height: V2Space.lg),
                DropdownButtonFormField<String>(
                  initialValue: tables.any((t) => t.id == tableId) ? tableId : null,
                  decoration: const InputDecoration(labelText: 'Meja tanam'),
                  items: [for (final t in tables) DropdownMenuItem(value: t.id, child: Text(t.code))],
                  // Terkunci sejak simpan dimulai: foto sudah terikat ke batch meja itu.
                  onChanged: busy || state.saveStarted ? null : (value) => setState(() => _tableId = value),
                ),
                const SizedBox(height: V2Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: V2Button(
                        label: 'Kamera',
                        state: busy ? V2ButtonState.disabled : V2ButtonState.normal,
                        onPressed: () => _capture(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: V2Space.md),
                    Expanded(
                      child: V2Button(
                        label: 'Galeri',
                        type: V2ButtonType.secondary,
                        state: busy ? V2ButtonState.disabled : V2ButtonState.normal,
                        onPressed: () => _capture(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                if (_pickError != null) _ErrorText(_pickError!),
                if (state.photo != null) ...[
                  const SizedBox(height: V2Space.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(V2Radius.iconBox),
                    child: Image.memory(
                      state.photo!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: 'Foto tanaman yang dianalisis',
                    ),
                  ),
                ],
                if (state.phase == ScanPhase.analyzing) ...[
                  const SizedBox(height: V2Space.lg),
                  const Center(child: CircularProgressIndicator(semanticsLabel: 'Menganalisis foto')),
                  const SizedBox(height: V2Space.sm),
                  const Center(child: Text('Menganalisis foto…', style: V2Type.caption)),
                ],
                if (state.error != null) _ErrorText(state.error!),
                if (state.canRetrySave) ...[
                  const SizedBox(height: V2Space.md),
                  V2Button(label: 'Coba simpan lagi', onPressed: save),
                ],
                if (state.result != null && state.phase != ScanPhase.analyzing) ..._result(state, notifier, busy, tableId, save),
              ],
            ),
    );
  }

  List<Widget> _result(PestScanState state, PestScanNotifier notifier, bool busy, String? tableId, VoidCallback save) {
    final result = state.result!;
    return [
      const SizedBox(height: V2Space.lg),
      if (result.isEmpty)
        const V2Card(
          title: 'Tidak ada hama terdeteksi',
          body: 'Ini bukan jaminan tanaman sehat. Periksa sisi bawah daun dan pucuk, lalu foto ulang bila ragu.',
        )
      else
        for (final f in result.findings) ...[
          V2Card(
            padding: const EdgeInsets.all(V2Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.kind.label}: ${f.count} terdeteksi', style: V2Type.h2),
                Text('Keyakinan tertinggi ${(f.maxConfidence * 100).round()}%', style: V2Type.caption),
                const SizedBox(height: V2Space.md),
                const Text('Tingkat serangan', style: V2Type.label),
                const SizedBox(height: V2Space.xs),
                SegmentedButton<PestSeverity>(
                  segments: [for (final s in PestSeverity.values) ButtonSegment(value: s, label: Text(s.label))],
                  selected: {state.severities[f.kind] ?? f.suggestedSeverity},
                  onSelectionChanged: state.canEditSeverity && !busy
                      ? (value) => notifier.setSeverity(f.kind, value.first)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: V2Space.md),
        ],
      if (state.phase == ScanPhase.analyzed || state.phase == ScanPhase.saving) ...[
        V2Button(
          label: result.isEmpty ? 'Simpan foto' : 'Simpan dan minta saran obat',
          expand: true,
          state: tableId == null
              ? V2ButtonState.disabled
              : busy
              ? V2ButtonState.loading
              : V2ButtonState.normal,
          onPressed: tableId == null || busy ? null : save,
        ),
        if (tableId == null)
          const Padding(
            padding: EdgeInsets.only(top: V2Space.sm),
            child: Text('Pilih meja tanam dulu.', style: V2Type.caption),
          ),
      ],
      for (final rec in state.recommendations) ...[
        const SizedBox(height: V2Space.lg),
        DecidableRecommendationCard(
          key: ValueKey(rec.id),
          recommendation: rec,
          onAccept: notifier.accept,
          onReject: notifier.reject,
          stock: stockOptions(ref),
        ),
      ],
    ];
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: V2Space.md),
    child: Text(message, style: V2Type.body.copyWith(color: V2Colors.red700)),
  );
}
