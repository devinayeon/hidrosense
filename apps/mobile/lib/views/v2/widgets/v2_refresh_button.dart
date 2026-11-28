import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';
import 'v2_icon_button.dart';

/// Tombol "Muat ulang" untuk daftar yang menarik data dari backend.
///
/// Selama [onRefresh] berjalan tombol berganti spinner dan tidak bisa ditekan
/// lagi, supaya satu ketukan tidak memicu beberapa permintaan. Null berarti
/// tidak ada tombol (halaman galeri tetap seperti semula).
class V2RefreshButton extends StatefulWidget {
  const V2RefreshButton({
    super.key,
    required this.onRefresh,
    this.semanticLabel = 'Muat ulang',
  });

  final Future<void> Function()? onRefresh;
  final String semanticLabel;

  @override
  State<V2RefreshButton> createState() => _V2RefreshButtonState();
}

class _V2RefreshButtonState extends State<V2RefreshButton> {
  bool _busy = false;

  Future<void> _run() async {
    final refresh = widget.onRefresh;
    if (refresh == null || _busy) return;
    setState(() => _busy = true);
    try {
      await refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onRefresh == null) return const SizedBox.shrink();
    if (_busy) {
      return Semantics(
        label: widget.semanticLabel,
        enabled: false,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: V2Colors.blue500,
              ),
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: widget.semanticLabel,
      child: V2IconButton(
        icon: V2IconName.refresh,
        semanticLabel: widget.semanticLabel,
        onPressed: _run,
      ),
    );
  }
}
