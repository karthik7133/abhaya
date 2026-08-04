import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Abhaya — Global ThemeData configuration.
/// NOTE: BackdropFilter is used throughout GlassCard components.
/// On Flutter Web, this degrades below 60fps on low-end browsers.
/// Optimization is scoped to native Android/iOS rendering paths.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary:   AppColors.accentTeal,
          secondary: AppColors.accentAmber,
          error:     AppColors.accentCrimson,
          surface:   AppColors.bgSurface,
        ),
        fontFamily: 'PlusJakartaSans',
        textTheme: _buildTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentTeal,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  static ThemeData get highContrast => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary:   Colors.white,
          secondary: Colors.yellow,
          error:     Colors.red,
          surface:   Colors.black,
        ),
        fontFamily: 'PlusJakartaSans',
        textTheme: _buildHighContrastTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white, width: 2),
            ),
            elevation: 0,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  static TextTheme _buildTextTheme() {
    const base = TextStyle(
      fontFamily: 'PlusJakartaSans',
      color: AppColors.textPrimary,
      letterSpacing: -0.3,
    );

    return TextTheme(
      displayLarge:  base.copyWith(fontSize: 57, fontWeight: FontWeight.w800),
      displayMedium: base.copyWith(fontSize: 45, fontWeight: FontWeight.w700),
      displaySmall:  base.copyWith(fontSize: 36, fontWeight: FontWeight.w700),
      headlineLarge: base.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium:base.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: base.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge:    base.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium:   base.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall:    base.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge:     base.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:    base.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:     base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge:    base.copyWith(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      labelMedium:   base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      labelSmall:    base.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  static TextTheme _buildHighContrastTextTheme() {
    const base = TextStyle(
      fontFamily: 'PlusJakartaSans',
      color: Colors.white,
      letterSpacing: 0,
    );

    return TextTheme(
      displayLarge:  base.copyWith(fontSize: 57, fontWeight: FontWeight.w900),
      displayMedium: base.copyWith(fontSize: 45, fontWeight: FontWeight.w900),
      displaySmall:  base.copyWith(fontSize: 36, fontWeight: FontWeight.w900),
      headlineLarge: base.copyWith(fontSize: 32, fontWeight: FontWeight.w900),
      headlineMedium:base.copyWith(fontSize: 28, fontWeight: FontWeight.w900),
      headlineSmall: base.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
      titleLarge:    base.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
      titleMedium:   base.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
      titleSmall:    base.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge:     base.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium:    base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodySmall:     base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
      labelLarge:    base.copyWith(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
      labelMedium:   base.copyWith(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
      labelSmall:    base.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
    );
  }
}
