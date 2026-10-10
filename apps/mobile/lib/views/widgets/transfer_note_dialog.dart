import 'package:flutter/material.dart';
import '../../data/models/transfer_record.dart';
import '../../viewmodels/damage_viewmodel.dart';
import '../theme/app_theme.dart';

class TransferNoteDialog extends StatefulWidget {
  const TransferNoteDialog({
    super.key,
    required this.notifier,
    required this.transfer,
    required this.onSaved,
  });
  final DamageViewModel notifier;
  final TransferRecord transfer;
  final ValueChanged<String?> onSaved;

  @override
  State<TransferNoteDialog> createState() => _TransferNoteDialogState();
}

class _TransferNoteDialogState extends State<TransferNoteDialog> {
  late final TextEditingController _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final vm = widget.notifier;
    _controller = TextEditingController(
      text: vm.pendingTarget == 'batch:${widget.transfer.id}'
          ? vm.pendingNote ?? ''
          : widget.transfer.note ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = widget.notifier;
    if (_busy || !vm.mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await vm.updateTransfer(
      widget.transfer.id,
      note: _controller.text,
    );
    if (!mounted) return;
    if (!vm.mounted) {
      Navigator.pop(context);
      return;
    }
    if (result == DamageSubmitResult.saved ||
        result == DamageSubmitResult.savedRefreshFailed) {
      Navigator.pop(context);
      widget.onSaved(vm.current.refreshWarning);
    } else {
      setState(() {
        _busy = false;
        _error = vm.current.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Catatan Batch #${widget.transfer.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              enabled: !_busy && !widget.notifier.payloadLocked,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Catatan batch',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkNavy,
            foregroundColor: AppColors.accentLime,
            minimumSize: const Size(44, 44),
          ),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    ),
  );
}
