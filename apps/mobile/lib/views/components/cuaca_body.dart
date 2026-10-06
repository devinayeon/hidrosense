import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/weather_viewmodel.dart';
import '../pages/rekomendasi_cuaca_page.dart';
import '../widgets/base_col_card.dart';
import '../widgets/capsule_badge.dart';

class CuacaBody extends ConsumerWidget {
  const CuacaBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherViewModelProvider);

    if (weatherState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color.fromRGBO(57, 198, 195, 1),
        ),
      );
    }

    if (weatherState.errorMessage != null) {
      return Center(
        child: Text(
          weatherState.errorMessage!,
          style: const TextStyle(fontFamily: 'Inter', color: Colors.redAccent),
        ),
      );
    }

    final data = weatherState.data;
    if (data == null) return const SizedBox.shrink();

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
            // 1. Header Banner Lokasi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(57, 198, 195, 1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.south_west_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data.lokasi,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.kota,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.sumber,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Grid 2x2 Info Cuaca Utama
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Suhu Udara',
                    value: '${data.suhu}°C',
                    badgeLabel: data.statusSuhu,
                    badgeBgColor: const Color.fromRGBO(240, 251, 251, 1),
                    badgeTextColor: const Color.fromRGBO(57, 198, 195, 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kelembapan',
                    value: '${data.kelembapan}%',
                    badgeLabel: data.statusKelembapan,
                    badgeBgColor: const Color.fromRGBO(255, 243, 236, 1),
                    badgeTextColor: const Color.fromRGBO(255, 154, 85, 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Curah Hujan',
                    value: data.curahHujan,
                    subtitle: data.estimasiHujan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kecepatan Angin',
                    value: '${data.kecepatanAngin} Km/Jam',
                    subtitle: data.arahAngin,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Section Prakiraan Harian Lokal (Bisa di-klik)
            const Text(
              'PRAKIRAAN HARIAN LOKAL',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),

            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(230, 230, 225, 1),
              padding: EdgeInsets.zero, // Padding diatur per baris item
              child: Column(
                children: List.generate(data.prakiraanHarian.length, (index) {
                  final item = data.prakiraanHarian[index];
                  final isLast = index == data.prakiraanHarian.length - 1;

                  return Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.vertical(
                            top: index == 0
                                ? const Radius.circular(20)
                                : Radius.zero,
                            bottom: isLast
                                ? const Radius.circular(20)
                                : Radius.zero,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RekomendasiCuacaPage(prakiraanItem: item),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.waktu,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                Row(
                                  children: [
                                    CapsuleBadge(
                                      label: '${item.status} • ${item.suhu}°C',
                                      textColor: item.status.contains('Hujan')
                                          ? const Color.fromRGBO(
                                              57,
                                              198,
                                              195,
                                              1,
                                            )
                                          : Colors.black,
                                      backgroundColor:
                                          item.status.contains('Hujan')
                                          ? const Color.fromRGBO(
                                              240,
                                              251,
                                              251,
                                              1,
                                            )
                                          : const Color.fromRGBO(
                                              254,
                                              250,
                                              224,
                                              1,
                                            ),
                                      size: CapsuleSize.medium,
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: Colors.black38,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color.fromRGBO(240, 240, 235, 1),
                        ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Status Indicator API BMKG
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(230, 230, 225, 1),
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(57, 198, 195, 1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Data Diperbarui: ${data.lastUpdated}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: Colors.black54,
                      ),
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

  // Helper Widget Card Metrik
  Widget _buildMetricCard({
    required String title,
    required String value,
    String? badgeLabel,
    Color? badgeBgColor,
    Color? badgeTextColor,
    String? subtitle,
  }) {
    return BaseColCard(
      backgroundColor: Colors.white,
      borderColor: const Color.fromRGBO(230, 230, 225, 1),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          if (badgeLabel != null)
            CapsuleBadge(
              label: badgeLabel,
              textColor: badgeTextColor ?? Colors.black,
              backgroundColor: badgeBgColor ?? Colors.grey.shade200,
              size: CapsuleSize.medium,
            ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: Colors.black45,
              ),
            ),
        ],
      ),
    );
  }
}
