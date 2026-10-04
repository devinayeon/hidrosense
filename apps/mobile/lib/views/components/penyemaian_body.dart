import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/penyemaian_viewmodel.dart';
import '../pages/seeding_form_page.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/seeding_card_content.dart';
import '../pages/info_seeding_page.dart';

class PenyemaianBody extends ConsumerWidget {
  const PenyemaianBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch daftar yang sudah ter-filter
    final filteredList = ref.watch(filteredSeedingListProvider);

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
            // CustomSearchBar dengan Callback Search Query
            CustomSearchBar(
              placeholder: 'Cari batch atau varietas...',
              onChanged: (value) {
                ref.read(seedingSearchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 16),

            // Tampilkan pesan kosong jika tidak ada hasil pencarian
            if (filteredList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'Penyemaian tidak ditemukan',
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
                final isReady = item.statusLabel.contains('Siap');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: RowInfoCardMd(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(229, 231, 235, 1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InfoSeedingPage(seedingItem: item),
                        ),
                      );
                    },
                    child: SeedingCardContent(
                      batchName: item.batchName,
                      variety: item.variety,
                      dateText: item.dateText,
                      seedCountText: item.seedCountText,
                      hssText: item.hssText,
                      statusLabel: item.statusLabel,
                      statusTextColor: isReady
                          ? const Color.fromRGBO(249, 115, 22, 1)
                          : const Color.fromRGBO(57, 198, 195, 1),
                      statusBgColor: isReady
                          ? const Color.fromRGBO(255, 248, 243, 1)
                          : const Color.fromRGBO(240, 251, 251, 1),
                      statusBorderColor: isReady
                          ? const Color.fromRGBO(254, 215, 170, 1)
                          : const Color.fromRGBO(165, 243, 242, 1),
                      note: item.note,
                    ),
                  ),
                );
              }),

            const SizedBox(height: 8),
            RowButton(
              label: '+ Mulai Penyemaian Baru',
              backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
              textColor: const Color.fromRGBO(221, 244, 90, 1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SeedingFormPage(),
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
