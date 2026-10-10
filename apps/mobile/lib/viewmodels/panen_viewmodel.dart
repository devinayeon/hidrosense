import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/business_date.dart';
import '../core/uuid.dart';
import '../data/models/harvest_draft.dart';
import '../data/models/harvest_record.dart';
import '../data/models/transfer_record.dart';
import '../data/repositories/harvest_repository.dart';
import '../data/services/api_client.dart';
import 'connected_table_viewmodel.dart';
import 'damage_viewmodel.dart' show growthClockProvider;
import 'session_viewmodel.dart';

enum PanenFilterCategory { all, upcoming, completed }

enum HarvestSubmitResult { saved, savedRefreshFailed, failed, busy }

class HarvestReadState {
  const HarvestReadState({this.record, this.loading = false, this.error});
  final HarvestRecord? record;
  final bool loading;
  final String? error;
}

class PanenState {
  const PanenState({
    this.records = const [],
    this.transfers = const [],
    this.loading = false,
    this.submitting = false,
    this.error,
    this.refreshWarning,
    this.conflictId,
    this.detailReads = const {},
  });
  final Map<String, HarvestReadState> detailReads;
  final List<HarvestRecord> records;
  final List<TransferRecord> transfers;
  final bool loading, submitting;
  final String? error, refreshWarning, conflictId;
  List<TransferRecord> get upcoming =>
      transfers.where((t) => t.activePlants > 0).toList();
}

class HarvestCommand {
  HarvestCommand(this.target, this.body, {this.draft, this.correction})
    : key = generateUuidV4();
  final String target, key;
  final Map<String, dynamic> body;
  final HarvestDraft? draft;
  final HarvestCorrection? correction;
  bool uncertain = false, running = false;
  HarvestRecord? receipt;
}

class HarvestCommands {
  final pending = <(String, String), HarvestCommand>{};
  final receipts = <(String, String), Map<String, HarvestRecord>>{};
}

final harvestCommandsProvider = Provider((ref) => HarvestCommands());
final harvestRepositoryProvider = Provider(
  (ref) => HarvestRepository(ref.watch(apiClientProvider)),
);
final panenFilterCategoryProvider = StateProvider.autoDispose(
  (ref) => PanenFilterCategory.all,
);

class PanenViewModel extends StateNotifier<PanenState> {
  PanenViewModel(
    this.repository,
    this.refreshTables, {
    required this.canWrite,
    required this.canReadBatches,
    required String userId,
    HarvestCommands? commands,
    DateTime Function()? clock,
    bool autoLoad = true,
  }) : _commands = commands ?? HarvestCommands(),
       _scope = (repository.serverOrigin, userId),
       _clock = clock ?? DateTime.now,
       super(const PanenState()) {
    if (autoLoad) refresh();
  }
  final HarvestRepository repository;
  final Future<void> Function(Set<String>) refreshTables;
  final bool canWrite, canReadBatches;
  final HarvestCommands _commands;
  final (String, String) _scope;
  final DateTime Function() _clock;
  int _generation = 0;
  final _detailLoads = <String, int>{};
  PanenState get current => state;
  DateTime get today => jakartaToday(_clock());
  HarvestCommand? get pendingCommand => _commands.pending[_scope];
  bool get payloadLocked =>
      pendingCommand?.uncertain == true || pendingCommand?.running == true;
  HarvestDraft? get pendingDraft =>
      payloadLocked ? pendingCommand?.draft : null;
  HarvestCorrection? get pendingCorrection =>
      payloadLocked ? pendingCommand?.correction : null;
  Map<String, HarvestRecord> get _receipts =>
      _commands.receipts.putIfAbsent(_scope, () => {});
  void beginDraft() {
    final c = pendingCommand;
    if (c?.receipt != null && c?.running != true) {
      _commands.pending.remove(_scope);
    }
  }

  void _set({
    List<HarvestRecord>? records,
    List<TransferRecord>? transfers,
    bool loading = false,
    bool? submitting,
    String? error,
    String? warning,
    String? conflictId,
    Map<String, HarvestReadState>? detailReads,
  }) {
    if (!mounted) return;
    state = PanenState(
      records: records ?? state.records,
      transfers: transfers ?? state.transfers,
      loading: loading,
      submitting: submitting ?? state.submitting,
      error: error,
      refreshWarning: warning,
      conflictId: conflictId ?? state.conflictId,
      detailReads: detailReads ?? state.detailReads,
    );
  }

  List<HarvestRecord> _merge(List<HarvestRecord> rows) {
    final records = {for (final row in rows) row.id: row};
    for (final receipt in _receipts.values) {
      final read = records[receipt.id];
      if (read?.version == null ||
          BigInt.parse(read!.version!) <= BigInt.parse(receipt.version!)) {
        records[receipt.id] = receipt;
      }
    }
    final result = records.values.toList()
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date == 0
            ? BigInt.parse(b.id).compareTo(BigInt.parse(a.id))
            : date;
      });
    return List.unmodifiable(result);
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_generation;
    _set(loading: true, warning: state.refreshWarning);
    try {
      final loaded = await Future.wait<Object>([
        repository.listHarvests(),
        canReadBatches
            ? repository.listTransfers()
            : Future.value(<TransferRecord>[]),
      ]);
      final records = loaded[0] as List<HarvestRecord>;
      final transfers = loaded[1] as List<TransferRecord>;
      if (mounted && generation == _generation) {
        _set(records: _merge(records), transfers: transfers);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        final denied = e is ApiException && [401, 403].contains(e.status);
        _set(
          records: denied ? [] : null,
          transfers: denied ? [] : null,
          error: serviceError(e),
          warning: state.refreshWarning,
        );
      }
    }
  }

  Future<HarvestReadState?> loadDetail(String id) async {
    if (!mounted) return null;
    final operation = (_detailLoads[id] ?? 0) + 1;
    _detailLoads[id] = operation;
    _set(
      detailReads: {
        ...state.detailReads,
        id: const HarvestReadState(loading: true),
      },
    );
    try {
      final record = await repository.getHarvest(id);
      if (mounted && _detailLoads[id] == operation) {
        final records = _merge([
          record,
          ...state.records.where((r) => r.id != id),
        ]);
        final result = HarvestReadState(
          record: records.firstWhere((r) => r.id == id),
        );
        _set(records: records, detailReads: {...state.detailReads, id: result});
        return result;
      }
    } catch (e) {
      if (mounted && _detailLoads[id] == operation) {
        if (e is ApiException && e.status == 404) {
          _receipts.remove(id);
          if (pendingCommand?.receipt?.id == id &&
              pendingCommand?.running != true) {
            _commands.pending.remove(_scope);
          }
        }
        final result = HarvestReadState(error: serviceError(e));
        _set(
          records: e is ApiException && [403, 404].contains(e.status)
              ? state.records.where((r) => r.id != id).toList()
              : null,
          detailReads: {...state.detailReads, id: result},
          error: result.error,
        );
        return result;
      }
    }
    return null;
  }

  HarvestSubmitResult _fail(String message) {
    _set(error: message, submitting: false);
    return HarvestSubmitResult.failed;
  }

  String? validateDraft(HarvestDraft draft) {
    try {
      harvestDate(draft.date);
      if (draft.rows.isEmpty ||
          draft.rows.length > 100 ||
          draft.rows.map((r) => r.transferId).toSet().length !=
              draft.rows.length ||
          (draft.note?.trim().length ?? 0) > 1000 ||
          DateTime.parse(draft.date).isAfter(today)) {
        return 'Periksa tanggal, catatan, dan pilih 1 sampai 100 batch berbeda.';
      }
      for (final row in draft.rows) {
        final batch = state.transfers
            .where((t) => t.id == row.transferId)
            .firstOrNull;
        final total = HarvestWeight.parse(row.total, ui: true),
            reject = HarvestWeight.parse(row.reject, ui: true);
        if (batch == null ||
            row.plantCount < 1 ||
            row.plantCount > 1000000 ||
            row.plantCount > batch.activePlants ||
            DateTime.parse(
              draft.date,
            ).isBefore(DateTime.parse(batch.transferDate)) ||
            total.minor <= BigInt.zero ||
            reject.minor > total.minor) {
          return 'Periksa jumlah tanaman, tanggal batch, dan berat sortasi.';
        }
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  Future<HarvestSubmitResult> submit(HarvestDraft draft) {
    if (!mounted || pendingCommand?.running == true || state.submitting) {
      return Future.value(HarvestSubmitResult.busy);
    }
    if (!canReadBatches) {
      return Future.value(_fail('Akses batch budidaya diperlukan.'));
    }
    if (!payloadLocked && pendingCommand?.receipt == null) {
      final error = validateDraft(draft);
      if (error != null) return Future.value(_fail(error));
    }
    try {
      return _save('create', draft.toJson(), draft: draft);
    } on FormatException catch (e) {
      return Future.value(_fail(e.message));
    }
  }

  void acknowledgeConflict(String id) {
    if (!mounted || state.conflictId != id) return;
    state = PanenState(
      records: state.records,
      transfers: state.transfers,
      detailReads: state.detailReads,
    );
  }

  Future<HarvestSubmitResult> correct(HarvestCorrection correction) {
    if (!mounted || pendingCommand?.running == true || state.submitting) {
      return Future.value(HarvestSubmitResult.busy);
    }
    if (state.conflictId == correction.id) {
      return Future.value(
        _fail('Tinjau data terbaru sebelum menyimpan koreksi.'),
      );
    }
    try {
      harvestId(correction.id);
      harvestId(correction.expectedVersion);
      final record = state.records
          .where((r) => r.id == correction.id)
          .firstOrNull;
      if (record == null ||
          (correction.note?.trim().length ?? 0) > 1000 ||
          (correction.rows != null &&
              (correction.rows!.isEmpty ||
                  correction.rows!.length > 100 ||
                  correction.rows!.map((r) => r.detailId).toSet().length !=
                      correction.rows!.length))) {
        return Future.value(_fail('Periksa data koreksi panen.'));
      }
      for (final row in correction.rows ?? <HarvestCorrectionRow>[]) {
        final total = HarvestWeight.parse(row.total, ui: true),
            reject = HarvestWeight.parse(row.reject, ui: true);
        if (!record.details.any((d) => d.id == row.detailId) ||
            total.minor <= BigInt.zero ||
            reject.minor > total.minor) {
          return Future.value(
            _fail('Periksa berat total dan reject untuk setiap rincian.'),
          );
        }
      }
      return _save(correction.id, correction.toJson(), correction: correction);
    } on FormatException catch (e) {
      return Future.value(_fail(e.message));
    }
  }

  Future<HarvestSubmitResult> retryPending() {
    final c = pendingCommand;
    if (c == null) {
      return Future.value(_fail('Tidak ada request yang perlu diulang.'));
    }
    return _save(c.target, c.body, draft: c.draft, correction: c.correction);
  }

  Future<HarvestSubmitResult> _save(
    String target,
    Map<String, dynamic> body, {
    HarvestDraft? draft,
    HarvestCorrection? correction,
  }) async {
    if (!mounted || pendingCommand?.running == true || state.submitting) {
      return HarvestSubmitResult.busy;
    }
    if (!canWrite) return _fail('Akses pencatatan panen tidak diizinkan.');
    var command = pendingCommand;
    if (command?.uncertain == true &&
        (command!.target != target ||
            jsonEncode(command.body) != jsonEncode(body))) {
      return _fail(
        'Hasil belum pasti. Selesaikan request sebelumnya dengan isian yang sama.',
      );
    }
    if (command == null ||
        command.target != target ||
        jsonEncode(command.body) != jsonEncode(body)) {
      command = HarvestCommand(
        target,
        jsonDecode(jsonEncode(body)),
        draft: draft,
        correction: correction,
      );
      _commands.pending[_scope] = command;
    }
    command.running = true;
    ++_generation;
    _set(submitting: true);
    try {
      if (command.receipt == null) {
        command.uncertain = true;
        final receipt = await repository.write(
          command.target,
          command.body,
          command.key,
        );
        command.receipt = receipt;
        final previous = _receipts[receipt.id];
        if (previous == null ||
            BigInt.parse(previous.version!) < BigInt.parse(receipt.version!)) {
          _receipts[receipt.id] = receipt;
        }
        command.uncertain = false;
      }
      if (!mounted) return HarvestSubmitResult.saved;
      final receipt = command.receipt!;
      _detailLoads[receipt.id] = (_detailLoads[receipt.id] ?? 0) + 1;
      final merged = _merge(state.records);
      _set(
        records: merged,
        detailReads: {
          ...state.detailReads,
          receipt.id: HarvestReadState(
            record: merged.firstWhere((r) => r.id == receipt.id),
          ),
        },
      );
      await refresh();
      if (!mounted) return HarvestSubmitResult.saved;
      String? warning = state.error;
      try {
        await refreshTables(
          command.receipt!.details.map((d) => d.tableId).toSet(),
        );
      } catch (e) {
        warning ??= serviceError(e);
      }
      if (!mounted) return HarvestSubmitResult.saved;
      _set(
        records: _merge(state.records),
        warning: warning == null
            ? null
            : 'Tersimpan. Data terbaru belum dapat dimuat: $warning',
      );
      return warning == null
          ? HarvestSubmitResult.saved
          : HarvestSubmitResult.savedRefreshFailed;
    } catch (e) {
      command.uncertain =
          e is! ApiException ||
          e.status == 0 ||
          e.status >= 500 ||
          e.code == 'SESSION_CHANGED';
      if (!command.uncertain) _commands.pending.remove(_scope);
      if (e is ApiException && e.status == 409) {
        await refresh();
        if (mounted && e.code == 'HARVEST_VERSION_CONFLICT') {
          _set(conflictId: target);
        }
      }
      return _fail(serviceError(e));
    } finally {
      command.running = false;
      if (mounted) {
        _set(
          submitting: false,
          error: state.error,
          warning: state.refreshWarning,
        );
      }
    }
  }
}

final panenViewModelProvider =
    StateNotifierProvider.autoDispose<PanenViewModel, PanenState>((ref) {
      final user = ref.watch(sessionProvider.select((s) => s.user));
      if (user == null || !user.permissions.contains('panen:read')) {
        throw StateError('Akses panen diperlukan.');
      }
      final clock = ref.watch(growthClockProvider);
      final vm = PanenViewModel(
        ref.watch(harvestRepositoryProvider),
        (ids) async {
          final tables = ref.read(connectedTableProvider.notifier);
          Object? failure;
          for (final id in ids) {
            try {
              await tables.refreshTable(id);
            } catch (error) {
              failure ??= error;
            }
          }
          if (failure != null) throw failure;
        },
        canWrite: user.permissions.contains('panen:write'),
        canReadBatches: user.permissions.contains('budidaya:read'),
        userId: user.id,
        commands: ref.watch(harvestCommandsProvider),
        clock: clock,
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
