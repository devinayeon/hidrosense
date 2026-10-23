import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/weather_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/cuaca_body.dart';
import 'package:hidrosense_mobile/views/components/dashboard_body.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:http/testing.dart';

const _weatherUser = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['cuaca:read'],
);

const _userWithoutWeather = SessionUser(
  id: '2',
  name: 'Pegawai',
  username: 'pegawai',
  role: 'pegawai',
  permissions: ['inventaris:read'],
);

ApiClient _api() => ApiClient(
  MockClient((_) async => throw StateError('Unexpected API request')),
  baseUri: Uri.parse('https://example.test/api/v1'),
)..setTokens(accessToken: 'access', refreshToken: 'refresh');

Widget _app({
  required SessionUser user,
  required WeatherViewModel weather,
  Widget body = const CuacaBody(),
}) {
  final api = _api();
  addTearDown(api.close);
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith(
        (_) => SessionViewModel(api, initialState: SessionState(user: user)),
      ),
      weatherViewModelProvider.overrideWith((_) => weather),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: body),
    ),
  );
}

void main() {
  group('WeatherViewModel', () {
    test('demo data never claims a live BMKG connection', () async {
      final data = await loadDemoWeather();

      expect(data.sumber.toLowerCase(), contains('data contoh'));
      expect(data.sumber.toLowerCase(), isNot(contains('bmkg api terkoneksi')));
      expect(data.lastUpdated.toLowerCase(), contains('bukan'));
      expect(data.prakiraanHarian, isNotEmpty);
    });

    test('a failed load can be retried without stale data', () async {
      var fail = true;
      final vm = WeatherViewModel(
        loader: () async {
          if (fail) throw StateError('offline');
          return loadDemoWeather();
        },
      );

      await pumpEventQueue();
      expect(vm.state.isLoading, isFalse);
      expect(vm.state.data, isNull);
      expect(vm.state.errorMessage, isNotNull);

      fail = false;
      await vm.fetchWeatherData();
      expect(vm.state.isLoading, isFalse);
      expect(vm.state.errorMessage, isNull);
      expect(vm.state.data?.kota, 'Ambulu, Jember');
      vm.dispose();
    });
  });

  group('CuacaBody', () {
    testWidgets('shows permission denial without reading weather', (
      tester,
    ) async {
      final weather = WeatherViewModel(autoLoad: false);
      await tester.pumpWidget(
        _app(user: _userWithoutWeather, weather: weather),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses cuaca tidak diizinkan.'), findsOneWidget);
      expect(find.text('Ambulu, Jember'), findsNothing);
    });

    testWidgets('shows a retry state and recovers after retry', (tester) async {
      var fail = true;
      final weather = WeatherViewModel(
        loader: () async {
          if (fail) throw StateError('offline');
          return loadDemoWeather();
        },
      );
      await tester.pumpWidget(_app(user: _weatherUser, weather: weather));
      await tester.pumpAndSettle();

      expect(find.text('Data cuaca belum dapat dimuat'), findsOneWidget);
      expect(find.byKey(const ValueKey('weather-retry')), findsOneWidget);

      fail = false;
      await tester.tap(find.byKey(const ValueKey('weather-retry')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Data cuaca belum dapat dimuat'), findsNothing);
      expect(find.text('Ambulu, Jember'), findsOneWidget);
      expect(find.textContaining('bukan pembaruan BMKG'), findsOneWidget);
    });
  });

  group('Dashboard weather tile', () {
    testWidgets('is hidden without cuaca:read', (tester) async {
      final weather = WeatherViewModel(autoLoad: false);
      await tester.pumpWidget(
        _app(
          user: _userWithoutWeather,
          weather: weather,
          body: const DashboardBody(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kondisi & Cuaca Kebun'), findsNothing);
    });

    testWidgets('is visible with cuaca:read', (tester) async {
      final weather = WeatherViewModel(autoLoad: false);
      await tester.pumpWidget(
        _app(user: _weatherUser, weather: weather, body: const DashboardBody()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kondisi & Cuaca Kebun'), findsOneWidget);
    });
  });
}
