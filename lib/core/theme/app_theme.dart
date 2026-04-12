import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Dark design system ────────────────────────────────────────────────────
//
// Surface hierarchy (darkest → lightest):
//   scaffold  #0A0A0C   – true background
//   surface   #131316   – cards, tiles
//   elevated  #1C1C20   – dialogs, modals, selected states
//   border    #2A2A30   – hairline borders
//
// Accent palette (desaturated for dark backgrounds):
//   primary   #7B93FF   – interactive, links, active states
//   accent    #5B7FFF   – buttons, FABs
//
// Semantic colors (softer variants for dark):
//   success   #4ADE80
//   warning   #FBBF24
//   error     #F87171
//   info      #60A5FA

const _scaffold  = Color(0xFF0A0A0C);
const _surface   = Color(0xFF131316);
const _elevated  = Color(0xFF1C1C20);
const _border    = Color(0xFF2A2A30);
const _primary   = Color(0xFF7B93FF);
const _accent    = Color(0xFF5B7FFF);
const _textPrimary   = Color(0xFFF0F0F2);
const _textSecondary = Color(0xFF8B8B95);
const _textTertiary  = Color(0xFF5A5A65);

class AppColors {
  static const scaffold = _scaffold;
  static const surface = _surface;
  static const elevated = _elevated;
  static const border = _border;
  static const primary = _primary;
  static const accent = _accent;
  static const textPrimary = _textPrimary;
  static const textSecondary = _textSecondary;
  static const textTertiary = _textTertiary;

  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error   = Color(0xFFF87171);
  static const info    = Color(0xFF60A5FA);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _scaffold,
    colorScheme: const ColorScheme.dark(
      surface: _surface,
      primary: _primary,
      secondary: _accent,
      error: Color(0xFFF87171),
      onPrimary: Colors.white,
      onSurface: _textPrimary,
      outline: _border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _scaffold,
      foregroundColor: _textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardTheme(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    ),
    dividerTheme: const DividerThemeData(
      color: _border,
      thickness: 0.5,
      space: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1),
      ),
      hintStyle: const TextStyle(color: _textTertiary, fontSize: 14),
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      prefixIconColor: _textTertiary,
      suffixIconColor: _textTertiary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _elevated,
        disabledForegroundColor: _textTertiary,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _textSecondary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: _textSecondary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _surface,
      side: const BorderSide(color: _border, width: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelStyle: const TextStyle(fontSize: 12, color: _textSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border, width: 0.5),
      ),
      titleTextStyle: const TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _elevated,
      contentTextStyle: const TextStyle(color: _textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _primary,
      linearTrackColor: _border,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: _textPrimary,
      iconColor: _textSecondary,
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge:     TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium:    TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
      titleSmall:     TextStyle(color: _textSecondary, fontWeight: FontWeight.w500),
      bodyLarge:      TextStyle(color: _textPrimary, fontSize: 15),
      bodyMedium:     TextStyle(color: _textSecondary, fontSize: 14),
      bodySmall:      TextStyle(color: _textTertiary, fontSize: 12),
      labelLarge:     TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium:    TextStyle(color: _textSecondary, fontSize: 12),
      labelSmall:     TextStyle(color: _textTertiary, fontSize: 11),
    ),
  );

  // Keep for backward compat — alias to dark
  static ThemeData get light => dark;
}

// ── Semantic status colors (for dark backgrounds) ─────────────────────────

Color orderStatusColor(String status) => switch (status) {
  'CONFIRMED'     => const Color(0xFF60A5FA),
  'IN_PRODUCTION' => const Color(0xFFFBBF24),
  'QC_PASSED'     => const Color(0xFF4ADE80),
  'DISPATCHED'    => const Color(0xFFA78BFA),
  'CANCELLED'     => const Color(0xFFF87171),
  _               => const Color(0xFF6B7280),
};

Color ledgerEntryColor(String entryType) => switch (entryType) {
  'GRN_IN'           => const Color(0xFF4ADE80),
  'OPENING_STOCK'    => const Color(0xFF60A5FA),
  'RETURN_FROM_PROD' => const Color(0xFF2DD4BF),
  'TRANSFER_IN'      => const Color(0xFF818CF8),
  'ADJUSTMENT'       => const Color(0xFFFBBF24),
  'ISSUE_TO_PROD'    => const Color(0xFFF87171),
  'TRANSFER_OUT'     => const Color(0xFFFB923C),
  _                  => const Color(0xFF6B7280),
};

String ledgerEntryLabel(String entryType) => switch (entryType) {
  'GRN_IN'           => 'GRN In',
  'OPENING_STOCK'    => 'Opening',
  'RETURN_FROM_PROD' => 'Return',
  'TRANSFER_IN'      => 'Transfer In',
  'ADJUSTMENT'       => 'Adjustment',
  'ISSUE_TO_PROD'    => 'Issue',
  'TRANSFER_OUT'     => 'Transfer Out',
  _                  => entryType,
};
