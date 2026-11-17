import 'package:flutter/material.dart';

/// Design tokens hasil slicing page "00 Foundations" pada file FigCraft
/// `HidroSense Mobile UI v2`.
///
/// Semua widget v2 memakai token di file ini supaya warna, tipografi, radius,
/// dan bayangan tetap satu sumber. Jangan menulis nilai hex langsung di widget.
abstract final class V2Colors {
  // Brand: Royal blue + electric lime
  static const Color blue50 = Color(0xFFEAF2FF);
  static const Color blue500 = Color(0xFF1565FF);
  static const Color blue600 = Color(0xFF0F4FD6);
  static const Color blue700 = Color(0xFF0B4FD1);
  static const Color blue800 = Color(0xFF0B3FAE);
  static const Color lime400 = Color(0xFFA3F533);
  static const Color lime500 = Color(0xFF8EDB22);

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF6F8FA);
  static const Color gray200 = Color(0xFFE5E8EC);
  static const Color charcoal900 = Color(0xFF111827);
  static const Color slate400 = Color(0xFF7A8494);
  static const Color slate500 = Color(0xFF687280);
  static const Color slate600 = Color(0xFF4B5563);
  static const Color muted = Color(0xFF6B7280);

  // Status
  static const Color green100 = Color(0xFFE3F5E1);
  static const Color green700 = Color(0xFF1F7A3D);
  static const Color amber100 = Color(0xFFFFF1CC);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber800 = Color(0xFF8A5200);
  static const Color red100 = Color(0xFFFDE7E4);
  static const Color red700 = Color(0xFFB3261E);

  // Semantics
  static const Color canvas = gray50;
  static const Color surface = white;
  static const Color border = gray200;
  static const Color borderStrong = slate400;
  static const Color ink = charcoal900;
  static const Color secondary = muted;
}

/// Type ramp Poppins dari "Foundations/Type".
abstract final class V2Type {
  static const String family = 'Poppins';

  /// Keluarga cadangan kalau Poppins belum terpasang sebagai asset aplikasi.
  static const List<String> fallback = <String>['Inter', 'Roboto'];

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 40 / 34,
    color: V2Colors.ink,
  );

  /// Angka utama di kartu (28/36 Bold).
  static const TextStyle value = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 36 / 28,
    color: V2Colors.ink,
  );

  /// Judul layar (28/36 Bold).
  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 36 / 28,
    color: V2Colors.ink,
  );

  /// Judul kartu / AppBar (20/28 SemiBold).
  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    color: V2Colors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: V2Colors.ink,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    color: V2Colors.ink,
  );

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    color: V2Colors.ink,
  );

  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    color: V2Colors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    color: V2Colors.secondary,
  );

  static TextStyle colored(TextStyle style, Color color) =>
      style.copyWith(color: color);
}

/// Ritme spasi kelipatan 4.
abstract final class V2Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class V2Radius {
  static const double iconBox = 12;
  static const double sm = 16;
  static const double card = 24;
  static const double sheet = 32;
  static const double pill = 999;
}

abstract final class V2Shadow {
  /// `Shadow/Card`: difusi lembut untuk permukaan kartu.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x14111827), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// `Shadow/Button Lip`: garis tegas 2px di bawah tombol brand.
  static const List<BoxShadow> buttonLip = <BoxShadow>[
    BoxShadow(color: V2Colors.blue800, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(color: Color(0x1F111827), blurRadius: 24, offset: Offset(0, -4)),
  ];
}

/// ThemeData minimal supaya halaman v2 tidak mewarisi warna theme lama.
abstract final class V2Theme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: V2Type.family,
    scaffoldBackgroundColor: V2Colors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: V2Colors.blue500,
      primary: V2Colors.blue500,
      secondary: V2Colors.lime400,
      surface: V2Colors.surface,
      brightness: Brightness.light,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: V2Colors.border,
      thickness: 1,
      space: 1,
    ),
  );
}
