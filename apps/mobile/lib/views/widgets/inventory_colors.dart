import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Palette warna yang digunakan di seluruh komponen inventaris.
/// Mendukung dark mode dan light mode secara otomatis.
class InventoryColors {
  const InventoryColors(this.dark);

  factory InventoryColors.of(BuildContext context) =>
      InventoryColors(Theme.of(context).brightness == Brightness.dark);

  final bool dark;

  Color get canvas => dark ? const Color(0xFF101D24) : AppColors.canvasWarm;
  Color get surface => dark ? const Color(0xFF1B2B34) : AppColors.cardSurface;
  Color get ink => dark ? const Color(0xFFF3F7F4) : AppColors.darkNavy;
  Color get secondary =>
      dark ? const Color(0xFFB3C1BB) : const Color(0xFF58665F);
  Color get teal => dark ? const Color(0xFF85DFCC) : const Color(0xFF0E756E);
  Color get onTeal => dark ? AppColors.darkNavy : Colors.white;
  Color get mintSurface =>
      dark ? const Color(0xFF223E37) : const Color(0xFFE9F3E7);
  Color get border => dark ? const Color(0xFF354C48) : const Color(0xFFDFE6DD);
  Color get controlBorder =>
      dark ? const Color(0xFF94A79B) : const Color(0xFF76857D);
  Color get error => dark ? const Color(0xFFFFB4AA) : const Color(0xFFB42318);
  Color get warning =>
      dark ? const Color(0xFFFFC78F) : const Color(0xFF915016);
}
