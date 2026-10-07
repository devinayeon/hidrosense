import 'package:flutter/material.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../pages/form_meja_nft_page.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/fluid_capacity_meter.dart';

class InfoMejaBody extends StatelessWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const InfoMejaBody({super.key, this.tableRecord, this.mejaItem})
    : assert(tableRecord != null || mejaItem != null);

  @override
  Widget build(BuildContext context) {
    final title = tableRecord?.displayName ?? mejaItem!.name;
    final totalCapacity = tableRecord?.holeCount ?? mejaItem!.capacityTotal;
    final activePlants = tableRecord?.activePlants ?? mejaItem!.capacityUsed;
    final isMaintenance =
        tableRecord?.isMaintenance ??
        (mejaItem!.status == MejaStatus.perawatan);
    final statusLabel =
        tableRecord?.statusLabel ?? (isMaintenance ? 'Perawatan' : 'Aktif');
    final notes =
        tableRecord?.notes ??
        mejaItem?.notes ??
        'Tidak ada catatan spesifikasi khusus.';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color.fromRGBO(23, 34, 49, 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sistem NFT • Status: $statusLabel',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color.fromRGBO(156, 163, 175, 1),
              ),
            ),
            const SizedBox(height: 16),
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(240, 240, 235, 1),
              padding: const EdgeInsets.all(16),
              child: FluidCapacityMeter(
                activePlants: activePlants,
                totalCapacity: totalCapacity,
                height: 12.0,
                showLabel: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CATATAN & SPESIFIKASI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 8),
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(240, 240, 235, 1),
              padding: const EdgeInsets.all(16),
              child: Text(
                notes,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color.fromRGBO(55, 65, 81, 1),
                ),
              ),
            ),
            const SizedBox(height: 24),
            RowButton(
              label: 'Edit Pengaturan Meja',
              backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
              textColor: const Color.fromRGBO(221, 244, 90, 1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormMejaNftPage(
                      tableRecord: tableRecord,
                      mejaItem: mejaItem,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
