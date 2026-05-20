import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF0F62FE);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );
  }
}