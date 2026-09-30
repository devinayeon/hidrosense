import 'package:flutter/material.dart';
import 'package:hidrosense_mobile/views/widgets/row_info_card_md.dart';
import 'package:hidrosense_mobile/views/widgets/col_info_card_sm.dart';
import '../widgets/info_card_md.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

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
            // Baris Pertama: 2 InfoCardMd bersebelahan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                InfoCardMd(
                  backgroundColor: Color.fromRGBO(57, 198, 195, 1),
                  topText: "Kapasitas NFT",
                  middleText: "12 Meja",
                  bottomText: "3000 Lubang",
                  textColor: Colors.white,
                ),
                InfoCardMd(
                  backgroundColor: Color.fromRGBO(221, 244, 90, 1),
                  topText: "Estimasi Panen",
                  middleText: "12 Des 2024",
                  bottomText: "~250 Kg Selada",
                ),
              ],
            ),

            const SizedBox(height: 16),

            // RowInfoCardMd 1: Icon Exclamation Mark Segitiga (Peringatan)
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(255, 243, 236, 1),
              borderColor: const Color.fromRGBO(255, 154, 85, 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(255, 154, 85, 1),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semaian Siap Pindah',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.0,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Batch #04 (Selada Grand Rapids) mencapai 14 HSS.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            height: 1.0,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // RowInfoCardMd 2: Icon Awan Hujan (Cuaca)
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(240, 251, 251, 1),
              borderColor: const Color.fromRGBO(57, 198, 195, 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(57, 198, 195, 1),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: const Icon(
                      Icons.cloudy_snowing,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuaca BMKG (Sore)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.0,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hujan Ringan, 28°C. Atur debit nutrisi meja NFT.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            height: 1.0,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'AKSES CEPAT',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.0,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // Horizontal Scrollable Row untuk ColInfoCardSm
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Card 1: + Barang
                  ColInfoCardSm(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(230, 230, 225, 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(57, 198, 195, 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.add_circle_outline, // Non-filled plus dengan lingkaran
                            color: Color.fromRGBO(57, 198, 195, 1),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '+ Barang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1.0,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Card 2: + Semai
                  ColInfoCardSm(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(230, 230, 225, 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(221, 244, 90, 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.eco_outlined, // Non-filled icon daun
                            color: Colors.black87,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '+ Semai',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1.0,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Card 3: Cek Stok
                  ColInfoCardSm(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(230, 230, 225, 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(57, 198, 195, 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.view_in_ar_outlined, // Non-filled icon kubus 3D
                            color: Color.fromRGBO(57, 198, 195, 1),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cek Stok',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1.0,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}