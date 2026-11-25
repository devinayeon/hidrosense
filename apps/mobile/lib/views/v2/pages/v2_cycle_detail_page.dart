import 'package:flutter/material.dart';

import '../components/v2_cycle_legend.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_checklist.dart';
import '../widgets/v2_cycle_ring.dart';
import '../widgets/v2_timeline_step.dart';

/// Satu langkah siklus di halaman 2.7.
class V2CycleStep {
  const V2CycleStep({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final V2TimelineState state;
}

/// Detail siklus 60 hari dari frame `2.7 Detail siklus`.
///
/// Dibuka dari kartu siklus di beranda 2.1. Cincin besar 224 menampilkan progres
/// HSS 23 dari 60 dengan garis penanda HSS 15, lalu linimasa empat tahap.
class V2CycleDetailPage extends StatelessWidget {
  const V2CycleDetailPage({
    super.key,
    this.tableName = 'Meja A2',
    this.value = 23,
    this.total = 60,
    this.windowEnd = 15,
    this.daysLeft = 37,
    this.steps = designSteps,
    this.onOpenTable,
    this.weatherTitle,
    this.weatherSubtitle,
    this.onOpenWeather,
  });

  final String tableName;
  final int value;
  final int total;
  final int windowEnd;
  final int daysLeft;
  final List<V2CycleStep> steps;
  final VoidCallback? onOpenTable;

  /// Ringkasan cuaca beranda; null berarti kartu cuaca tidak ditampilkan.
  final String? weatherTitle;
  final String? weatherSubtitle;
  final VoidCallback? onOpenWeather;

  static const List<V2CycleStep> designSteps = [
    V2CycleStep(
      title: 'Semai',
      subtitle: 'HSS 1 sampai 15. Selesai',
      state: V2TimelineState.done,
    ),
    V2CycleStep(
      title: 'Pindah ke meja',
      subtitle: 'HSS 15. Selesai',
      state: V2TimelineState.done,
    ),
    V2CycleStep(
      title: 'Tumbuh',
      subtitle: 'HSS 16 sampai 60. Berjalan',
      state: V2TimelineState.active,
    ),
    V2CycleStep(
      title: 'Panen',
      subtitle: 'HSS 60. 37 hari lagi',
      state: V2TimelineState.pending,
    ),
  ];

  static Route<void> route({
    String tableName = 'Meja A2',
    int value = 23,
    int total = 60,
    VoidCallback? onOpenTable,
    String? weatherTitle,
    String? weatherSubtitle,
    VoidCallback? onOpenWeather,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2CycleDetailPage(
        tableName: tableName,
        value: value,
        total: total,
        daysLeft: (total - value).clamp(0, total),
        onOpenTable: onOpenTable,
        weatherTitle: weatherTitle,
        weatherSubtitle: weatherSubtitle,
        onOpenWeather: onOpenWeather,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Siklus $tableName',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: V2CycleRing(
                          value: value,
                          total: total,
                          windowEnd: windowEnd,
                          size: 224,
                          strokeWidth: 20,
                          tickValue: windowEnd,
                        ),
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        'HSS $value dari $total. Panen $daysLeft hari lagi.',
                        style: V2Type.body.copyWith(color: V2Colors.muted),
                      ),
                      const SizedBox(height: V2Space.lg),
                      V2CycleLegend(
                        label: 'Garis: HSS $windowEnd, pindah ke meja',
                      ),
                      const SizedBox(height: V2Space.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < steps.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: V2Space.sm),
                            V2TimelineStep(
                              title: steps[index].title,
                              subtitle: steps[index].subtitle,
                              state: steps[index].state,
                            ),
                          ],
                        ],
                      ),
                      if (weatherTitle != null) ...[
                        const SizedBox(height: V2Space.lg),
                        V2WeatherCard(
                          title: weatherTitle!,
                          subtitle: weatherSubtitle ?? 'Cuaca hari ini',
                          onTap: onOpenWeather,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    0,
                    V2Space.xl,
                    V2Space.sm,
                  ),
                  child: V2Button(
                    label: 'Buka $tableName',
                    onPressed: onOpenTable,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
