import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/repositories/table_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/models/seeding_batch_model.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/views/widgets/transfer_seedling_bottom_sheet.dart';
import 'package:http/http.dart' as http;

class FakeTableRepository extends TableRepository {
  FakeTableRepository()
      : super(ApiClient(http.Client(), baseUri: Uri.parse('http://localhost')));
}

class MockTableNotifier extends ConnectedTableNotifier {
  MockTableNotifier(super.repo, List<TableRecord> initialRecords) {
    state = TableState(records: initialRecords);
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  group('TransferSeedlingBottomSheet B009 Tests', () {
    testWidgets('Merender estimasi panen 45 hari dan kapasitas meja NFT',
        (tester) async {
      final mockTable = TableRecord(
        id: '1',
        code: 'M-01',
        holeCount: 200,
        activePlants: 100,
        status: 'tersedia',
        notes: 'Meja NFT Selada',
      );

      final batch = SeedingBatch(
        id: '1',
        batchName: 'Batch Selada #01',
        variety: 'Selada Romaine',
        dateText: '2026-09-22',
        seedCount: 200,
        hss: 15,
        totalHss: 15,
        statusLabel: 'Siap Pindah',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedTableProvider.overrideWith(
              (ref) => MockTableNotifier(
                FakeTableRepository(),
                [mockTable],
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => TransferSeedlingBottomSheet.show(
                    context,
                    seedingItem: batch,
                  ),
                  child: const Text('Buka Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Modal'));
      await tester.pumpAndSettle();

      // Verifikasi judul modal & estimasi 45 hari
      expect(find.text('Pindahkan Bibit ke Meja NFT'), findsOneWidget);
      expect(find.textContaining('Estimasi Waktu Panen (45 Hari)'), findsOneWidget);
      expect(find.textContaining('M-01 (Sisa 100 / 200 Lubang)'), findsOneWidget);

      // Verifikasi validasi input (coba masukkan 150 bibit padahal sisa 100)
      final inputFinder = find.byType(TextFormField).first;
      final submitFinder = find.text('Konfirmasi Pemindahan ke Meja');
      await tester.enterText(inputFinder, '150');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Meja tanam hanya memiliki sisa 100 lubang kosong'),
        findsOneWidget,
      );

      // Masukkan jumlah valid (50 bibit)
      await tester.enterText(inputFinder, '50');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verifikasi modal tertutup dan SnackBar muncul
      expect(find.text('Pindahkan Bibit ke Meja NFT'), findsNothing);
      expect(find.textContaining('Berhasil memindahkan 50 bibit ke Meja M-01'), findsOneWidget);
    });
  });
}
