// lib/views/components/laporan_panen_body.dart
import 'package:flutter/material.dart';
import '../../models/panen_model.dart';
import '../pages/panen_form_page.dart';
import '../widgets/base_col_card.dart';
import '../widgets/col_button.dart';
import '../widgets/row_info_card_md.dart';

class LaporanPanenBody extends StatelessWidget {
  final PanenItem item;

  const LaporanPanenBody({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Title Header Laporan Panen
            Text(
              'Laporan Panen - ${item.batchName}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color.fromRGBO(23, 34, 49, 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selesai diproses pada ${item.processedDate}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Row Info Cards (Total Berat Hasil & Rasio Layak/Reject)
            Row(
              children: [
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(240, 240, 235, 1),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Berat Hasil',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.totalWeight,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Color.fromRGBO(23, 34, 49, 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Target: ${item.targetWeight}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(240, 240, 235, 1),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rasio Layak/Reject',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.layakPercent} / ${item.rejectPercent}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Color.fromRGBO(34, 139, 34, 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reject: ${item.rejectWeight}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Section Informas Produksi & Penjualan
            const Text(
              'INFORMASI PRODUKSI & PENJUALAN',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 12),

            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(240, 240, 235, 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  _buildDetailRow('Asal Meja Tanam:', item.asalMejaTanam),
                  const SizedBox(height: 12),
                  _buildDetailRow('Varietas Tanaman:', item.varietas),
                  const SizedBox(height: 12),
                  _buildDetailRow('Lama Budidaya (HSS):', item.lamaBudidaya),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Grade Kualitas Utama:',
                    item.gradeKualitas,
                    valueColor: const Color.fromRGBO(34, 139, 34, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 4. Action Buttons (Edit Laporan & Ekspor ke PDF)
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Edit Laporan',
                    textColor: const Color.fromRGBO(57, 198, 195, 1),
                    borderColor: const Color.fromRGBO(57, 198, 195, 1),
                    backgroundColor: Colors.white,
                    height: 48,
                    borderRadius: 24,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PanenFormPage(itemToEdit: item),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ColButton(
                    text: 'Ekspor ke PDF',
                    textColor: Colors.white,
                    borderColor: const Color.fromRGBO(57, 198, 195, 1),
                    backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
                    height: 48,
                    borderRadius: 24,
                    onPressed: () {
                      // Action Ekspor ke PDF
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 13,
            color: Color.fromRGBO(107, 114, 128, 1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: valueColor ?? const Color.fromRGBO(23, 34, 49, 1),
            ),
          ),
        ),
      ],
    );
  }
}
