import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/repositories/sales_repository.dart';
import 'package:http/http.dart' as http;

import 'support/sales_fixture.dart';

void main() {
  test('listSales reads every page and exposes strict detail totals', () async {
    final repo = SalesRepository(
      salesApi((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/penjualan');
        expect(request.url.queryParameters, {'page': '1', 'limit': '100'});
        return salePage([
          saleJson(
            id: '9',
            buyer: 'Supermarket Jaya',
            details: [
              saleDetailJson(
                id: '9',
                harvestId: '1',
                quantity: '5.00',
                price: '20000.00',
              ),
            ],
          ),
        ]);
      }),
    );

    final rows = await repo.listSales();
    expect(rows, hasLength(1));
    expect(rows.single.id, '9');
    expect(rows.single.buyer, 'Supermarket Jaya');
    expect(rows.single.quantity.wire, '5.00');
    expect(rows.single.total, 100000);
  });

  test(
    'createSale sends flat fields, exact amounts, and idempotency key',
    () async {
      const key = '1a9b0f9e-6e3c-4dc2-b3f1-2a8a2d8e6f01';
      final repo = SalesRepository(
        salesApi((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/penjualan');
          expect(request.headers['Idempotency-Key'], key);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['tanggal_penjualan'], '2026-09-25');
          expect(body['pembeli'], 'Resto Baru');
          expect(body['status_pembayaran'], 'lunas');
          expect(body['id_panen'], '1');
          expect(body['jumlah_kg'], '12.50');
          expect(body['harga_per_kg'], '20000.00');
          expect(body['keterangan'], isNull);
          return http.Response(
            jsonEncode({
              'data': saleJson(
                id: '10',
                date: '2026-09-25',
                buyer: 'Resto Baru',
                status: 'lunas',
                version: '1',
                details: [
                  saleDetailJson(
                    id: '10',
                    harvestId: '1',
                    quantity: '12.50',
                    price: '20000.00',
                  ),
                ],
              ),
            }),
            201,
          );
        }),
      );

      final record = await repo.createSale(
        const SalesDraft(
          date: '2026-09-25',
          buyer: 'Resto Baru',
          status: 'lunas',
          harvestId: '1',
          quantity: 12.5,
          price: 20000,
        ),
        key,
      );
      expect(record.id, '10');
      expect(record.version, '1');
      expect(record.total, 250000);
    },
  );

  test(
    'updateSale requires a new version and sends expected_version',
    () async {
      const key = '1a9b0f9e-6e3c-4dc2-b3f1-2a8a2d8e6f02';
      final repo = SalesRepository(
        salesApi((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/penjualan/10');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['expected_version'], '1');
          expect(body['jumlah_kg'], '15.00');
          return http.Response(
            jsonEncode({
              'data': saleJson(
                id: '10',
                date: '2026-09-25',
                buyer: 'Resto Baru',
                status: 'lunas',
                version: '2',
                details: [
                  saleDetailJson(
                    id: '10',
                    harvestId: '1',
                    quantity: '15.00',
                    price: '20000.00',
                  ),
                ],
              ),
            }),
            200,
          );
        }),
      );

      final record = await repo.updateSale(
        '10',
        const SalesDraft(
          date: '2026-09-25',
          buyer: 'Resto Baru',
          status: 'lunas',
          harvestId: '1',
          quantity: 15,
          price: 20000,
        ),
        '1',
        key,
      );
      expect(record.version, '2');
      expect(record.total, 300000);
    },
  );
}
