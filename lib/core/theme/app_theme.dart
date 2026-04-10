import 'package:flutter/material.dart';

const _primary = Color(0xFF1F3864);
const _accent  = Color(0xFF2E75B6);

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      primary:   _primary,
      secondary: _accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      backgroundColor: Color(0xFF1A2F56),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );
}

Color orderStatusColor(String status) => switch (status) {
  'CONFIRMED'    => const Color(0xFF1890FF),
  'IN_PRODUCTION' => const Color(0xFFFAAD14),
  'QC_PASSED'   => const Color(0xFF52C41A),
  'DISPATCHED'  => const Color(0xFF722ED1),
  'CANCELLED'   => const Color(0xFFFF4D4F),
  _             => Colors.grey,
};

Color ledgerEntryColor(String entryType) => switch (entryType) {
  'GRN_IN'          => const Color(0xFF52C41A),
  'OPENING_STOCK'   => const Color(0xFF1890FF),
  'RETURN_FROM_PROD'=> const Color(0xFF13C2C2),
  'TRANSFER_IN'     => const Color(0xFF2F54EB),
  'ADJUSTMENT'      => const Color(0xFFFA8C16),
  'ISSUE_TO_PROD'   => const Color(0xFFFF4D4F),
  'TRANSFER_OUT'    => const Color(0xFFFA541C),
  _                 => Colors.grey,
};

String ledgerEntryLabel(String entryType) => switch (entryType) {
  'GRN_IN'          => 'GRN In',
  'OPENING_STOCK'   => 'Opening',
  'RETURN_FROM_PROD'=> 'Return',
  'TRANSFER_IN'     => 'Transfer In',
  'ADJUSTMENT'      => 'Adjustment',
  'ISSUE_TO_PROD'   => 'Issue',
  'TRANSFER_OUT'    => 'Transfer Out',
  _                 => entryType,
};
