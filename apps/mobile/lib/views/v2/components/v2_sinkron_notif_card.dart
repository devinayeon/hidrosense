import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Kartu biru muda "Notifikasi mati" (frame 11.3).
///
/// Berbeda dari kartu Total di form penjualan (frame 8.7) yang menonjolkan
/// angka, kartu ini memakai judul 20/28 SemiBold dan satu kalimat badan 16/24,
/// jadi dibuat khusus halaman sinkron.
class V2SinkronNotifCard extends StatelessWidget {
  const V2SinkronNotifCard({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Komponen `Card` di frame 11.3 digambar 120 tinggi; isi teksnya hanya
      // 108, jadi sisa 12 di bawah dipertahankan lewat tinggi minimum.
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: V2Type.h2),
          const SizedBox(height: V2Space.sm),
          Text(body, style: V2Type.body.copyWith(color: V2Colors.secondary)),
        ],
      ),
    );
  }
}
