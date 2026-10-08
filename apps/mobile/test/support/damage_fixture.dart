import 'dart:convert';
import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/repositories/damage_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> transferJson({String id = '1', int active = 200}) => {
  'id_pemindahan': id,
  'id_meja': '1',
  'id_penyemaian': '1',
  'tanggal_pemindahan': '2026-09-16',
  'jumlah_tanaman': 200,
  'tanaman_aktif': active,
};
Map<String, dynamic> damageJson({String id = '1', String transferId = '1'}) => {
  'id_kerusakan': id,
  'id_pemindahan': transferId,
  'tanggal_kejadian': '2026-09-20',
  'jumlah_tanaman': 5,
  'jenis_kerusakan': 'Busuk akar',
  'keterangan': null,
  'public_id': 'ed241e52-d67a-46d8-a23a-2dba1fb79390',
  'version': '1',
};
http.Response reply(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status);
http.Response pageReply(List<Object> rows, {int page = 1, int? total}) =>
    reply({
      'data': rows,
      'meta': {
        'page': page,
        'total': total ?? rows.length,
        'total_pages': ((total ?? rows.length) / 100).ceil(),
      },
    });
ApiClient apiFor(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');

const draft = DamageDraft(
  transferId: '1',
  date: '2026-09-20',
  plantCount: 5,
  category: 'Busuk akar',
);
const farmer = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: [
    'budidaya:read',
    'budidaya:write',
    'inventaris:read',
    'penyemaian:read',
    'penjualan:read',
    'penjualan:write',
  ],
);
const employee = SessionUser(
  id: '2',
  name: 'Pegawai',
  username: 'pegawai',
  role: 'pegawai',
  permissions: [
    'budidaya:read',
    'budidaya:write',
    'inventaris:read',
    'penyemaian:read',
  ],
);

class FakeDamageRepository extends DamageRepository {
  FakeDamageRepository(super.api);
  List<TransferRecord> transfers = [TransferRecord.fromJson(transferJson())];
  List<DamageRecord> reports = [];
  final keys = <String>[];
  final drafts = <DamageDraft>[];
  Object? loadError;
  Future<DamageRecord> Function(DamageDraft, String)? onCreate;
  Future<List<TransferRecord>> Function()? onList;
  @override
  Future<List<TransferRecord>> listTransfers(String tableId) async {
    if (loadError != null) throw loadError!;
    return onList != null ? onList!() : transfers;
  }

  @override
  Future<List<DamageRecord>> listDamages(String transferId) async => reports;
  @override
  Future<DamageRecord> createDamage(DamageDraft draft, String key) async {
    keys.add(key);
    drafts.add(draft);
    return onCreate != null
        ? onCreate!(draft, key)
        : DamageRecord.fromJson(damageJson());
  }
}
