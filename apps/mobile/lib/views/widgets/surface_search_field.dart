import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_colors.dart';

/// Kolom pencarian bergaya inventaris: label mengambang, ikon kaca pembesar,
/// dan tombol hapus yang muncul saat ada isi.
class SurfaceSearchField extends StatelessWidget {
  const SurfaceSearchField({
    super.key,
    required this.label,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.controller,
    this.textInputAction = TextInputAction.search,
    this.autofocus = false,
  });

  final String label;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final TextEditingController? controller;
  final TextInputAction textInputAction;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);

    return TextField(
      controller: controller,
      autofocus: autofocus,
      cursorColor: colors.teal,
      textInputAction: textInputAction,
      style: AppTypography.body.copyWith(color: colors.ink),
      decoration: InputDecoration(
        filled: true,
        labelText: label,
        labelStyle: AppTypography.subheadline.copyWith(color: colors.secondary),
        floatingLabelStyle: TextStyle(color: colors.teal),
        fillColor: colors.surface,
        prefixIcon: Icon(
          CupertinoIcons.search,
          color: colors.secondary,
          size: 22,
        ),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: colors.secondary,
                  size: 20,
                ),
                onPressed: onClear,
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colors.controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colors.teal, width: 2),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
