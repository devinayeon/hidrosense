import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/dashboard_body.dart';
import 'package:hidrosense_mobile/views/components/header.dart';
import 'package:hidrosense_mobile/views/pages/info_seeding_page.dart';
import 'package:hidrosense_mobile/views/pages/login_page.dart';
import 'package:hidrosense_mobile/views/pages/main_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/row_button.dart';
import 'package:hidrosense_mobile/views/widgets/row_info_card_md.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response(Object data, {int status = 200}) =>
    http.Response(jsonEncode(data), status);

ApiClient apiFor(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');

const user = SessionUser(
  id: 'user-1',
  name: 'Mitra',
  username: 'mitra',
  role: 'petani',
  permissions: [],
);

Map<String, dynamic> sowingJson(
  String id, {
  bool ready = false,
  int age = 1,
  String status = 'aktif',
}) => {
  'id_penyemaian': id,
  'id_user': user.id,
  'tanggal_semai': '2026-09-01',
  'jumlah_benih': 100,
  'status_penyemaian': status,
  'usia_hari': age,
  'siap_pindah': ready,
};

class TestNursery extends ConnectedNurseryViewModel {
  TestNursery(ApiClient api, ConnectedNurseryState initial)
    : super(NurseryRepository(api), autoLoad: false) {
    state = initial;
  }

  void publish(ConnectedNurseryState value) => state = value;
}

Future<void> pumpDashboard(WidgetTester tester, TestNursery nursery) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [connectedNurseryProvider.overrideWith((ref) => nursery)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: DashboardBody()),
        ),
      ),
    );

void main() {
  testWidgets(
    'dashboard header uses Large Title and other headers retain size',
    (tester) async {
      final api = apiFor((_) async => response({'data': []}));
      final nursery = TestNursery(api, const ConnectedNurseryState());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connectedNurseryProvider.overrideWith((ref) => nursery)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Header>(find.byType(Header)).largeTitle, isTrue);
      expect(
        tester.widget<Text>(find.text('HidroSense')).style,
        AppTypography.largeTitle,
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 88);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: Header(titleText: 'Daftar Inventaris')),
        ),
      );
      expect(tester.widget<Header>(find.byType(Header)).largeTitle, isFalse);
      expect(
        tester.widget<Text>(find.text('Daftar Inventaris')).style?.fontSize,
        20,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
        kToolbarHeight,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets(
    'dashboard uses API readiness, puts alerts first, and opens the matching batch',
    (tester) async {
      var calls = 0;
      final api = apiFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/penyemaian');
        calls++;
        return response({
          'data': [
            sowingJson('ready-from-api', ready: true, age: 1),
            sowingJson('old-but-not-ready', age: 40),
            sowingJson('completed', ready: true, status: 'selesai'),
          ],
        });
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith(
              (ref) => SessionViewModel(
                api,
                initialState: const SessionState(user: user),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: DashboardBody()),
          ),
        ),
      );
      expect(find.text('Memuat data semaian...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Semaian Siap Pindah'), findsOneWidget);
      expect(find.textContaining('ready-from-api'), findsOneWidget);
      expect(find.textContaining('old-but-not-ready'), findsNothing);
      expect(find.textContaining('completed'), findsNothing);
      expect(find.text('2 Batch'), findsOneWidget);
      expect(find.text('200 Butir'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Semaian Siap Pindah')).dy,
        lessThan(tester.getTopLeft(find.text('Batch Semai Aktif')).dy),
      );
      expect(find.textContaining('BMKG'), findsNothing);
      expect(find.textContaining('2024'), findsNothing);
      await tester.tap(find.text('Semaian Siap Pindah'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InfoSeedingPage>(find.byType(InfoSeedingPage))
            .sowingRecord
            ?.id,
        'ready-from-api',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets(
    'dashboard distinguishes loading, unavailable and no ready batches',
    (tester) async {
      final api = apiFor((_) async => response({'data': []}));
      final nursery = TestNursery(
        api,
        const ConnectedNurseryState(loading: true),
      );
      await pumpDashboard(tester, nursery);
      expect(find.text('Memuat data semaian...'), findsOneWidget);
      expect(find.text('Belum ada semaian siap pindah'), findsNothing);
      nursery.publish(
        ConnectedNurseryState(
          error: 'Koneksi terputus',
          records: [SowingRecord.fromJson(sowingJson('cached', ready: true))],
        ),
      );
      await tester.pump();
      expect(find.text('Data semaian belum dapat diperbarui'), findsOneWidget);
      expect(find.text('Koneksi terputus'), findsOneWidget);
      expect(find.text('Semaian Siap Pindah'), findsNothing);
      nursery.publish(const ConnectedNurseryState());
      await tester.pump();
      expect(find.text('Belum ada semaian siap pindah'), findsOneWidget);
      expect(find.text('0 Batch'), findsOneWidget);
      expect(find.textContaining('Batch #04'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  for (final scenario in [
    (width: 240.0, columns: 1, scale: 2.0),
    (width: 320.0, columns: 2, scale: 2.0),
    (width: 390.0, columns: 2, scale: 1.0),
    (width: 800.0, columns: 4, scale: 1.0),
  ]) {
    testWidgets(
      'four quick actions fit ${scenario.width}px at text scale ${scenario.scale}',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = apiFor((_) async => response({'data': []}));
        final nursery = TestNursery(api, const ConnectedNurseryState());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectedNurseryProvider.overrideWith((ref) => nursery),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                child: child!,
              ),
              home: const Scaffold(body: DashboardBody()),
            ),
          ),
        );
        final grid = find.byKey(const ValueKey('dashboard-quick-actions'));
        final actions = find.descendant(
          of: grid,
          matching: find.byType(RowInfoCardMd),
        );
        expect(actions, findsNWidgets(4));
        for (var i = 0; i < 4; i++) {
          final size = tester.getSize(actions.at(i));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(
            tester.getRect(actions.at(i)).right,
            lessThanOrEqualTo(scenario.width),
          );
        }
        expect(
          tester.getTopLeft(actions.at(0)).dy,
          tester.getTopLeft(actions.at(scenario.columns - 1)).dy,
        );
        if (scenario.columns < 4) {
          expect(
            tester.getTopLeft(actions.at(scenario.columns)).dy,
            greaterThan(tester.getTopLeft(actions.at(0)).dy),
          );
        }
        expect(find.text('+ Barang'), findsOneWidget);
        expect(find.text('+ Semai'), findsOneWidget);
        expect(find.text('Cek Stok'), findsOneWidget);
        expect(find.text('Meja NFT'), findsOneWidget);
        expect(
          find
              .byType(SingleChildScrollView)
              .evaluate()
              .every(
                (element) =>
                    (element.widget as SingleChildScrollView).scrollDirection ==
                    Axis.vertical,
              ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      },
    );
  }

  testWidgets(
    'Next focuses password; Done submits once and disables controls while busy',
    (tester) async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final api = apiFor((request) {
        calls++;
        expect(request.url.path, '/api/v1/auth/login');
        expect(jsonDecode(request.body), {
          'username': 'mitra',
          'password': ' secret ',
        });
        return pending.future;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .textInputAction,
        TextInputAction.next,
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .textInputAction,
        TextInputAction.done,
      );
      await tester.enterText(fields.first, '  mitra  ');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final passwordEditor = tester.widget<EditableText>(
        find.byType(EditableText).last,
      );
      expect(passwordEditor.focusNode.hasFocus, isTrue);
      await tester.enterText(fields.last, ' secret ');
      final done = tester
          .widget<EditableText>(find.byType(EditableText).last)
          .onSubmitted!;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<RowButton>(find.byType(RowButton)).onTap, isNull);
      expect(tester.widget<TextFormField>(fields.first).enabled, isFalse);
      expect(tester.widget<TextFormField>(fields.last).enabled, isFalse);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      done(' secret ');
      await tester.tap(find.text('Memproses...'));
      await tester.pump();
      expect(calls, 1);
      pending.complete(
        response({
          'error': {'code': 'INVALID_LOGIN', 'message': 'Kredensial salah'},
        }, status: 401),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kredensial salah'), findsOneWidget);
      expect(tester.widget<RowButton>(find.byType(RowButton)).onTap, isNotNull);
      expect(tester.widget<TextFormField>(fields.first).enabled, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets(
    'Done keeps form validation and never submits empty credentials',
    (tester) async {
      var calls = 0;
      final api = apiFor((_) async {
        calls++;
        return response({'data': {}});
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );
      await tester.tap(find.byType(TextFormField).last);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Username tidak boleh kosong'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong'), findsOneWidget);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );
}
