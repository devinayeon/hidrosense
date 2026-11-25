import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/uuid.dart';
import '../../data/pest_detector.dart';
import '../../data/pest_models.dart';
import '../../data/pest_repository.dart';
import '../../domain/pest_summary.dart';
import 'pest_providers.dart';
import 'recommendation_decider.dart';

enum ScanPhase { idle, analyzing, analyzed, saving, saved, failed }

class PestScanState {
  const PestScanState({
    this.phase = ScanPhase.idle,
    this.photo,
    this.result,
    this.severities = const {},
    this.recommendations = const [],
    this.error,
    this.saveStarted = false,
    this.tableId,
  });

  final ScanPhase phase;
  final Uint8List? photo;
  final PestScanResult? result;

  /// Tingkat yang dikirim per hama. Awalnya saran heuristik, bisa diubah sampai simpan dimulai.
  final Map<PestKind, PestSeverity> severities;
  final List<PestRecommendation> recommendations;
  final String? error;

  /// Sebuah tulis sudah dikirim untuk foto ini. Sejak itu tingkat dan meja terkunci, sehingga
  /// kiriman ulang membawa isi dan kunci yang sama (ARCHITECTURE.md, "Bila respons server hilang").
  final bool saveStarted;

  /// Meja yang dipakai foto ini sejak simpan dimulai.
  final String? tableId;

  bool get canEditSeverity => phase == ScanPhase.analyzed && !saveStarted;
  bool get canRetrySave => phase == ScanPhase.failed && saveStarted;

  PestScanState copyWith({
    ScanPhase? phase,
    Map<PestKind, PestSeverity>? severities,
    List<PestRecommendation>? recommendations,
    String? error,
    bool clearError = false,
    bool? saveStarted,
    String? tableId,
  }) => PestScanState(
    phase: phase ?? this.phase,
    photo: photo,
    result: result,
    severities: severities ?? this.severities,
    recommendations: recommendations ?? this.recommendations,
    error: clearError ? null : error ?? this.error,
    saveStarted: saveStarted ?? this.saveStarted,
    tableId: tableId ?? this.tableId,
  );
}

/// Alur: analisis di perangkat (tanpa jaringan) → simpan (unggah, pindaian, rekomendasi).
///
/// Simpan bisa diulang setelah gagal di tengah jalan: hasil tiap langkah dan kunci idempotensi
/// disimpan, jadi foto tidak diunggah dua kali dan rekomendasi tidak dobel.
class PestScanNotifier extends StateNotifier<PestScanState> {
  PestScanNotifier(
    this._detect,
    this._repo,
    this._resolveTransfer,
    this._decider,
  ) : super(const PestScanState());

  final Future<PestScanResult> Function(Uint8List) _detect;
  final PestRepository _repo;
  final Future<String?> Function(String tableId) _resolveTransfer;
  final RecommendationDecider _decider;

  UploadedPhoto? _uploaded;
  String? _transferId;
  String? _scanId;
  String? _scanKey;
  final Map<PestKind, String> _recKeys = {};
  int _generation = 0;

  void _forgetPhoto() {
    _uploaded = null;
    _transferId = null;
    _scanId = null;
    _scanKey = null;
    _recKeys.clear();
  }

  Future<void> analyze(Uint8List bytes) async {
    final generation = ++_generation;
    _forgetPhoto();
    state = PestScanState(phase: ScanPhase.analyzing, photo: bytes);
    try {
      final result = await _detect(bytes);
      if (generation != _generation) return;
      state = PestScanState(
        phase: ScanPhase.analyzed,
        photo: bytes,
        result: result,
        severities: {
          for (final f in result.findings) f.kind: f.suggestedSeverity,
        },
      );
    } catch (error) {
      if (generation != _generation) return;
      state = PestScanState(
        phase: ScanPhase.failed,
        photo: bytes,
        error: error is FormatException
            ? error.message
            : 'Foto tidak bisa dianalisis. Coba foto lain.',
      );
    }
  }

  void setSeverity(PestKind kind, PestSeverity severity) {
    if (!state.canEditSeverity) return;
    state = state.copyWith(severities: {...state.severities, kind: severity});
  }

  Future<void> save({required String tableId}) async {
    final result = state.result;
    final photo = state.photo;
    if (result == null || photo == null || state.phase == ScanPhase.saving) {
      return;
    }
    // Setelah simpan dimulai meja terkunci: pindaian sudah terikat ke batch meja itu.
    final table = state.tableId ?? tableId;
    final generation = _generation;
    state = state.copyWith(phase: ScanPhase.saving, clearError: true);
    try {
      if (_transferId == null) {
        final transfer = await _resolveTransfer(table);
        if (generation != _generation) return;
        if (transfer == null) {
          // Belum ada yang terkirim: pengguna boleh memilih meja lain.
          state = state.copyWith(
            phase: ScanPhase.analyzed,
            error:
                'Meja ini belum punya tanaman aktif. Pilih meja yang sedang ditanami.',
          );
          return;
        }
        _transferId = transfer;
      }
      state = state.copyWith(saveStarted: true, tableId: table);
      _uploaded ??= await _repo.uploadPhoto(photo, await _repo.signUpload());
      _scanKey ??= generateUuidV4();
      _scanId ??= await _repo.saveScan(
        transferId: _transferId!,
        photo: _uploaded!,
        modelVersion: result.modelVersion,
        findings: [
          for (final f in result.findings)
            ScanFindingDraft(
              pest: f.kind,
              count: f.count,
              maxConfidence: f.maxConfidence,
            ),
        ],
        idempotencyKey: _scanKey,
      );
      final done = [...state.recommendations];
      for (final f in result.findings) {
        if (done.any((r) => r.pest == f.kind)) continue;
        done.add(
          await _repo.createRecommendation(
            tableId: table,
            pest: f.kind,
            severity: state.severities[f.kind] ?? f.suggestedSeverity,
            scanId: _scanId,
            idempotencyKey: _recKeys.putIfAbsent(f.kind, generateUuidV4),
          ),
        );
        if (generation == _generation) {
          state = state.copyWith(recommendations: List.of(done));
        }
      }
      if (generation != _generation) return;
      state = state.copyWith(phase: ScanPhase.saved, recommendations: done);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        phase: ScanPhase.failed,
        error: pestErrorMessage(error),
      );
    }
  }

  Future<String?> accept(
    String id, {
    String? note,
    List<StockLineDraft> materials = const [],
  }) => _apply(() => _decider.accept(id, note: note, materials: materials));

  Future<String?> reject(String id, RejectReason reason, {String? note}) =>
      _apply(() => _decider.reject(id, reason, note: note));

  /// Pesan galat, atau null bila berhasil atau diabaikan karena ketuk ganda.
  Future<String?> _apply(Future<PestRecommendation?> Function() call) async {
    try {
      final updated = await call();
      if (updated != null) {
        state = state.copyWith(
          recommendations: [
            for (final r in state.recommendations)
              r.id == updated.id ? updated : r,
          ],
        );
      }
      return null;
    } catch (error) {
      return pestErrorMessage(error);
    }
  }

  void reset() {
    _generation++;
    _forgetPhoto();
    state = const PestScanState();
  }
}

final pestScanProvider =
    StateNotifierProvider.autoDispose<PestScanNotifier, PestScanState>((ref) {
      final repo = ref.watch(pestRepositoryProvider);
      return PestScanNotifier(
        ref.watch(pestDetectFnProvider),
        repo,
        ref.watch(activeTransferResolverProvider),
        RecommendationDecider(repo),
      );
    });
