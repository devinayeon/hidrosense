import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_connected_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('login membuka beranda v2; logout kembali ke onboarding v2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return respond({
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'user': {
                'id_user': '1',
                'nama': 'Mitra',
                'username': 'mitra',
                'role': 'petani',
                'permissions': [
                  'inventaris:read',
                  'inventaris:write',
                  'penyemaian:read',
                  'penyemaian:write',
                ],
              },
            },
          });
        }
        if (request.url.path.endsWith('/penyemaian')) {
          return respond({
            'data': [],
            'meta': {'page': 1, 'total': 0, 'total_pages': 0},
          });
        }
        return respond({'data': {}});
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AppGate()),
      ),
    );
    await tester.pump();
    expect(find.byType(V2OnboardingPage), findsOneWidget);
    expect(find.byType(V2BerandaConnectedPage), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppGate)),
    );
    await container.read(sessionProvider.notifier).login('mitra', 'secret');
    await tester.pumpAndSettle();
    expect(find.byType(V2BerandaConnectedPage), findsOneWidget);
    expect(find.byType(V2OnboardingPage), findsNothing);

    await container.read(sessionProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(find.byType(V2OnboardingPage), findsOneWidget);
    expect(find.byType(V2BerandaConnectedPage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
}

http.Response respond(Object body) => http.Response(jsonEncode(body), 200);
