import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/uuid.dart';
import '../data/models/sale_record.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/api_client.dart';
import '../models/penjualan_model.dart';

/// Target perintah untuk penjualan baru; untuk koreksi, targetnya id penjualan.
const saleCreateTarget = 'create';

/// Satu tulis penjualan beserta kuncinya. Disimpan sebelum dikirim, supaya
/// formulir yang dibuka ulang tidak mengirim isian yang sama dengan kunci baru.
class SaleCommand {
  SaleCommand({
    required this.target,
    required this.payload,
    required this.write,
    this.draft,
    this.headerDraft,
    this.oldItem,
  }) : key = generateUuidV4();

  final String target, payload, key;
  final SalesDraft? draft;
  final SalesHeaderDraft? headerDraft;

  /// Baris sebelum dikoreksi, untuk menghitung ulang stok setelah kirim ulang.
  final PenjualanItem? oldItem;
  final Future<SaleRecord> Function(SalesRepository sales, String key) write;

  /// True setelah kiriman gagal tanpa jawaban yang pasti: penjualan itu mungkin
  /// sudah tersimpan. Selama kiriman pertama berjalan, nilainya masih false.
  bool uncertain = false;

  /// Pesan untuk formulir lain: transaksi mana yang tertahan dan cara melepasnya.
  String get blockedMessage {
    final buyer = draft?.buyer ?? headerDraft?.buyer ?? '';
    return target == saleCreateTarget
        ? 'Penjualan untuk $buyer mungkin sudah tersimpan. Buka formulir '
              'Catat Penjualan dan kirim ulang dulu, atau buang isiannya.'
        : 'Perubahan penjualan untuk $buyer mungkin sudah tersimpan. Buka '
              'transaksi itu dan kirim ulang dulu, atau buang isiannya.';
  }
}

typedef SaleCommandScope = (String server, String userId);

// Sengaja tanpa autoDispose: pindah tab membuang view model penjualan, dan
// kuncinya harus tetap ada supaya pengiriman ulang tidak mencatat dua kali.
final saleCommandsProvider = Provider(
  (ref) => <SaleCommandScope, SaleCommand>{},
);

/// Ditolak di aplikasi, sebelum terkirim: isian lain bisa menjadi penjualan kedua.
ApiException saleBlockedError(SaleCommand pending) =>
    ApiException(409, 'SALE_RESULT_UNCERTAIN', pending.blockedMessage);
