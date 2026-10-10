import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/uuid.dart';
import '../data/services/api_client.dart';
import '../data/models/table_record.dart';
import '../data/repositories/table_repository.dart';
import 'session_viewmodel.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return TableRepository(api);
});

class TableState {
  const TableState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilter,
  });

  final List<TableRecord> records;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String? statusFilter; // null = semua, 'tersedia', 'pemeliharaan', dsb.

  List<TableRecord> get filtered {
    return records.where((table) {
      if (statusFilter != null &&
          !(statusFilter == 'tersedia'
              ? table.isActive
              : statusFilter == 'pemeliharaan'
              ? table.isMaintenance
              : table.status == statusFilter)) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchCode = table.code.toLowerCase().contains(q);
        final matchNotes = table.notes?.toLowerCase().contains(q) ?? false;
        return matchCode || matchNotes;
      }
      return true;
    }).toList();
  }

  Map<String, int> get counts {
    int total = records.length;
    int active = 0;
    int maintenance = 0;
    for (final t in records) {
      if (t.isMaintenance) {
        maintenance++;
      } else if (t.isActive) {
        active++;
      }
    }
    return {'total': total, 'aktif': active, 'perawatan': maintenance};
  }

  TableState copyWith({
    List<TableRecord>? records,
    bool? loading,
    String? error,
    bool clearError = false,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return TableState(
      records: records ?? this.records,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
    );
  }
}

class TableCommand {
  TableCommand(this.target, this.body) : key = generateUuidV4();
  final String target, key;
  final Map<String, dynamic> body;
  bool uncertain = false, running = false;
  TableRecord? receipt;
}

final tableCommandsProvider = Provider(
  (ref) => <(String, String), TableCommand>{},
);

class ConnectedTableNotifier extends StateNotifier<TableState> {
  ConnectedTableNotifier(
    this._repo, {
    this.canRead = true,
    this.canWrite = true,
    String userId = '',
    Map<(String, String), TableCommand>? commands,
  }) : _scope = (_repo.serverOrigin, userId),
       _commands = commands ?? {},
       super(const TableState()) {
    if (canRead) refresh();
  }
  final TableRepository _repo;
  final bool canRead, canWrite;
  final (String, String) _scope;
  final Map<(String, String), TableCommand> _commands;
  int _generation = 0;
  TableCommand? get pendingCommand => _commands[_scope];
  bool get payloadLocked => pendingCommand?.uncertain ?? false;
  bool get submitting => pendingCommand?.running ?? false;
  String? refreshWarning;
  Future<void> refresh() async {
    if (!mounted || !canRead) return;
    final generation = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final list = await _repo.fetchTables();
      if (mounted && generation == _generation) {
        state = state.copyWith(records: list, loading: false);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        state = state.copyWith(loading: false, error: serviceError(e));
      }
    }
  }

  void setSearchQuery(String query) {
    if (mounted) state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? status) {
    if (mounted) {
      state = state.copyWith(
        statusFilter: status,
        clearStatusFilter: status == null,
      );
    }
  }

  void _merge(TableRecord record) {
    ++_generation;
    final current = state.records.where((r) => r.id == record.id).firstOrNull;
    if (current?.version != null &&
        record.version != null &&
        BigInt.parse(current!.version!) > BigInt.parse(record.version!)) {
      return;
    }
    if (mounted) {
      state = state.copyWith(
        records: List.unmodifiable([
          record,
          ...state.records.where((r) => r.id != record.id),
        ]),
        loading: false,
        clearError: true,
      );
    }
  }

  Future<void> refreshTable(String id) async {
    if (!mounted || !canRead) return;
    final generation = _generation;
    final record = await _repo.getTable(id);
    if (record.id != id) {
      throw const FormatException('Respons meja tidak sesuai target.');
    }
    if (mounted && generation == _generation) _merge(record);
  }

  Future<TableRecord> _save(String target, Map<String, dynamic> body) async {
    if (!mounted || !canWrite) {
      throw StateError('Akses perubahan meja tidak diizinkan.');
    }
    var command = pendingCommand;
    if (command?.running == true) throw StateError('Meja sedang disimpan.');
    if (command?.uncertain == true &&
        (command!.target != target ||
            jsonEncode(command.body) != jsonEncode(body))) {
      throw StateError('Hasil belum pasti. Ulangi isian meja sebelumnya.');
    }
    if (command == null ||
        command.target != target ||
        jsonEncode(command.body) != jsonEncode(body)) {
      command = TableCommand(target, body);
      _commands[_scope] = command;
    }
    command.running = true;
    refreshWarning = null;
    ++_generation;
    try {
      command.uncertain = true;
      final b = command.body;
      command.receipt ??= target == 'create'
          ? await _repo.createTable(
              code: b['kode_meja'] as String,
              holeCount: b['jumlah_lubang'] as int,
              status: b['status_meja'] as String?,
              notes: b['keterangan'] as String?,
              idempotencyKey: command.key,
            )
          : await _repo.updateTable(
              target,
              code: b['kode_meja'] as String?,
              holeCount: b['jumlah_lubang'] as int?,
              status: b['status_meja'] as String?,
              notes: b['keterangan'],
              idempotencyKey: command.key,
            );
      command.uncertain = false;
      final record = command.receipt!;
      if (target != 'create' && record.id != target) {
        throw const FormatException('Respons meja tidak sesuai target.');
      }
      if (!mounted) return record;
      _merge(record);
      await refresh();
      if (mounted) {
        refreshWarning = state.error;
        if (refreshWarning != null ||
            !state.records.any((r) => r.id == record.id)) {
          _merge(record);
        }
      }
      _commands.remove(_scope);
      return record;
    } catch (e) {
      command.uncertain =
          e is! ApiException ||
          e.status == 0 ||
          e.status >= 500 ||
          e.code == 'SESSION_CHANGED';
      if (!command.uncertain) _commands.remove(_scope);
      rethrow;
    } finally {
      command.running = false;
    }
  }

  Future<TableRecord> createTable({
    required String code,
    required int holeCount,
    String? status,
    String? notes,
  }) => _save('create', {
    'kode_meja': code,
    'jumlah_lubang': holeCount,
    'status_meja': status ?? 'tersedia',
    'keterangan': notes,
  });
  Future<TableRecord> updateTable(
    String id, {
    String? code,
    int? holeCount,
    String? status,
    String? notes,
  }) => _save(id, {
    'kode_meja': ?code,
    'jumlah_lubang': ?holeCount,
    'status_meja': ?status,
    'keterangan': notes,
  });
}

final connectedTableProvider =
    StateNotifierProvider<ConnectedTableNotifier, TableState>((ref) {
      final user = ref.watch(sessionProvider.select((s) => s.user));
      return ConnectedTableNotifier(
        ref.watch(tableRepositoryProvider),
        userId: user?.id ?? '',
        canRead: user?.permissions.contains('budidaya:read') ?? false,
        canWrite: user?.permissions.contains('budidaya:write') ?? false,
        commands: ref.watch(tableCommandsProvider),
      );
    });
