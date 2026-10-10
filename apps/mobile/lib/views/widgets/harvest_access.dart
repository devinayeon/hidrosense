import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';

class HarvestAccess extends ConsumerWidget {
  const HarvestAccess({
    super.key,
    required this.child,
    this.write = false,
    this.batches = false,
  });
  final Widget child;
  final bool write, batches;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? <String>[];
    if (!permissions.contains('panen:read') ||
        (write && !permissions.contains('panen:write')) ||
        (batches && !permissions.contains('budidaya:read'))) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Akses panen tidak diizinkan. Hubungi pemilik kebun.'),
        ),
      );
    }
    final user = ref.watch(sessionProvider).user!;
    final origin = ref.watch(apiClientProvider).serverOrigin;
    return Theme(
      key: ValueKey((origin, user.id)),
      data: harvestTheme(Theme.of(context)),
      child: child,
    );
  }
}

ThemeData harvestTheme(ThemeData base) {
  final colors = base.colorScheme;
  final scheme = colors.brightness == Brightness.light
      ? colors.copyWith(
          primary: const Color(0xff14675f),
          onPrimary: Colors.white,
        )
      : colors;
  final inputs = base.inputDecorationTheme;
  final border = inputs.border ?? const OutlineInputBorder();
  return base.copyWith(
    colorScheme: scheme,
    inputDecorationTheme: inputs.copyWith(
      enabledBorder: (inputs.enabledBorder ?? border).copyWith(
        borderSide: BorderSide(
          color: scheme.outline,
          width: (inputs.enabledBorder ?? border).borderSide.width,
        ),
      ),
      focusedBorder: (inputs.focusedBorder ?? border).copyWith(
        borderSide: BorderSide(
          color: scheme.primary,
          width: inputs.focusedBorder?.borderSide.width ?? 2,
        ),
      ),
      errorBorder: (inputs.errorBorder ?? border).copyWith(
        borderSide: BorderSide(
          color: scheme.error,
          width: (inputs.errorBorder ?? border).borderSide.width,
        ),
      ),
      focusedErrorBorder:
          (inputs.focusedErrorBorder ?? inputs.focusedBorder ?? border)
              .copyWith(
                borderSide: BorderSide(
                  color: scheme.error,
                  width: inputs.focusedBorder?.borderSide.width ?? 2,
                ),
              ),
      hintStyle: (inputs.hintStyle ?? base.textTheme.bodyLarge)?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      labelStyle: (inputs.labelStyle ?? base.textTheme.bodyLarge)?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) =>
            (inputs.labelStyle ?? base.textTheme.bodyLarge ?? const TextStyle())
                .copyWith(
                  color: states.contains(WidgetState.error)
                      ? scheme.error
                      : states.contains(WidgetState.focused)
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
      ),
      errorStyle: (inputs.errorStyle ?? base.textTheme.bodySmall)?.copyWith(
        color: scheme.error,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.outline,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: scheme.outline),
      ),
    ),
  );
}
