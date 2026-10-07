import 'package:flutter/material.dart';

/// Palet warna resmi HidroSense (100% Retensi warna asli produk).
class AppColors {
  // Brand & Accent Colors
  static const Color primaryMint = Color(0xFF39C6C5);
  static const Color primaryDarkTeal = Color(0xFF168681);
  static const Color accentLime = Color(0xFFDDF45A);
  static const Color darkNavy = Color(0xFF172231);

  // Canvas & Surface
  static const Color canvasWarm = Color(0xFFFAFAF7);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color secondarySurface = Color(0xFFF3F4F6);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderSubtle = Color(0xFFF0F0EB);
  static const Color borderAccent = Color(0x6639C6C5);

  // Semantic Status
  static const Color successGreen = Color(0xFF10B981);
  static const Color successBg = Color(0x1A10B981);
  static const Color warningOrange = Color(0xFFFF9A55);
  static const Color warningBg = Color(0xFFFFF3EC);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEFF6FF);

  // Typography
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);
}

/// Token spasi ritme kelipatan 4pt & 8pt Apple HIG.
class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
}

/// Token sudut melengkung kontinyu (Squircle Radii).
class AppRadius {
  static const double badge = 8.0;
  static const double input = 12.0;
  static const double card = 16.0;
  static const double modal = 24.0;
  static const double pill = 999.0;
}

/// Token bayangan difusi lembut Apple HIG (Soft Diffusion Elevation).
class AppShadows {
  /// Level 1: Permukaan kartu kontainer standar
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A111827),
      blurRadius: 8.0,
      offset: Offset(0, 2),
      spreadRadius: 0.0,
    ),
  ];

  /// Level 2: Elemen melayang, dropdown, popover
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x14111827),
      blurRadius: 16.0,
      offset: Offset(0, 4),
      spreadRadius: 0.0,
    ),
  ];

  /// Level 3: Modal bottom sheet, floating action menu
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x1F111827),
      blurRadius: 24.0,
      offset: Offset(0, -4),
      spreadRadius: 0.0,
    ),
  ];
}

/// Skala Tipografi Apple HIG (Type Ramp) berbasis font Inter.
class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle subheadline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.textSecondary,
  );

  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0.0,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.0,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0.1,
    color: AppColors.textTertiary,
  );

  /// Helper untuk memastikan angka tabular tidak bergeser saat nilai berubah.
  static TextStyle tabular(TextStyle base) => base.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Konfigurasi ThemeData Flutter berbasis Apple HIG.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.canvasWarm,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryMint,
        primary: AppColors.primaryDarkTeal,
        secondary: AppColors.primaryMint,
        surface: AppColors.cardSurface,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvasWarm,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title3,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.primaryMint, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.0),
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTypography.subheadline.copyWith(color: AppColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardSurface,
        selectedItemColor: AppColors.primaryMint,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkTeal,
          foregroundColor: AppColors.textOnDark,
          minimumSize: const Size.fromHeight(50.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle: AppTypography.headline.copyWith(
            color: AppColors.textOnDark,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(50.0),
          side: const BorderSide(color: AppColors.borderLight, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle: AppTypography.headline,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTeal,
          textStyle: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.modal),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1.0,
        space: 1.0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: AppTypography.title3,
        contentTextStyle: AppTypography.body,
      ),
    );
  }
}
