import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../pages/form_meja_nft_page.dart';
import '../pages/info_meja_page.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/fluid_capacity_meter.dart';

class MejaNftBody extends ConsumerWidget {
  const MejaNftBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedTableProvider);
    final notifier = ref.read(connectedTableProvider.notifier);
    final counts = state.counts;
    final filteredList = state.filtered;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomSearchBar(
                placeholder: 'Cari meja tanam...',
                onChanged: (value) => notifier.setSearchQuery(value),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    FilterButton(
                      label: 'Semua (${counts['total']})',
                      isSelected: state.statusFilter == null,
                      onTap: () => notifier.setStatusFilter(null),
                    ),
                    const SizedBox(width: 8),
                    FilterButton(
                      label: 'Aktif (${counts['aktif']})',
                      isSelected: state.statusFilter == 'tersedia',
                      onTap: () => notifier.setStatusFilter('tersedia'),
                    ),
                    const SizedBox(width: 8),
                    FilterButton(
                      label: 'Perawatan (${counts['perawatan']})',
                      isSelected: state.statusFilter == 'pemeliharaan',
                      onTap: () => notifier.setStatusFilter('pemeliharaan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (state.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: CircularProgressIndicator(
                      color: Color.fromRGBO(57, 198, 195, 1),
                    ),
                  ),
                )
              else if (filteredList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  child: Center(
                    child: Text(
                      state.error != null && state.records.isEmpty
                          ? 'Data meja tanam belum dapat dimuat.'
                          : state.records.isEmpty
                              ? 'Belum ada meja tanam terdaftar.'
                              : 'Meja tanam tidak ditemukan.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color.fromRGBO(156, 163, 175, 1),
                      ),
                    ),
                  ),
                )
              else
                ...filteredList.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: RowInfoCardMd(
                      backgroundColor: Colors.white,
                      borderColor: const Color.fromRGBO(229, 231, 235, 1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InfoMejaPage(tableRecord: item),
                          ),
                        );
                      },
                      child: _ConnectedTableCardContent(item: item),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              RowButton(
                label: '+ Tambah Meja NFT Baru',
                backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                textColor: const Color.fromRGBO(221, 244, 90, 1),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FormMejaNftPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectedTableCardContent extends StatelessWidget {
  final TableRecord item;
  const _ConnectedTableCardContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final isMaintenance = item.isMaintenance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item.displayName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.black,
              ),
            ),
            CapsuleBadge(
              label: item.statusLabel,
              textColor: isMaintenance
                  ? const Color.fromRGBO(217, 119, 6, 1)
                  : const Color.fromRGBO(2, 132, 199, 1),
              backgroundColor: isMaintenance
                  ? const Color.fromRGBO(254, 243, 199, 1)
                  : const Color.fromRGBO(224, 242, 254, 1),
              size: CapsuleSize.small,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isMaintenance) ...[
          FluidCapacityMeter(
            activePlants: item.activePlants,
            totalCapacity: item.holeCount,
            height: 6.0,
            showLabel: false,
            compact: true,
          ),
          const SizedBox(height: 6),
          Text(
            'Kapasitas: ${item.activePlants} / ${item.holeCount} Lubang Terisi (${item.occupancyPercentage}%)',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color.fromRGBO(107, 114, 128, 1),
            ),
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.notes!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color.fromRGBO(156, 163, 175, 1),
              ),
            ),
          ],
        ] else ...[
          Text(
            'Dalam Perawatan / Pemeliharaan',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color.fromRGBO(107, 114, 128, 1),
            ),
          ),
        ],
      ],
    );
  }
}
