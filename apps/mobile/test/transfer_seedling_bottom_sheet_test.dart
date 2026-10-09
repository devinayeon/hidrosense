import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/penyemaian_body.dart';
import 'package:hidrosense_mobile/views/pages/info_seeding_page.dart';
import 'package:hidrosense_mobile/views/widgets/seedling_transfer_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final fromList in [true, false]) {
    testWidgets(
      '${fromList ? 'list' : 'detail'} transfer persists and refreshes both counts',
      (tester) async {
        var moved = 0;
        var posts = 0;
        var reject = fromList;
        Map<String, dynamic> sowing() => {
          'id_penyemaian': '1',
          'id_user': '2',
          'tanggal_semai': '2026-09-01',
          'jumlah_benih': 100,
          'sisa_benih': 100 - moved,
          'status_penyemaian': 'aktif',
          'usia_hari': 37,
          'siap_pindah': true,
        };
        final api = ApiClient(
          MockClient((request) async {
            Object data;
            if (request.method == 'POST') {
              posts++;
              expect(request.url.path, '/api/v1/pemindahan');
              expect(request.headers['Idempotency-Key'], isNotEmpty);
              final body = jsonDecode(request.body);
              expect(body['id_penyemaian'], '1');
              expect(body['id_meja'], '1');
              expect(body['jumlah_tanaman'], 50);
              if (reject) {
                reject = false;
                return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'TABLE_CAPACITY_EXCEEDED',
                      'message': 'Kapasitas tidak cukup.',
                    },
                  }),
                  409,
                );
              }
              moved += body['jumlah_tanaman'] as int;
              data = {'id_pemindahan': '1'};
            } else if (request.url.path.endsWith('/meja-tanam')) {
              data = [
                {
                  'id_meja': '1',
                  'kode_meja': 'M-01',
                  'jumlah_lubang': 200,
                  'tanaman_aktif': moved,
                  'kapasitas_tersedia': 200 - moved,
                  'status_meja': 'tersedia',
                },
              ];
            } else if (request.url.path.endsWith('/penyemaian/1')) {
              data = sowing();
            } else {
              data = [sowing()];
            }
            return http.Response(
              jsonEncode({
                'data': data,
                if (request.url.path.endsWith('/penyemaian'))
                  'meta': {'page': 1, 'total': 1, 'total_pages': 1},
              }),
              request.method == 'POST' ? 201 : 200,
            );
          }),
          baseUri: Uri.parse('https://example.test/api/v1'),
        )..setTokens(accessToken: 'access', refreshToken: 'refresh');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith(
                (ref) => SessionViewModel(
                  api,
                  initialState: const SessionState(
                    user: SessionUser(
                      id: '2',
                      name: 'Petani',
                      username: 'petani',
                      role: 'petani',
                      permissions: [
                        'penyemaian:read',
                        'penyemaian:write',
                        'budidaya:write',
                      ],
                    ),
                  ),
                ),
              ),
              apiClientProvider.overrideWithValue(api),
              connectedNurseryProvider.overrideWith(
                (ref) => ConnectedNurseryViewModel(NurseryRepository(api)),
              ),
            ],
            child: MaterialApp(
              home: fromList
                  ? const Scaffold(body: PenyemaianBody())
                  : InfoSeedingPage(
                      sowingRecord: SowingRecord.fromJson(sowing()),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.text(
          fromList ? 'Pindah ke Meja' : 'Pindahkan ke Meja',
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(SeedlingTransferSheet), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Meja M-01').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '50');
        final submit = find.text('Simpan pemindahan');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        if (fromList) {
          expect(find.text('Kapasitas tidak cukup.'), findsOneWidget);
          expect(find.text('Pemindahan berhasil disimpan.'), findsNothing);
          expect(moved, 0);
          await tester.tap(submit);
          await tester.pumpAndSettle();
        }
        expect(posts, fromList ? 2 : 1);
        expect(moved, 50);
        expect(find.text('Pemindahan berhasil disimpan.'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SeedlingTransferSheet)),
        );
        expect(
          container.read(connectedTableProvider).records.single.activePlants,
          50,
        );
        expect(
          container
              .read(connectedTableProvider)
              .records
              .single
              .availableCapacity,
          150,
        );
        expect(
          container
              .read(connectedNurseryProvider)
              .records
              .single
              .remainingSeedCount,
          50,
        );
        await tester.ensureVisible(find.text('Selesai'));
        await tester.tap(find.text('Selesai'));
        await tester.pumpAndSettle();
        expect(
          fromList
              ? find.textContaining('50 Butir', findRichText: true)
              : find.text('50 Bibit'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      },
    );
  }
}
