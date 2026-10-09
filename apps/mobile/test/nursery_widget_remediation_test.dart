import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/penyemaian_body.dart';
import 'package:hidrosense_mobile/views/pages/info_seeding_page.dart';
import 'package:hidrosense_mobile/views/pages/seeding_form_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/row_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/remediation_capture.dart';

const farmer = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['penyemaian:read', 'penyemaian:write', 'inventaris:read'],
);
Map<String, dynamic> sowing({
  int count = 100,
  String note = 'Rak A',
  int age = 14,
}) => {
  'id_penyemaian': '1',
  'id_user': '1',
  'tanggal_semai': '2026-09-16',
  'jumlah_benih': count,
  'sisa_benih': count,
  'status_penyemaian': 'aktif',
  'keterangan': note,
  'usia_hari': age,
  'siap_pindah': age >= 15,
  'stok_konsumsi': [
    {'id_inventaris': '1', 'jumlah': '1.25', 'satuan': 'gram'},
  ],
};
InventoryRecord seed() => InventoryRecord.fromJson({
  'id_inventaris': '1',
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '1',
  'id_obat': null,
  'nama_barang': 'Benih Bayam',
  'satuan': 'gram',
  'stok_minimum': null,
  'status_aktif': 1,
  'nama_jenis': 'Benih Tanaman',
  'nama_obat': null,
  'saldo': '10',
});

class InventoryForForm extends ConnectedInventoryViewModel {
  InventoryForForm(ApiClient api, List<InventoryRecord> records)
    : super(
        InventoryRepository(
          api,
          Completer<InventoryCache>().future,
          userId: '1',
        ),
        autoLoad: false,
        initialState: ConnectedInventoryState(records: records),
      );
}

class NurseryForPage extends ConnectedNurseryViewModel {
  NurseryForPage(ApiClient api, ConnectedNurseryState initial)
    : super(NurseryRepository(api), autoLoad: false) {
    state = initial;
  }
}

class PageFixture {
  PageFixture() {
    api = ApiClient(
      MockClient((req) async {
        Object data;
        if (req.method == 'PATCH' || req.method == 'POST') {
          writes.add(req);
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          current = sowing(
            count: body['jumlah_benih'] as int,
            note: body['keterangan'] as String? ?? '',
          );
          data = current;
        } else {
          data = req.url.path.endsWith('/penyemaian/1') ? current : [current];
        }
        return http.Response(
          jsonEncode({
            'data': data,
            if (data is List) 'meta': {'page': 1, 'total': 1, 'total_pages': 1},
          }),
          req.method == 'POST' ? 201 : 200,
        );
      }),
      baseUri: Uri.parse('https://fixture.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');
  }
  late final ApiClient api;
  Map<String, dynamic> current = sowing();
  final writes = <http.Request>[];
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    List<InventoryRecord>? seeds,
    SessionUser user = farmer,
    ConnectedNurseryState? nursery,
    double scale = 1,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (ref) =>
                SessionViewModel(api, initialState: SessionState(user: user)),
          ),
          connectedInventoryProvider.overrideWith(
            (ref) => InventoryForForm(api, seeds ?? [seed()]),
          ),
          connectedNurseryProvider.overrideWith(
            (ref) => NurseryForPage(
              api,
              nursery ??
                  ConnectedNurseryState(
                    records: [SowingRecord.fromJson(current)],
                  ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('remediation-capture'),
              child: child!,
            ),
          ),
          home: page,
        ),
      ),
    );
    if (nursery?.loading == true) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets(
    'list search/navigation and form calendar/selector/keyboard work',
    (tester) async {
      final f = PageFixture();
      addTearDown(f.api.close);
      await f.pump(tester, const Scaffold(body: PenyemaianBody()));
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('Penyemaian tidak ditemukan.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rak A');
      await tester.pump();
      await tester.tap(find.text('Batch #1'));
      await tester.pumpAndSettle();
      expect(find.byType(InfoSeedingPage), findsOneWidget);
      expect(
        tester.getSize(find.text('Ubah').hitTestable()).height,
        greaterThan(0),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Mulai Penyemaian Baru'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedingFormPage), findsOneWidget);
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(
        picker.lastDate.isAfter(DateTime.now().add(const Duration(days: 1))),
        isFalse,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih Benih dari Inventaris'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Benih Bayam'), findsNothing);
      await tester.tap(find.byType(TextFormField).at(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final editable = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(editable.any((field) => field.focusNode.hasFocus), isTrue);
      expect(f.writes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'detail edit persists count and empty note; date is immutable and stocks remain visible',
    (tester) async {
      final f = PageFixture();
      addTearDown(f.api.close);
      await f.pump(
        tester,
        InfoSeedingPage(sowingRecord: SowingRecord.fromJson(f.current)),
      );
      expect(find.text('1: 1.25 gram'), findsOneWidget);
      expect(find.textContaining('Varietas:'), findsNothing);
      expect(find.text('Bibit Rusak'), findsNothing);
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();
      final inputs = find.byType(TextFormField);
      final date = tester.widget<TextField>(
        find.descendant(of: inputs.at(0), matching: find.byType(TextField)),
      );
      expect(date.readOnly, isTrue);
      expect(date.onTap, isNull);
      await tester.enterText(inputs.at(1), '120');
      await tester.enterText(inputs.at(2), '');
      await tester.tap(find.text('Simpan Penyemaian'));
      await tester.pumpAndSettle();
      expect(f.writes.length, 1);
      expect(f.writes.single.method, 'PATCH');
      expect(jsonDecode(f.writes.single.body), {
        'jumlah_benih': 120,
        'keterangan': '',
      });
      expect(find.text('120 Bibit'), findsOneWidget);
      expect(find.text('Rak A'), findsNothing);
      expect(find.text('1: 1.25 gram'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'create explicitly picks inventory and separates seeds from grams; empty inventory never submits',
    (tester) async {
      final f = PageFixture();
      addTearDown(f.api.close);
      await f.pump(tester, const SeedingFormPage(), seeds: []);
      await tester.tap(find.text('Simpan Penyemaian'));
      await tester.pumpAndSettle();
      expect(f.writes, isEmpty);
      expect(find.text('Pilih benih aktif dari inventaris.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await f.pump(tester, const SeedingFormPage());
      await tester.tap(find.text('Pilih Benih dari Inventaris'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Benih Bayam'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '100');
      await tester.enterText(find.byType(TextFormField).at(2), '1.25');
      await tester.tap(find.text('Simpan Penyemaian'));
      await tester.pumpAndSettle();
      final body = jsonDecode(f.writes.single.body);
      expect(body['jumlah_benih'], 100);
      expect(body['materials'], [
        {'id_inventaris': '1', 'jumlah': '1.25', 'satuan': 'gram'},
      ]);
      expect(
        f.writes.single.headers['Idempotency-Key'],
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('read-only sessions cannot add/edit/transfer via pages', (
    tester,
  ) async {
    final f = PageFixture();
    addTearDown(f.api.close);
    const readOnly = SessionUser(
      id: '1',
      name: 'Petani',
      username: 'petani',
      role: 'petani',
      permissions: ['penyemaian:read'],
    );
    f.current = sowing(age: 15);
    await f.pump(
      tester,
      const Scaffold(body: PenyemaianBody()),
      user: readOnly,
    );
    expect(find.text('+ Mulai Penyemaian Baru'), findsNothing);
    expect(find.text('Pindah ke Meja'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await f.pump(
      tester,
      InfoSeedingPage(sowingRecord: SowingRecord.fromJson(f.current)),
      user: readOnly,
    );
    expect(find.text('Ubah'), findsNothing);
    expect(find.text('Pindahkan ke Meja'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await f.pump(tester, const SeedingFormPage(), user: readOnly);
    expect(find.text('Anda tidak memiliki akses penyemaian.'), findsOneWidget);
    expect(f.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final dark in [false, true]) {
    for (final screen in [
      'list',
      'detail',
      'form',
      'loading',
      'empty',
      'error',
    ]) {
      testWidgets(
        '$screen 320x568 text2 ${dark ? 'dark' : 'light'} has no overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final f = PageFixture();
          addTearDown(f.api.close);
          f.current = sowing(age: 15);
          final page = switch (screen) {
            'detail' => InfoSeedingPage(
              sowingRecord: SowingRecord.fromJson(f.current),
            ),
            'form' => const SeedingFormPage(),
            _ => const Scaffold(body: PenyemaianBody()),
          };
          final state = switch (screen) {
            'loading' => const ConnectedNurseryState(loading: true),
            'empty' => const ConnectedNurseryState(),
            'error' => const ConnectedNurseryState(
              error: 'Layanan tidak dapat dihubungi.',
            ),
            _ => null,
          };
          await f.pump(tester, page, nursery: state, scale: 2, dark: dark);
          await captureRemediation(
            tester,
            'nursery-$screen-${dark ? 'dark' : 'light'}-small-text2',
          );
          expect(tester.takeException(), isNull);
          for (final button in find.byType(RowButton).evaluate()) {
            final size = tester.getSize(find.byWidget(button.widget));
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
          if (screen == 'form') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 180);
            await tester.pump();
            await tester.ensureVisible(find.byType(TextFormField).last);
            await tester.enterText(
              find.byType(TextFormField).last,
              'Catatan rak',
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            tester.view.resetViewInsets();
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
