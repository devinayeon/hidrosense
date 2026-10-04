import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/penyemaian_viewmodel.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/seeding_card_content.dart';

class PenyemaianBody extends ConsumerWidget {
  const PenyemaianBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedingList = ref.watch(penyemaianViewModelProvider);

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
            const CustomSearchBar(placeholder: 'Cari batch atau varietas...'),
            const SizedBox(height: 16),
            ...seedingList.map((item) {
              final isReady = item.statusLabel.contains('Siap');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RowInfoCardMd(
                  backgroundColor: Colors.white,
                  borderColor: const Color.fromRGBO(229, 231, 235, 1),
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
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
