import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.coral,
        onPrimary: AppColors.paper,
        secondary: AppColors.sage,
        onSecondary: AppColors.paper,
        surface: AppColors.paper,
        onSurface: AppColors.walnut,
        error: AppColors.coralDeep,
      ),
      textTheme: _textTheme(AppColors.walnut, AppColors.walnutSoft),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.walnut,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.walnut),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.linen,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: AppColors.paper,
          elevation: 6,
          shadowColor: AppColors.coral.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.walnut,
          side: const BorderSide(color: AppColors.linen),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.linen.withValues(alpha: 0.5),
        selectedColor: AppColors.terracotta,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: AppColors.walnut,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: AppColors.paper,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        elevation: 0,
        height: 68,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.walnutMuted,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: AppColors.walnutMuted, size: 24),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.inkSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.terracotta,
        secondary: AppColors.sage,
        surface: AppColors.inkPaper,
        onSurface: AppColors.cream,
      ),
      textTheme: _textTheme(AppColors.cream, AppColors.walnutMuted),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      // ── Display & headlines: Fraunces (serif editorial) ──────────────
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -0.8,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 31,
        fontWeight: FontWeight.w600,
        height: 1.08,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 25,
        fontWeight: FontWeight.w600,
        height: 1.14,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: -0.3,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        height: 1.5,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        height: 1.5,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        height: 1.4,
        color: secondary,
        letterSpacing: 0.1,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
    );
  }
}
