import 'dart:convert';
import '../core/business_date.dart';
export '../core/business_date.dart' show jakartaToday, apiDate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/uuid.dart';
import '../data/models/damage_record.dart';
import '../data/models/transfer_record.dart';
import '../data/repositories/damage_repository.dart';
import '../data/services/api_client.dart';
import 'connected_table_viewmodel.dart';
import 'session_viewmodel.dart';

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

class DamageViewModel extends StateNotifier<DamageState> {
  DamageViewModel(
    this._repository,
    this.tableId,
    this._refreshTable, {
    required this.canWrite,
    this.autoLoad = true,
  }) : super(const DamageState()) {
    if (autoLoad) refresh();
  }
  final DamageRepository _repository;
  final String tableId;
  final Future<void> Function() _refreshTable;
  final bool canWrite, autoLoad;
  String? _payload, _key;
  DamageRecord? _saved;
  DamageDraft? _draft;
  bool _uncertain = false;
  int _load = 0;

  void beginDraft() {
    if (_saved != null) {
      _payload = null;
      _key = null;
      _saved = null;
      _draft = null;
      _uncertain = false;
    }
  }

  Future<void> refresh() async {
    final operation = ++_load;
    state = DamageState(
      transfers: state.transfers,
      reports: state.reports,
      loading: true,
      submitting: state.submitting,
      refreshWarning: state.refreshWarning,
      uncertainDraft: state.uncertainDraft,
    );
    try {
      final transfers = await _repository.listTransfers(tableId);
      final reports = <String, List<DamageRecord>>{};
      for (final transfer in transfers) {
        if (!mounted || operation != _load) return;
        reports[transfer.id] = await _repository.listDamages(transfer.id);
      }
      if (mounted && operation == _load) {
        state = DamageState(
          transfers: transfers,
          reports: Map.unmodifiable(reports),
          submitting: state.submitting,
          uncertainDraft: state.uncertainDraft,
        );
      }
    } catch (error) {
      if (mounted && operation == _load) {
        final denied =
            error is ApiException && [401, 403].contains(error.status);
        state = DamageState(
          transfers: denied ? const [] : state.transfers,
          reports: denied ? const {} : state.reports,
          submitting: state.submitting,
          error: serviceError(error),
          refreshWarning: state.refreshWarning,
          uncertainDraft: denied ? null : state.uncertainDraft,
        );
      }
    }
  }

  Future<DamageSubmitResult> submit(DamageDraft draft) async {
    if (state.submitting) return DamageSubmitResult.busy;
    final payload = jsonEncode(draft.toJson());
    if (_payload != payload) {
      _payload = payload;
      _key = generateUuidV4();
      _saved = null;
      _draft = draft;
      _uncertain = false;
    }
    if (!canWrite) return _fail('Akses pencatatan kerusakan tidak diizinkan.');
    if (_saved == null && !_uncertain) {
      final candidates = state.transfers.where((t) => t.id == draft.transferId);
      final date = DateTime.tryParse(draft.date);
      if (candidates.isEmpty ||
          date == null ||
          apiDate(date) != draft.date ||
          date.isBefore(DateTime.parse(candidates.first.transferDate)) ||
          date.isAfter(jakartaToday()) ||
          draft.plantCount <= 0 ||
          draft.plantCount > candidates.first.activePlants ||
          draft.category.trim().isEmpty ||
          draft.category.trim().length > 100 ||
          (draft.note?.trim().length ?? 0) > 1000) {
        return _fail('Periksa batch, tanggal, jumlah tanaman, dan keterangan.');
      }
    }
    state = DamageState(
      transfers: state.transfers,
      reports: state.reports,
      submitting: true,
      uncertainDraft: _uncertain ? _draft : null,
    );
    try {
      _saved ??= await _repository.createDamage(draft, _key!);
      _uncertain = false;
    } catch (error) {
      if (!mounted) return DamageSubmitResult.failed;
      _uncertain =
          error is! ApiException || error.status == 0 || error.status >= 500;
      if (error is ApiException && error.code == 'DAMAGE_EXCEEDS_ACTIVE') {
        await refresh();
        if (!mounted) return DamageSubmitResult.failed;
      }
      return _fail(serviceError(error));
    }
    if (!mounted) return DamageSubmitResult.saved;
    await refresh();
    if (!mounted) return DamageSubmitResult.saved;
    String? warning = state.error;
    try {
      await _refreshTable();
    } catch (error) {
      warning ??= serviceError(error);
    }
    if (!mounted) return DamageSubmitResult.saved;
    final reports = {...state.reports};
    final saved = _saved!;
    reports[saved.transferId] = List.unmodifiable([
      saved,
      ...?reports[saved.transferId]?.where((r) => r.id != saved.id),
    ]);
    state = DamageState(
      transfers: state.transfers,
      reports: Map.unmodifiable(reports),
      refreshWarning: warning == null
          ? null
          : 'Laporan tersimpan. Data terbaru belum dapat dimuat: $warning',
    );
    return warning == null
        ? DamageSubmitResult.saved
        : DamageSubmitResult.savedRefreshFailed;
  }

  DamageSubmitResult _fail(String message) {
    if (mounted) {
      state = DamageState(
        transfers: state.transfers,
        reports: state.reports,
        error: message,
        uncertainDraft: _uncertain ? _draft : null,
      );
    }
    return DamageSubmitResult.failed;
  }
}

final damageRepositoryProvider = Provider<DamageRepository>(
  (ref) => DamageRepository(ref.watch(apiClientProvider)),
);

final damageProvider = StateNotifierProvider.autoDispose
    .family<DamageViewModel, DamageState, String>((ref, tableId) {
      final user = ref.watch(sessionProvider.select((s) => s.user));
      if (user == null || !user.permissions.contains('budidaya:read')) {
        throw StateError('Laporan kerusakan memerlukan akses budidaya.');
      }
      return DamageViewModel(
        ref.watch(damageRepositoryProvider),
        tableId,
        () => ref.read(connectedTableProvider.notifier).refreshTable(tableId),
        canWrite: user.permissions.contains('budidaya:write'),
      );
    });
