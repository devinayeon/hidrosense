// lib/views/components/meja_nft_body.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/meja_nft_viewmodel.dart'; // Hanya perlukan ini
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/meja_nft_card_content.dart';

class MejaNftBody extends ConsumerWidget {
  const MejaNftBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX: Gunakan filteredMejaNftListProvider, bukan filteredSeedingListProvider
    final filteredList = ref.watch(filteredMejaNftListProvider);
    final counts = ref.watch(mejaCountProvider);
    final activeFilter = ref.watch(mejaFilterCategoryProvider);

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
            // 1. Search Bar
            CustomSearchBar(
              placeholder: 'Cari meja tanam...',
              onChanged: (value) {
                ref.read(mejaSearchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 14),

            // 2. Filter Tab Badges (Semua, Aktif, Perawatan)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  FilterButton(
                    label: 'Semua (${counts['total']})',
                    isSelected: activeFilter == null,
                    onTap: () {
                      ref.read(mejaFilterCategoryProvider.notifier).state =
                          null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterButton(
                    label: 'Aktif (${counts['aktif']})',
                    isSelected: activeFilter == MejaStatus.aktif,
                    onTap: () {
                      ref.read(mejaFilterCategoryProvider.notifier).state =
                          MejaStatus.aktif;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterButton(
                    label: 'Perawatan (${counts['perawatan']})',
                    isSelected: activeFilter == MejaStatus.perawatan,
                    onTap: () {
                      ref.read(mejaFilterCategoryProvider.notifier).state =
                          MejaStatus.perawatan;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Daftar Kartu Meja NFT
            if (filteredList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: Center(
                  child: Text(
                    'Meja NFT tidak ditemukan',
                    style: TextStyle(
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
                      // Detail meja / aksi tap
                    },
                    child: MejaNftCardContent(item: item),
                  ),
                );
              }),

            const SizedBox(height: 8),

            // 4. Tombol Tambah Meja NFT Baru
            RowButton(
              label: '+ Tambah Meja NFT Baru',
              backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
              textColor: const Color.fromRGBO(221, 244, 90, 1),
              onTap: () {
                // Navigasi atau form tambah meja NFT
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
