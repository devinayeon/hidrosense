import 'package:flutter/material.dart';
import 'package:hidrosense_mobile/views/widgets/row_info_card_md.dart';
import 'package:hidrosense_mobile/views/widgets/base_col_card.dart';
import 'package:hidrosense_mobile/views/widgets/top_info_content.dart';
import 'package:hidrosense_mobile/views/widgets/card_icon_box.dart';

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
            // Baris Pertama: Top Info Cards menggunakan BaseColCard
            Row(
              children: const [
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Color.fromRGBO(57, 198, 195, 1),
                    child: TopInfoContent(
                      topText: "Kapasitas NFT",
                      middleText: "12 Meja",
                      bottomText: "3000 Lubang",
                      textColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Color.fromRGBO(221, 244, 90, 1),
                    child: TopInfoContent(
                      topText: "Estimasi Panen",
                      middleText: "12 Des 2024",
                      bottomText: "~250 Kg Selada",
                    ),
                  ),
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
                children: const [
                  CardIconBox(
                    iconData: Icons.warning_amber_rounded,
                    backgroundColor: Color.fromRGBO(255, 154, 85, 1),
                    iconColor: Colors.white,
                  ),
                  SizedBox(width: 12),
                  Expanded(
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
                children: const [
                  CardIconBox(
                    iconData: Icons.cloudy_snowing,
                    backgroundColor: Color.fromRGBO(57, 198, 195, 1),
                    iconColor: Colors.white,
                  ),
                  SizedBox(width: 12),
                  Expanded(
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

            // Horizontal Scrollable Row untuk Quick Access menggunakan BaseColCard
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Quick Access 1: + Barang
                  BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(230, 230, 225, 1),
                    width: 102,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        CardIconBox(
                          iconData: Icons.add_circle_outline,
                          backgroundColor: Color.fromRGBO(57, 198, 195, 0.15),
                          iconColor: Color.fromRGBO(57, 198, 195, 1),
                          width: 40,
                          height: 40,
                          borderRadius: 14,
                          iconSize: 22,
                        ),
                        SizedBox(height: 8),
                        Text(
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

                  // Quick Access 2: + Semai
                  BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(230, 230, 225, 1),
                    width: 102,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        CardIconBox(
                          iconData: Icons.eco_outlined,
                          backgroundColor: Color.fromRGBO(221, 244, 90, 0.35),
                          iconColor: Colors.black87,
                          width: 40,
                          height: 40,
                          borderRadius: 14,
                          iconSize: 22,
                        ),
                        SizedBox(height: 8),
                        Text(
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

                  // Quick Access 3: Cek Stok
                  BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(230, 230, 225, 1),
                    width: 102,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        CardIconBox(
                          iconData: Icons.view_in_ar_outlined,
                          backgroundColor: Color.fromRGBO(57, 198, 195, 0.15),
                          iconColor: Color.fromRGBO(57, 198, 195, 1),
                          width: 40,
                          height: 40,
                          borderRadius: 14,
                          iconSize: 22,
                        ),
                        SizedBox(height: 8),
                        Text(
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
          ],
        ),
      ),
    );
  }
}