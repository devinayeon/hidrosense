import 'package:flutter/material.dart';

import '../../../../views/v2/theme/v2_tokens.dart';
import '../../data/pest_models.dart';

/// Urutan obat bergantian beserta sisa jatah semprot tiap cara kerja.
class RotationPlanView extends StatelessWidget {
  const RotationPlanView({super.key, required this.plan});

  final RotationPlan plan;

  static String detail(RotationStep step) {
    if (step.moaCode == null) return 'Tanpa batas semprot';
    final remaining = step.remaining;
    final moa = 'MoA ${step.moaCode}';
    return remaining == null ? moa : '$moa · sisa ${remaining}x';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text('Urutan rotasi', style: V2Type.bodyStrong),
        ),
        for (final step in plan.steps) ...[
          const SizedBox(height: V2Space.sm),
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: V2Space.xl,
                  child: Text('${step.order}.', style: V2Type.body),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.activeIngredient, style: V2Type.body),
                      Text(detail(step), style: V2Type.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: V2Space.sm),
        const Text('Maks. 2x per 30 hari.', style: V2Type.caption),
      ],
    );
  }
}
