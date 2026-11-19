import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_skeleton.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_list_page.dart';

/// Store yang gagal dengan galat di luar [V2PenjualanStoreException], mis.
/// bentuk respons server berubah.
class _BrokenStore implements V2PenjualanStore {
  @override
  Future<V2PenjualanSnapshot> load() async =>
      throw const FormatException('Bentuk respons penjualan berubah.');

  @override
  Future<V2Penjualan> create(V2PenjualanDraft draft) =>
      throw UnimplementedError();

  @override
  Future<V2Penjualan> update(V2Penjualan existing, V2PenjualanDraft draft) =>
      throw UnimplementedError();

  @override
  Future<V2Penjualan> markPaid(V2Penjualan existing) =>
      throw UnimplementedError();

  @override
  Future<V2Penjualan> reload(V2Penjualan existing) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('galat tak terduga menutup kerangka dan menampilkan coba lagi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: V2PenjualanListPage(store: _BrokenStore())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(V2PenjualanSkeleton), findsNothing);
    expect(find.text('Gagal memuat'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
