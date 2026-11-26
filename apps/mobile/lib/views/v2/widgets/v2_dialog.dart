import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_button.dart';

/// Varian dialog: `Confirm` (aksi utama biru) dan `Destructive` (aksi utama
/// merah, dipakai konfirmasi nonaktifkan).
enum V2DialogType { confirm, destructive }

/// Dialog dari component set `Dialog` (Type=Confirm/Destructive).
class V2Dialog extends StatelessWidget {
  const V2Dialog({
    super.key,
    required this.title,
    this.body,
    this.type = V2DialogType.confirm,
    this.primaryLabel = 'Simpan',
    this.onPrimary,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.child,
  });

  final String title;
  final String? body;
  final V2DialogType type;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Tampilkan spinner di tombol utama selama proses berjalan.
  final bool primaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        boxShadow: V2Shadow.card,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: V2Type.h2),
            if (body != null) ...[
              const SizedBox(height: V2Space.lg),
              Text(body!, style: V2Type.body.copyWith(color: V2Colors.muted)),
            ],
            if (child != null) ...[const SizedBox(height: V2Space.lg), child!],
            const SizedBox(height: V2Space.lg),
            V2Button(
              label: primaryLabel,
              type: type == V2DialogType.destructive
                  ? V2ButtonType.destructive
                  : V2ButtonType.primary,
              onPressed: onPrimary,
              loading: primaryLoading,
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: secondaryLabel!,
                type: V2ButtonType.tertiary,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilkan [V2Dialog] sebagai modal dan kembalikan `true` bila aksi utama.
Future<bool?> showV2Dialog(
  BuildContext context, {
  required String title,
  String? body,
  V2DialogType type = V2DialogType.confirm,
  String primaryLabel = 'Simpan',
  String? secondaryLabel,
  Widget? child,
}) {
  return showDialog<bool>(
    context: context,
    // FigCraft menggambar Scrim `#111827` 60% dan menaruh dialog di tengah
    // frame penuh (3.3, 3.9, 3.13, 3.15, 11.8), bukan di tengah area aman.
    barrierColor: V2Colors.ink.withValues(alpha: 0.6),
    useSafeArea: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(V2Space.xl),
      child: V2Dialog(
        title: title,
        body: body,
        type: type,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        child: child,
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
      ),
    ),
  );
}

/// Tampilkan [V2Dialog] sebagai modal, jalankan [onConfirm] saat tombol utama
/// ditekan, dan kembalikan `true` hanya bila [onConfirm] selesai tanpa galat.
///
/// Selama [onConfirm] berjalan tombol utama menampilkan spinner, tombol batal
/// dan tombol kembali dimatikan, dan dialog tidak bisa ditutup lewat barrier.
/// Dialog baru menutup setelah proses selesai, jadi layar pemanggil tidak
/// kembali ke menu sebelumnya sebelum prosesnya beres. Galat dari [onConfirm]
/// dilempar ke pemanggil supaya bisa ditampilkan sebagai pesan di layar asal.
Future<bool> showV2ActionDialog(
  BuildContext context, {
  required String title,
  String? body,
  V2DialogType type = V2DialogType.confirm,
  String primaryLabel = 'Simpan',
  String secondaryLabel = 'Batal',
  Widget? child,
  required Future<void> Function() onConfirm,
}) async {
  final outcome = await showDialog<_V2ActionOutcome>(
    context: context,
    // Barrier mati supaya proses yang sedang berjalan tidak bisa ditinggalkan.
    barrierDismissible: false,
    barrierColor: V2Colors.ink.withValues(alpha: 0.6),
    useSafeArea: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(V2Space.xl),
      child: _V2ActionDialogBody(
        title: title,
        body: body,
        type: type,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        onConfirm: onConfirm,
        child: child,
      ),
    ),
  );
  final error = outcome?.error;
  if (error != null) throw error;
  return outcome?.done ?? false;
}

/// Hasil dialog aksi: selesai, dibatalkan, atau gagal membawa galatnya.
class _V2ActionOutcome {
  const _V2ActionOutcome.done()
    : done = true,
      error = null;
  const _V2ActionOutcome.cancelled()
    : done = false,
      error = null;
  const _V2ActionOutcome.failed(this.error) : done = false;

  final bool done;
  final Object? error;
}

class _V2ActionDialogBody extends StatefulWidget {
  const _V2ActionDialogBody({
    required this.title,
    required this.body,
    required this.type,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onConfirm,
    this.child,
  });

  final String title;
  final String? body;
  final V2DialogType type;
  final String primaryLabel;
  final String? secondaryLabel;
  final Widget? child;
  final Future<void> Function() onConfirm;

  @override
  State<_V2ActionDialogBody> createState() => _V2ActionDialogBodyState();
}

class _V2ActionDialogBodyState extends State<_V2ActionDialogBody> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(const _V2ActionOutcome.done());
    } catch (error) {
      if (mounted) Navigator.of(context).pop(_V2ActionOutcome.failed(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_running,
      child: V2Dialog(
        title: widget.title,
        body: widget.body,
        type: widget.type,
        primaryLabel: widget.primaryLabel,
        primaryLoading: _running,
        onPrimary: _running ? null : _run,
        secondaryLabel: widget.secondaryLabel,
        onSecondary: _running
            ? null
            : () => Navigator.of(context).pop(const _V2ActionOutcome.cancelled()),
        child: widget.child,
      ),
    );
  }
}
