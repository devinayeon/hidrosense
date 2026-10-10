import 'dart:convert';
import 'package:hidrosense_mobile/data/models/harvest_draft.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/repositories/harvest_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> harvestJson({
  String id = '1',
  String version = '1',
  bool legacy = false,
  String? note,
  String total = '2.50',
  String reject = '0.25',
  String layak = '2.25',
  String transferId = '1',
  int count = 5,
}) => {
  'id_panen': id,
  'id_user': '1',
  'tanggal_panen': '2026-10-10',
  'keterangan': note,
  'version': version,
  'public_id': '79464d5b-b494-48a5-9727-7b2b13dc4e35',
  'berat_total': legacy ? null : total,
  'berat_reject': legacy ? null : reject,
  'berat_layak': layak,
  'details': [
    {
      'id_detail_panen': '1',
      'id_pemindahan': transferId,
      'id_meja': '1',
      'kode_meja': 'NFT-01',
      'tanggal_semai': '2026-08-26',
      'tanggal_pemindahan': '2026-09-16',
      'jumlah_tanaman': count,
      'berat_total': legacy ? null : total,
      'berat_reject': legacy ? null : reject,
      'berat_layak': layak,
    },
  ],
};
Map<String, dynamic> harvestTransferJson({String id = '1', int active = 200}) =>
    {
      'id_pemindahan': id,
      'id_meja': '1',
      'id_penyemaian': '1',
      'tanggal_pemindahan': '2026-09-16',
      'tanggal_semai': '2026-08-26',
      'jumlah_tanaman': 200,
      'tanaman_aktif': active,
      'hss': 45,
      'hst': 24,
      'estimasi_panen': '2026-10-10',
      'sisa_hari_panen': 0,
    };
http.Response harvestReply(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status);
http.Response harvestPage(List<Object> rows, {int page = 1, int? total}) =>
    harvestReply({
      'data': rows,
      'meta': {
        'page': page,
        'limit': 100,
        'total': total ?? rows.length,
        'total_pages': ((total ?? rows.length) / 100).ceil(),
      },
    });
ApiClient harvestApi(
  Future<http.Response> Function(http.Request) handler, {
  String server = 'example.test',
}) =>
    ApiClient(MockClient(handler), baseUri: Uri.parse('https://$server/api/v1'))
      ..setTokens(accessToken: 'access', refreshToken: 'refresh');
const harvestDraft = HarvestDraft(
  date: '2026-10-10',
  rows: [
    HarvestDraftRow(
      transferId: '1',
      plantCount: 5,
      total: '2,50',
      reject: '0.25',
    ),
  ],
);
const harvestUser = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['panen:read', 'panen:write', 'budidaya:read', 'budidaya:write'],
);

class FakeHarvestRepository extends HarvestRepository {
  FakeHarvestRepository(super.api);
  List<HarvestRecord> records = [];
  List<TransferRecord> transfers = [
    TransferRecord.fromJson(harvestTransferJson()),
  ];
  final keys = <String>[], targets = <String>[];
  final bodies = <Map<String, dynamic>>[];
  Object? readError, detailError;
  Future<HarvestRecord> Function(String)? onDetail;
  int harvestReads = 0, transferReads = 0;
  Future<List<HarvestRecord>> Function()? onRead;
  Future<HarvestRecord> Function(String, Map<String, dynamic>, String)? onWrite;
  @override
  Future<List<HarvestRecord>> listHarvests() async {
    harvestReads++;
    if (readError != null) throw readError!;
    return onRead == null ? records : await onRead!();
  }

  @override
  Future<List<TransferRecord>> listTransfers() async {
    transferReads++;
    return transfers;
  }

  @override
  Future<HarvestRecord> getHarvest(String id) async {
    if (detailError != null) throw detailError!;
    return onDetail == null
        ? records.firstWhere((r) => r.id == id)
        : await onDetail!(id);
  }

  @override
  Future<HarvestRecord> write(
    String target,
    Map<String, dynamic> body,
    String key,
  ) async {
    keys.add(key);
    targets.add(target);
    bodies.add(body);
    if (onWrite != null) return onWrite!(target, body, key);
    final record = HarvestRecord.fromJson(
      harvestJson(
        id: target == 'create' ? '${keys.length}' : target,
        version: target == 'create'
            ? '1'
            : '${BigInt.parse(body['expected_version']) + BigInt.one}',
        note: body['keterangan'],
      ),
    );
    records = [record, ...records.where((r) => r.id != record.id)];
    return record;
  }
}

PanenViewModel harvestVm(
  FakeHarvestRepository repo, {
  HarvestCommands? commands,
  String userId = '1',
  bool canWrite = true,
  bool canReadBatches = true,
  Future<void> Function(Set<String>)? tables,
}) => PanenViewModel(
  repo,
  tables ?? (_) async {},
  canWrite: canWrite,
  canReadBatches: canReadBatches,
  userId: userId,
  autoLoad: false,
  commands: commands,
  clock: () => DateTime.utc(2026, 10, 10),
);
Future<FakeHarvestRepository> loadedRepo() async =>
    FakeHarvestRepository(harvestApi((_) async => harvestPage([])));
