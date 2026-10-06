import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../pages/info_seeding_page.dart';
import '../pages/seeding_form_page.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/seeding_card_content.dart';

class PenyemaianBody extends ConsumerWidget {
  const PenyemaianBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedNurseryProvider);
    final refresh = ref.read(connectedNurseryProvider.notifier).refresh;
    final items = state.filteredRecords;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(254, 242, 242, 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color.fromRGBO(239, 68, 68, 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Color.fromRGBO(239, 68, 68, 1)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(fontSize: 11, color: Color.fromRGBO(239, 68, 68, 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              CustomSearchBar(
                placeholder: 'Cari batch semaian...',
                onChanged: (value) {
                  ref.read(connectedNurseryProvider.notifier).setSearchQuery(value);
                },
              ),
              const SizedBox(height: 16),
              if (state.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: CircularProgressIndicator(color: Color.fromRGBO(57, 198, 195, 1)),
                  ),
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      state.error != null && state.records.isEmpty
                          ? 'Data penyemaian belum dapat ditampilkan.'
                          : state.records.isEmpty
                          ? 'Belum ada batch penyemaian aktif.'
                          : 'Penyemaian tidak ditemukan.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color.fromRGBO(156, 163, 175, 1),
                      ),
                    ),
                  ),
                )
              else
                ...items.map((item) {
                  final isReady = item.isReadyToMove;
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
                                InfoSeedingPage(sowingRecord: item),
                          ),
                        );
                      },
                      child: SeedingCardContent(
                        batchName: item.batchName,
                        variety: 'Selada Hidroponik',
                        dateText: item.sowingDate,
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
      ),
    );
  }
}
