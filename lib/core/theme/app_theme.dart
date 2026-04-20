import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/settings/presentation/controllers/app_settings_controller.dart';

class AppTheme {
  const AppTheme._();

  static const _seed = Color(0xFF0F766E);
  static const _secondary = Color(0xFFF97316);
  static const _surface = Color(0xFFF7FAFC);

  static ThemeData themeFor(
    AppSettingsState settings, {
    required Brightness brightness,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: _seed,
      secondary: _secondary,
      surface: brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : _surface,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      displaySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.plusJakartaSans(height: 1.4),
      bodyMedium: GoogleFonts.plusJakartaSans(height: 1.4),
      bodySmall: GoogleFonts.plusJakartaSans(height: 1.35),
      labelLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
    );
    final background =
        brightness == Brightness.dark
            ? const Color(0xFF020617)
            : const Color(0xFFF4F7FB);
    final inputFill =
        brightness == Brightness.dark ? const Color(0xFF111827) : Colors.white;
    final cardColor =
        brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white;
    final outlineColor = settings.highContrastEnabled
        ? scheme.primary
        : scheme.outlineVariant;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      iconTheme: IconThemeData(
        color: settings.highContrastEnabled ? scheme.primary : scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(
          settings.highContrastEnabled ? scheme.secondary : null,
        ),
      ),
    );
  }

  static ThemeData get lightTheme =>
      themeFor(const AppSettingsState(), brightness: Brightness.light);

  static ThemeData get darkTheme =>
      themeFor(const AppSettingsState(darkModeEnabled: true), brightness: Brightness.dark);
}
