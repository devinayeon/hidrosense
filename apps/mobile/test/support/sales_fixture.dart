import 'dart:convert';

import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/repositories/sales_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const salePublicId = '79464d5b-b494-48a5-9727-7b2b13dc4e35';

ApiClient salesApi(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');

Map<String, dynamic> saleDetailJson({
  String id = '1',
  String harvestId = '2',
  String harvestDate = '2026-09-20',
  String quantity = '1.00',
  String price = '20000.00',
  String? saleable = '50.00',
}) {
  final total = (double.parse(quantity) * double.parse(price)).toStringAsFixed(
    2,
  );
  return {
    'id_detail_penjualan': id,
    'id_panen': harvestId,
    'tanggal_panen': harvestDate,
    'berat_layak': saleable,
    'jumlah_kg': quantity,
    'harga_per_kg': price,
    'total_harga': total,
  };
}

Map<String, dynamic> saleJson({
  String id = '1',
  String userId = '1',
  String date = '2026-09-25',
  String buyer = 'Supermarket Jaya',
  String status = 'lunas',
  String? note,
  String version = '1',
  List<Map<String, dynamic>>? details,
}) => {
  'id_penjualan': id,
  'id_user': userId,
  'tanggal_penjualan': date,
  'pembeli': buyer,
  'status_pembayaran': status,
  'keterangan': note,
  'public_id': salePublicId,
  'version': version,
  'details': details ?? [saleDetailJson()],
};

Map<String, dynamic> saleHarvestJson({
  String id = '1',
  String date = '2026-09-20',
  String layak = '100.00',
  String transferId = '1',
  int count = 50,
}) => {
  'id_panen': id,
  'id_user': '1',
  'tanggal_panen': date,
  'keterangan': 'panen',
  'version': '1',
  'public_id': 'ed241e52-d67a-46d8-a23a-2dba1fb79390',
  'berat_total': layak,
  'berat_reject': '0.00',
  'berat_layak': layak,
  'details': [
    {
      'id_detail_panen': id,
      'id_pemindahan': transferId,
      'id_meja': '1',
      'kode_meja': 'NFT-01',
      'tanggal_semai': '2026-08-26',
      'tanggal_pemindahan': '2026-09-16',
      'jumlah_tanaman': count,
      'berat_total': layak,
      'berat_reject': '0.00',
      'berat_layak': layak,
    },
  ],
};

HarvestRecord saleHarvest({
  String id = '1',
  String date = '2026-09-20',
  String layak = '100.00',
  String transferId = '1',
  int count = 50,
}) => HarvestRecord.fromJson(
  saleHarvestJson(
    id: id,
    date: date,
    layak: layak,
    transferId: transferId,
    count: count,
  ),
);

SaleRecord saleRecord({
  String id = '1',
  String userId = '1',
  String date = '2026-09-25',
  String buyer = 'Supermarket Jaya',
  String status = 'lunas',
  String? note,
  String version = '1',
  List<Map<String, dynamic>>? details,
}) => SaleRecord.fromJson(
  saleJson(
    id: id,
    userId: userId,
    date: date,
    buyer: buyer,
    status: status,
    note: note,
    version: version,
    details: details,
  ),
);

http.Response salePage(List<Object> rows, {int page = 1, int? total}) =>
    http.Response(
      jsonEncode({
        'data': rows,
        'meta': {
          'page': page,
          'limit': 100,
          'total': total ?? rows.length,
          'total_pages': ((total ?? rows.length) / 100).ceil(),
        },
      }),
      200,
    );

class FakeSalesRepository extends SalesRepository {
  FakeSalesRepository(super.api);

  List<SaleRecord> records = [];
  Object? loadError, writeError;
  Future<List<SaleRecord>> Function()? onList;
  final drafts = <SalesDraft>[];
  final headerDrafts = <SalesHeaderDraft>[];
  final keys = <String>[];
  final updateKeys = <String>[];
  final headerUpdateKeys = <String>[];
  int listReads = 0;

  @override
  Future<List<SaleRecord>> listSales() async {
    listReads++;
    if (loadError != null) throw loadError!;
    final handler = onList;
    if (handler != null) return handler();
    return List.unmodifiable(records);
  }

  @override
  Future<SaleRecord> getSale(String id) async {
    return records.firstWhere((record) => record.id == id);
  }

  @override
  Future<SaleRecord> createSale(SalesDraft draft, String key) async {
    if (writeError != null) throw writeError!;
    drafts.add(draft);
    keys.add(key);
    final next =
        records
            .map((record) => BigInt.parse(record.id))
            .fold(BigInt.zero, (a, b) => a > b ? a : b) +
        BigInt.one;
    final record = SaleRecord.fromJson(
      saleJson(
        id: next.toString(),
        date: draft.date,
        buyer: draft.buyer,
        status: draft.status,
        note: draft.note,
        version: '1',
        details: [
          saleDetailJson(
            id: next.toString(),
            harvestId: draft.harvestId,
            quantity: draft.quantityWire,
            price: draft.priceWire,
          ),
        ],
      ),
    );
    records = [record, ...records];
    return record;
  }

  @override
  Future<SaleRecord> updateSale(
    String id,
    SalesDraft draft,
    String expectedVersion,
    String key,
  ) async {
    if (writeError != null) throw writeError!;
    drafts.add(draft);
    updateKeys.add(key);
    final previous = records.firstWhere((record) => record.id == id);
    final record = SaleRecord.fromJson(
      saleJson(
        id: id,
        date: draft.date,
        buyer: draft.buyer,
        status: draft.status,
        note: draft.note,
        version: '${BigInt.parse(expectedVersion) + BigInt.one}',
        details: [
          saleDetailJson(
            id: previous.details.first.id,
            harvestId: draft.harvestId,
            quantity: draft.quantityWire,
            price: draft.priceWire,
          ),
        ],
      ),
    );
    records = [record, ...records.where((sale) => sale.id != id)];
    return record;
  }

  @override
  Future<SaleRecord> updateSaleHeader(
    String id,
    SalesHeaderDraft draft,
    String expectedVersion,
    String key,
  ) async {
    if (writeError != null) throw writeError!;
    headerDrafts.add(draft);
    headerUpdateKeys.add(key);
    final previous = records.firstWhere((record) => record.id == id);
    final record = SaleRecord(
      id: previous.id,
      userId: previous.userId,
      date: draft.date,
      buyer: draft.buyer,
      status: draft.status,
      note: draft.note,
      version: '${BigInt.parse(expectedVersion) + BigInt.one}',
      publicId: previous.publicId,
      details: previous.details,
    );
    records = [record, ...records.where((sale) => sale.id != id)];
    return record;
  }
}
