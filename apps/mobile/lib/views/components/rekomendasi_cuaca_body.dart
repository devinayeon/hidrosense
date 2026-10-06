import 'package:flutter/material.dart';
import '../../models/weather_model.dart';
import '../widgets/base_col_card.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/row_info_card_md.dart';

class RekomendasiCuacaBody extends StatelessWidget {
  final PrakiraanHarian item;

  const RekomendasiCuacaBody({super.key, required this.item});

  // @style
  @override
  Widget build(BuildContext context) {
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
            // 1. Top Card: Rekomendasi Berbasis Cuaca
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(240, 251, 251, 1),
              borderColor: const Color.fromRGBO(57, 198, 195, 1),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardIconBox(
                    iconData: Icons.cloud_outlined,
                    backgroundColor: Color.fromRGBO(57, 198, 195, 1),
                    iconColor: Colors.white,
                    width: 44,
                    height: 44,
                    borderRadius: 14,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rekomendasi Berbasis Cuaca',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.ringkasanSaran,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.3,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Section Header
            const Text(
              'TINDAKAN REKOMENDASI HARI INI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color.fromRGBO(57, 198, 195, 1),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // 3. List Cards Rekomendasi
            ...item.rekomendasiList.map((rec) {
              final isPenting = rec.isPenting;
              final tagBgColor = isPenting
                  ? const Color.fromRGBO(255, 243, 236, 1)
                  : const Color.fromRGBO(240, 251, 251, 1);
              final tagTextColor = isPenting
                  ? const Color.fromRGBO(255, 154, 85, 1)
                  : const Color.fromRGBO(57, 198, 195, 1);
              final tagBorderColor = isPenting
                  ? const Color.fromRGBO(255, 154, 85, 1)
                  : const Color.fromRGBO(57, 198, 195, 1);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: BaseColCard(
                  backgroundColor: Colors.white,
                  borderColor: const Color.fromRGBO(230, 230, 225, 1),
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              rec.judul,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CapsuleBadge(
                            label: rec.labelTag,
                            textColor: tagTextColor,
                            backgroundColor: tagBgColor,
                            borderColor: tagBorderColor,
                            size: CapsuleSize.medium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rec.deskripsi,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rec.alasan,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          height: 1.3,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // 4. Disclaimer Footer
            const Text(
              'Disclaimer: Saran otomatis sistem berdasarkan analisis cuaca lokal & usia tanaman terkini. Modifikasi sesuai pengamatan visual lapangan petani.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                fontSize: 11,
                height: 1.3,
                color: Colors.black38,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
