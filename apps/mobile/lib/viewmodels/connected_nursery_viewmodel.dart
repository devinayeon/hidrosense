import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/business_date.dart';
import '../data/models/nursery_record.dart';
import '../data/models/transfer_record.dart';
import '../data/repositories/nursery_repository.dart';
import '../data/services/api_client.dart';
import 'session_viewmodel.dart';
import 'sowing_draft.dart';
import 'connected_inventory_viewmodel.dart';

final sowingCommandsProvider = Provider(
  (ref) => <(String, String), SowingCommand>{},
);
final nurseryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

typedef SeedlingTransferPayload = ({
  String idempotencyKey,
  String sowingId,
  String tableId,
  String transferDate,
  int plantCount,
  String note,
});

class SeedlingTransferCommand extends ChangeNotifier {
  SeedlingTransferCommand(this.payload);

  final SeedlingTransferPayload payload;
  bool submitting = false;
  bool saved = false;
  bool rejected = false;
  String? error;
  TransferRecord? receipt;

  void start() {
    submitting = true;
    error = null;
    notifyListeners();
  }

  void complete(TransferRecord receipt) {
    this.receipt = receipt;
    saved = true;
    submitting = false;
    notifyListeners();
  }

  void fail(Object failure, {required bool definitivelyRejected}) {
    error = serviceError(failure);
    submitting = false;
    rejected = definitivelyRejected;
    notifyListeners();
  }
}

final seedlingTransferCommandsProvider = Provider(
  (ref) => <(String, String, String), SeedlingTransferCommand>{},
);

class ConnectedNurseryState {
  const ConnectedNurseryState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.filterStatus,
    this.saving = false,
    this.pendingDraft,
    this.saveError,
  });

  final List<SowingRecord> records;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String? filterStatus;
  final bool saving;
  final SowingDraft? pendingDraft;
  final String? saveError;

  List<SowingRecord> get filteredRecords {
    return records.where((item) {
      final matchStatus = filterStatus == null || item.status == filterStatus;
      final matchQuery =
          item.batchName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (item.note != null &&
              item.note!.toLowerCase().contains(searchQuery.toLowerCase()));
      return matchStatus && matchQuery;
    }).toList();
  }

  ConnectedNurseryState copyWith({
    List<SowingRecord>? records,
    bool? loading,
    String? error,
    String? searchQuery,
    String? filterStatus,
    bool? saving,
    SowingDraft? pendingDraft,
    String? saveError,
    bool clearPending = false,
  }) {
    return ConnectedNurseryState(
      records: records ?? this.records,
      loading: loading ?? this.loading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      filterStatus: filterStatus ?? this.filterStatus,
      saving: saving ?? this.saving,
      pendingDraft: clearPending ? null : pendingDraft ?? this.pendingDraft,
      saveError: saveError,
    );
  }
}

class ConnectedNurseryViewModel extends StateNotifier<ConnectedNurseryState> {
  ConnectedNurseryViewModel(
    this._repository, {
    bool autoLoad = true,
    this.canWrite = true,
    String userId = '',
    Map<(String, String), SowingCommand>? commands,
    Future<String?> Function()? refreshInventory,
  }) : super(const ConnectedNurseryState()) {
    _scope = (_repository.serverOrigin, userId);
    _commands = commands ?? {};
    _refreshInventory = refreshInventory;
    if (_command != null) state = state.copyWith(pendingDraft: _command!.draft);
    if (autoLoad) refresh();
  }

  final NurseryRepository _repository;
  final bool canWrite;
  late final (String, String) _scope;
  late final Map<(String, String), SowingCommand> _commands;
  late final Future<String?> Function()? _refreshInventory;
  Future<void>? _refreshTask;
  SowingCommand? get _command => _commands[_scope];

  Future<TransferRecord> transferSowing({
    required String idempotencyKey,
    required String sowingId,
    required String tableId,
    required String transferDate,
    required int plantCount,
    String? note,
  }) async {
    if (!mounted || !canWrite) {
      throw StateError('Akses pemindahan bibit tidak diizinkan.');
    }
    return _repository.transferSowing(
      idempotencyKey: idempotencyKey,
      sowingId: sowingId,
      tableId: tableId,
      transferDate: transferDate,
      plantCount: plantCount,
      note: note,
    );
  }

  Future<void> submitTransfer(SeedlingTransferCommand command) async {
    if (!mounted || !canWrite) {
      throw StateError('Akses pemindahan bibit tidak diizinkan.');
    }
    if (command.submitting || command.saved) return;
    command.start();
    try {
      final payload = command.payload;
      final receipt = await _repository.transferSowing(
        idempotencyKey: payload.idempotencyKey,
        sowingId: payload.sowingId,
        tableId: payload.tableId,
        transferDate: payload.transferDate,
        plantCount: payload.plantCount,
        note: payload.note,
      );
      command.complete(receipt);
    } catch (error) {
      final definitivelyRejected =
          error is ApiException &&
          error.status >= 400 &&
          error.status < 500 &&
          error.code != 'SESSION_CHANGED';
      command.fail(error, definitivelyRejected: definitivelyRejected);
      rethrow;
    }
  }

  Future<void> refresh() {
    if (!mounted) return Future.value();
    return _refreshTask ??= _refresh().whenComplete(() => _refreshTask = null);
  }

  Future<void> refreshAfterTransfer() async {
    await _refreshTask;
    if (mounted) await refresh();
  }

  Future<void> _refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _repository.listSowings();
      if (mounted) {
        state = state.copyWith(records: list, loading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(loading: false, error: serviceError(e));
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void setFilterStatus(String? status) {
    state = state.copyWith(filterStatus: status);
  }

  Future<String?> saveSowing(SowingDraft draft) async {
    if (!mounted || state.saving) return null;
    if (draft.errors.isNotEmpty) {
      throw StateError('Isian penyemaian tidak valid.');
    }
    final command = _commands[_scope] ??= SowingCommand(draft);
    if (command.draft.id != draft.id) {
      throw StateError('Lanjutkan batch sebelumnya.');
    }
    final input = command.draft;
    final attempt = ++command.attempt;
    bool currentAttempt() =>
        identical(_command, command) && command.attempt == attempt;
    final previousUncertain = command.uncertain;
    state = state.copyWith(saving: true, pendingDraft: input);
    try {
      command.uncertain = true;
      final record =
          command.receipt ??
          (input.id == null
              ? await _repository.createSowing(
                  sowingDate: input.date,
                  seedCount: input.seedCount,
                  note: input.note,
                  materials: [
                    {
                      'id_inventaris': input.inventoryId!,
                      'jumlah': input.amount,
                      'satuan': input.unit,
                    },
                  ],
                  idempotencyKey: command.key,
                )
              : await _repository.updateSowing(
                  input.id!,
                  seedCount: input.seedCount,
                  note: input.note,
                  idempotencyKey: command.key,
                ));
      if (!currentAttempt()) return null;
      command.receipt = record;
    } catch (error) {
      if (!currentAttempt()) return null;
      final rejected =
          error is ApiException &&
          error.code != 'SESSION_CHANGED' &&
          error.status >= 400 &&
          error.status < 500;
      command.uncertain = previousUncertain || !rejected;
      if (!command.uncertain) _commands.remove(_scope);
      if (!mounted) return null;
      state = state.copyWith(
        saving: false,
        clearPending: !command.uncertain,
        saveError: serviceError(error),
      );
      rethrow;
    }
    if (!mounted) return null;
    _commands.remove(_scope);
    await _refreshTask;
    if (!mounted) return null;
    final record = command.receipt!;
    state = state.copyWith(
      records: [record, ...state.records.where((r) => r.id != record.id)],
    );
    await refresh();
    if (!mounted) return null;
    final nurseryWarning = state.error;
    String? inventoryWarning;
    if (input.id == null) {
      try {
        inventoryWarning = await _refreshInventory?.call();
      } catch (error) {
        inventoryWarning = serviceError(error);
      }
    }
    if (!mounted) return null;
    state = state.copyWith(
      saving: false,
      clearPending: true,
      error: nurseryWarning,
    );
    return nurseryWarning ?? inventoryWarning;
  }
}

final nurseryRepositoryProvider = Provider<NurseryRepository>((ref) {
  return NurseryRepository(ref.watch(apiClientProvider));
});

final connectedNurseryProvider =
    StateNotifierProvider.autoDispose<
      ConnectedNurseryViewModel,
      ConnectedNurseryState
    >((ref) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      if (user == null || !user.permissions.contains('penyemaian:read')) {
        throw StateError('Penyemaian memerlukan izin baca.');
      }
      final vm = ConnectedNurseryViewModel(
        ref.watch(nurseryRepositoryProvider),
        userId: user.id,
        canWrite:
            user.permissions.contains('penyemaian:write') &&
            user.permissions.contains('budidaya:write'),
        commands: ref.watch(sowingCommandsProvider),
        refreshInventory: () async {
          final inventory = ref.read(connectedInventoryProvider.notifier);
          await inventory.refreshAfterWrite();
          return ref.read(connectedInventoryProvider).error;
        },
      );
      Timer? timer;
      final clock = ref.watch(nurseryClockProvider);
      void schedule() {
        timer = Timer(untilJakartaMidnight(clock()), () {
          if (!vm.mounted) return;
          unawaited(vm.refresh());
          schedule();
        });
      }

      schedule();
      final lifecycle = AppLifecycleListener(
        onResume: () {
          if (vm.mounted) unawaited(vm.refresh());
        },
      );
      ref.onDispose(() {
        timer?.cancel();
        lifecycle.dispose();
      });
      return vm;
    });

final sowingDetailProvider = FutureProvider.autoDispose
    .family<SowingRecord, String>((ref, id) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      if (user == null || !user.permissions.contains('penyemaian:read')) {
        throw StateError('Penyemaian memerlukan izin baca.');
      }
      ref.watch(
        connectedNurseryProvider.select(
          (state) => state.records.where((r) => r.id == id).firstOrNull,
        ),
      );
      return ref.watch(nurseryRepositoryProvider).getSowing(id);
    });
