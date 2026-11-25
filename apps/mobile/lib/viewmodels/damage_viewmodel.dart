import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/business_date.dart';
export '../core/business_date.dart' show jakartaToday, apiDate;
import '../core/formatting.dart';
import '../core/uuid.dart';
import '../data/models/damage_record.dart';
import '../data/models/transfer_record.dart';
import '../data/repositories/damage_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/write_outcome.dart';
import 'connected_table_viewmodel.dart';
import 'damage_queue_sink.dart';
import 'session_viewmodel.dart';
import 'v2_damage_sender.dart';
import 'v2_sync_queue.dart';

class DamageState {
  const DamageState({
    this.transfers = const [],
    this.reports = const {},
    this.loading = false,
    this.submitting = false,
    this.error,
    this.refreshWarning,
    this.uncertainDraft,
  });
  final List<TransferRecord> transfers;
  final Map<String, List<DamageRecord>> reports;
  final bool loading, submitting;
  final String? error, refreshWarning;
  final DamageDraft? uncertainDraft;
}

enum DamageSubmitResult { saved, savedRefreshFailed, failed, busy }

class DamageCommand {
  DamageCommand(this.target, this.payload, this.draft) : key = generateUuidV4();
  final String target, payload, key;
  final DamageDraft? draft;
  bool uncertain = false, running = false;
  DamageRecord? damage;
  TransferRecord? transfer;
  bool get saved => damage != null || transfer != null;
}

final damageCommandsProvider = Provider(
  (ref) => <(String, String, String), DamageCommand>{},
);
final growthClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class DamageViewModel extends StateNotifier<DamageState> {
  DamageViewModel(
    this._repository,
    this.tableId,
    this._refreshTable, {
    required this.canWrite,
    this.autoLoad = true,
    String userId = '',
    Map<(String, String, String), DamageCommand>? commands,
    DateTime Function()? clock,
    this.queueSink,
  }) : _commands = commands ?? {},
       _scope = (_repository.serverOrigin, userId, tableId),
       _clock = clock ?? DateTime.now,
       super(const DamageState()) {
    if (autoLoad) refresh();
  }
  final DamageRepository _repository;
  final String tableId;
  final Future<void> Function() _refreshTable;
  final bool canWrite, autoLoad;
  final DamageQueueSink? queueSink;
  final Map<(String, String, String), DamageCommand> _commands;
  final (String, String, String) _scope;
  final DateTime Function() _clock;
  int _load = 0;
  DamageCommand? get _command => _commands[_scope];
  DamageState get current => state;
  DamageDraft? get pendingDraft => payloadLocked ? _command?.draft : null;
  bool get payloadLocked => _command?.uncertain ?? false;
  String? get pendingTarget => payloadLocked ? _command?.target : null;
  String? get pendingNote => pendingTarget?.startsWith('batch:') == true
      ? (jsonDecode(_command!.payload) as Map)['keterangan'] as String?
      : null;

  void beginDraft() {
    if (_command?.saved == true && _command?.running != true) {
      _commands.remove(_scope);
    }
  }

  void _set({
    bool loading = false,
    bool submitting = false,
    String? error,
    String? warning,
    List<TransferRecord>? transfers,
    Map<String, List<DamageRecord>>? reports,
  }) {
    if (!mounted) return;
    state = DamageState(
      transfers: transfers ?? state.transfers,
      reports: reports ?? state.reports,
      loading: loading,
      submitting: submitting,
      error: error,
      refreshWarning: warning,
      uncertainDraft: payloadLocked ? _command?.draft : null,
    );
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final operation = ++_load;
    _set(loading: true, submitting: state.submitting);
    try {
      final transfers = await _repository.listTransfers(tableId);
      final reports = <String, List<DamageRecord>>{};
      for (final transfer in transfers) {
        if (!mounted || operation != _load) return;
        reports[transfer.id] = await _repository.listDamages(transfer.id);
      }
      if (mounted && operation == _load) {
        _set(
          transfers: transfers,
          reports: Map.unmodifiable(reports),
          submitting: state.submitting,
        );
      }
    } catch (error) {
      if (mounted && operation == _load) {
        final denied =
            error is ApiException && [401, 403].contains(error.status);
        _set(
          error: serviceError(error),
          submitting: state.submitting,
          transfers: denied ? [] : null,
          reports: denied ? {} : null,
        );
      }
    }
  }

  DamageSubmitResult _fail(String error) {
    _set(error: error);
    return DamageSubmitResult.failed;
  }

  void _merge(DamageCommand command) {
    ++_load;
    if (command.transfer case final record?) {
      final current = state.transfers
          .where((r) => r.id == record.id)
          .firstOrNull;
      if (current?.version != null &&
          record.version != null &&
          BigInt.parse(current!.version!) >= BigInt.parse(record.version!)) {
        return;
      }
      _set(
        transfers: List.unmodifiable(
          state.transfers.map((r) => r.id == record.id ? record : r),
        ),
        submitting: true,
      );
    }
    if (command.damage case final record?) {
      final current = state.reports[record.transferId]
          ?.where((r) => r.id == record.id)
          .firstOrNull;
      if (current?.version != null &&
          record.version != null &&
          BigInt.parse(current!.version!) >= BigInt.parse(record.version!)) {
        return;
      }
      final reports = {...state.reports};
      reports[record.transferId] = List.unmodifiable([
        record,
        ...?reports[record.transferId]?.where((r) => r.id != record.id),
      ]);
      _set(reports: Map.unmodifiable(reports), submitting: true);
    }
  }

  Future<DamageSubmitResult> _save(
    String target,
    Map<String, dynamic> body,
    DamageDraft? draft,
    Future<void> Function(DamageCommand) write,
  ) async {
    if (!mounted || state.submitting || _command?.running == true) {
      return DamageSubmitResult.busy;
    }
    if (!canWrite) return _fail('Akses pembaruan budidaya tidak diizinkan.');
    final payload = jsonEncode(body);
    var command = _command;
    if (command != null &&
        command.uncertain &&
        (command.target != target || command.payload != payload)) {
      return _fail(
        'Hasil belum pasti. Ulangi request sebelumnya dengan isian yang sama.',
      );
    }
    if (command == null ||
        command.target != target ||
        command.payload != payload) {
      command = DamageCommand(target, payload, draft);
      _commands[_scope] = command;
    }
    final wasUncertain = command.uncertain;
    command.running = true;
    ++_load;
    _set(submitting: true);
    try {
      if (!command.saved) {
        command.uncertain = true;
        await write(command);
        command.uncertain = false;
        await _settleQueue(command.key);
      }
      if (!mounted) return DamageSubmitResult.saved;
      _merge(command);
      await refresh();
      if (!mounted) return DamageSubmitResult.saved;
      String? warning = state.error;
      try {
        await _refreshTable();
      } catch (error) {
        warning ??= serviceError(error);
      }
      if (!mounted) return DamageSubmitResult.saved;
      _merge(command);
      _set(
        warning: warning == null
            ? null
            : 'Tersimpan. Data terbaru belum dapat dimuat: $warning',
      );
      return warning == null
          ? DamageSubmitResult.saved
          : DamageSubmitResult.savedRefreshFailed;
    } catch (error) {
      command.uncertain = writeStaysUncertain(
        error,
        wasUncertain: wasUncertain,
      );
      if (!command.uncertain) _commands.remove(_scope);
      if (command.uncertain) {
        await _record(command, target, body);
      } else {
        await _failQueue(command.key, serviceError(error));
      }
      if (error is ApiException &&
          [
            'DAMAGE_EXCEEDS_ACTIVE',
            'DAMAGE_RESTORE_EXCEEDS_TABLE_CAPACITY',
          ].contains(error.code)) {
        await refresh();
        try {
          await _refreshTable();
        } catch (_) {}
      }
      return _fail(serviceError(error));
    } finally {
      command.running = false;
      if (mounted && state.submitting) {
        _set(error: state.error, warning: state.refreshWarning);
      }
    }
  }

  /// Subjudul baris antrean: tanggal laporan, catatan batch, atau koreksi.
  String _queueSubtitle(String queueTarget, Map<String, dynamic> body) {
    if (queueTarget == damageCreateTarget) {
      final date = DateTime.tryParse('${body['tanggal_kejadian'] ?? ''}');
      return date == null
          ? 'Rusak tanaman'
          : 'Rusak ${formatTanggalIndo(date, singkat: true)}';
    }
    if (queueTarget.startsWith(damageBatchPrefix)) {
      final id = queueTarget.substring(damageBatchPrefix.length);
      final batch = state.transfers.where((t) => t.id == id).firstOrNull;
      return batch == null ? 'Catatan batch #$id' : 'Catatan ${batch.label}';
    }
    return 'Koreksi kerusakan';
  }

  /// Target antrean yang stabil, terpisah dari nama target internal command.
  String _queueTarget(String target) => switch (target) {
    'create' => damageCreateTarget,
    _ when target.startsWith('damage:') =>
      '$damageUpdatePrefix${target.substring('damage:'.length)}',
    _ => target,
  };

  Future<void> _record(
    DamageCommand command,
    String target,
    Map<String, dynamic> body,
  ) async {
    final sink = queueSink;
    final queueTarget = _queueTarget(target);
    if (sink == null) return;
    try {
      await sink.record(
        key: command.key,
        target: queueTarget,
        body: body,
        subtitle: _queueSubtitle(queueTarget, body),
        createdAt: DateTime.now(),
      );
    } catch (_) {
      // Antrean HP bersifat cadangan; galat asli tetap yang dilaporkan.
    }
  }

  Future<void> _settleQueue(String key) async {
    try {
      await queueSink?.remove(key);
    } catch (_) {
      // Baris akan dilepas saat kiriman ulang berikutnya.
    }
  }

  Future<void> _failQueue(String key, String message) async {
    try {
      await queueSink?.fail(key, message);
    } catch (_) {
      // Status gagal akan ditandai lagi saat pengiriman ulang.
    }
  }

  Future<DamageSubmitResult> submit(DamageDraft draft) async {
    if (!mounted || state.submitting || _command?.running == true) {
      return DamageSubmitResult.busy;
    }
    if (!payloadLocked && _command?.saved != true) {
      final batch = state.transfers.where((t) => t.id == draft.transferId);
      final date = DateTime.tryParse(draft.date);
      if (batch.isEmpty ||
          date == null ||
          apiDate(date) != draft.date ||
          date.isBefore(DateTime.parse(batch.first.transferDate)) ||
          date.isAfter(jakartaToday(_clock())) ||
          draft.plantCount <= 0 ||
          draft.plantCount > batch.first.activePlants ||
          draft.category.trim().isEmpty ||
          draft.category.trim().length > 100 ||
          (draft.note?.trim().length ?? 0) > 1000) {
        return Future.value(
          _fail('Periksa batch, tanggal, jumlah tanaman, dan keterangan.'),
        );
      }
    }
    return _save('create', draft.toJson(), draft, (c) async {
      c.damage = await _repository.createDamage(draft, c.key);
    });
  }

  Future<DamageSubmitResult> updateTransfer(String id, {String? note}) => _save(
    'batch:$id',
    {'keterangan': note?.trim().isNotEmpty == true ? note!.trim() : null},
    null,
    (c) async {
      c.transfer = await _repository.updateTransfer(
        id,
        note: note,
        idempotencyKey: c.key,
      );
    },
  );
  Future<DamageSubmitResult> updateDamage(
    String id, {
    String? date,
    int? plantCount,
    String? category,
    String? note,
  }) {
    final records = state.reports.values
        .expand((r) => r)
        .where((r) => r.id == id);
    final record = records.isEmpty ? null : records.first;
    final draft = record == null
        ? null
        : DamageDraft(
            transferId: record.transferId,
            date: date ?? record.date,
            plantCount: plantCount ?? record.plantCount,
            category: category ?? record.category,
            note: note,
          );
    return _save(
      'damage:$id',
      {
        'tanggal_kejadian': ?date,
        'jumlah_tanaman': ?plantCount,
        if (category != null) 'jenis_kerusakan': category.trim(),
        'keterangan': note?.trim().isNotEmpty == true ? note!.trim() : null,
      },
      draft,
      (c) async {
        c.damage = await _repository.updateDamage(
          id,
          date: date,
          plantCount: plantCount,
          category: category,
          note: note,
          idempotencyKey: c.key,
        );
      },
    );
  }
}

final damageRepositoryProvider = Provider(
  (ref) => DamageRepository(ref.watch(apiClientProvider)),
);
final damageProvider = StateNotifierProvider.autoDispose
    .family<DamageViewModel, DamageState, String>((ref, tableId) {
      final user = ref.watch(sessionProvider.select((s) => s.user));
      if (user == null || !user.permissions.contains('budidaya:read')) {
        throw StateError('Laporan kerusakan memerlukan akses budidaya.');
      }
      final clock = ref.watch(growthClockProvider);
      final vm = DamageViewModel(
        ref.watch(damageRepositoryProvider),
        tableId,
        () => ref.read(connectedTableProvider.notifier).refreshTable(tableId),
        canWrite: user.permissions.contains('budidaya:write'),
        userId: user.id,
        commands: ref.watch(damageCommandsProvider),
        clock: clock,
        queueSink: V2DamageQueueSink(ref.watch(v2SyncQueueProvider.notifier)),
      );
      Timer? timer;
      void schedule() {
        timer?.cancel();
        timer = Timer(untilJakartaMidnight(clock()), () {
          vm.refresh();
          schedule();
        });
      }

      schedule();
      final listener = AppLifecycleListener(
        onResume: () {
          vm.refresh();
          schedule();
        },
      );
      ref.onDispose(() {
        timer?.cancel();
        listener.dispose();
      });
      return vm;
    });
