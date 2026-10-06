// lib/views/components/dashboard_body.dart
import 'package:flutter/material.dart';
import 'package:hidrosense_mobile/views/widgets/row_info_card_md.dart';
import 'package:hidrosense_mobile/views/widgets/base_col_card.dart';
import 'package:hidrosense_mobile/views/widgets/top_info_content.dart';
import 'package:hidrosense_mobile/views/widgets/card_icon_box.dart';
import '../pages/cuaca_page.dart';
import '../pages/meja_nft_page.dart';
import '../pages/panen_page.dart';
import '../pages/penjualan_page.dart'; // Import halaman baru

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  // Data List untuk RowInfoCardMd (Peringatan, Cuaca, dll)
  final List<Map<String, dynamic>> _infoCardsData = const [
    {
      'title': 'Semaian Siap Pindah',
      'subtitle': 'Batch #04 (Selada Grand Rapids) mencapai 14 HSS.',
      'bgColor': Color.fromRGBO(255, 243, 236, 1),
      'borderColor': Color.fromRGBO(255, 154, 85, 1),
      'iconData': Icons.warning_amber_rounded,
      'iconBgColor': Color.fromRGBO(255, 154, 85, 1),
      'iconColor': Colors.white,
    },
    {
      'title': 'Cuaca BMKG (Sore)',
      'subtitle': 'Hujan Ringan, 28°C. Atur debit nutrisi meja NFT.',
      'bgColor': Color.fromRGBO(240, 251, 251, 1),
      'borderColor': Color.fromRGBO(57, 198, 195, 1),
      'iconData': Icons.cloudy_snowing,
      'iconBgColor': Color.fromRGBO(57, 198, 195, 1),
      'iconColor': Colors.white,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Data List Akses Cepat ditaruh di dalam build agar bisa mengakses context navigasi
    final List<Map<String, dynamic>> quickAccessData = [
      {
        'title': '+ Barang',
        'iconData': Icons.add_circle_outline,
        'iconBgColor': const Color.fromRGBO(57, 198, 195, 0.15),
        'iconColor': const Color.fromRGBO(57, 198, 195, 1),
        'onTap': () {
          // Action untuk + Barang
        },
      },
      {
        'title': '+ Semai',
        'iconData': Icons.eco_outlined,
        'iconBgColor': const Color.fromRGBO(221, 244, 90, 0.35),
        'iconColor': Colors.black87,
        'onTap': () {
          // Action untuk + Semai
        },
      },
      {
        'title': 'Cuaca',
        'iconData': Icons.cloud_outlined,
        'iconBgColor': const Color.fromRGBO(57, 198, 195, 0.15),
        'iconColor': const Color.fromRGBO(57, 198, 195, 1),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CuacaPage()),
          );
        },
      },
      {
        'title': 'Penjualan', // MENU BARU PENJUALAN
        'iconData': Icons.point_of_sale_outlined,
        'iconBgColor': const Color.fromRGBO(57, 198, 195, 0.15),
        'iconColor': const Color.fromRGBO(57, 198, 195, 1),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PenjualanPage()),
          );
        },
      },
      {
        'title': 'Panen', // MENU BARU PANEN
        'iconData': Icons.agriculture_outlined,
        'iconBgColor': const Color.fromRGBO(57, 198, 195, 0.15),
        'iconColor': const Color.fromRGBO(57, 198, 195, 1),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PanenPage()),
          );
        },
      },
      {
        'title': 'Meja NFT',
        'iconData': Icons.table_restaurant_outlined,
        'iconBgColor': const Color.fromRGBO(57, 198, 195, 0.15),
        'iconColor': const Color.fromRGBO(57, 198, 195, 1),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MejaNftPage()),
          );
        },
      },
      {
        'title': 'Cek Stok',
        'iconData': Icons.view_in_ar_outlined,
        'iconBgColor': const Color.fromRGBO(57, 198, 195, 0.15),
        'iconColor': const Color.fromRGBO(57, 198, 195, 1),
        'onTap': () {
          // Action untuk Cek Stok
        },
      },
    ];

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
            // Baris Pertama: Top Info Cards (Kapasitas NFT & Estimasi Panen)
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

            // Loop untuk RowInfoCardMd (Informasi/Peringatan)
            ..._infoCardsData.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RowInfoCardMd(
                  backgroundColor: item['bgColor'],
                  borderColor: item['borderColor'],
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CardIconBox(
                        iconData: item['iconData'],
                        backgroundColor: item['iconBgColor'],
                        iconColor: item['iconColor'],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'],
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.0,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['subtitle'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
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
              );
            }),

            const SizedBox(height: 4),

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

            // Horizontal Scrollable Row & Loop untuk Akses Cepat (Quick Access)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: quickAccessData.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: InkWell(
                      onTap: item['onTap'],
                      borderRadius: BorderRadius.circular(16),
                      child: BaseColCard(
                        backgroundColor: Colors.white,
                        borderColor: const Color.fromRGBO(230, 230, 225, 1),
                        width: 102,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CardIconBox(
                              iconData: item['iconData'],
                              backgroundColor: item['iconBgColor'],
                              iconColor: item['iconColor'],
                              width: 40,
                              height: 40,
                              borderRadius: 14,
                              iconSize: 22,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
