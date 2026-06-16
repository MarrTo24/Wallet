// Sistema de diseño de SeguriData Identity Wallet.
// Paleta basada en los colores oficiales de SeguriData:
//   Verde principal:  #72B52D  (logo green)
//   Gris corporativo: #58595B  (logo gray)

import 'package:flutter/material.dart';

/// Paleta de colores corporativa SeguriData.
abstract final class AppColors {
  // ── Marca SeguriData ──────────────────────────────────────────────────
  /// Verde principal del logo SeguriData.
  static const primary        = Color(0xFF72B52D);
  /// Verde oscuro para hover y estados activos.
  static const primaryDark    = Color(0xFF5A9020);
  /// Verde claro para fondos y badges.
  static const primaryLight   = Color(0xFFEBF5D9);
  /// Verde muy claro para superficies sutiles.
  static const primarySurface = Color(0xFFF4FAE8);

  // ── Grises corporativos ───────────────────────────────────────────────
  /// Gris corporativo del logo ("Seguri").
  static const corpGray       = Color(0xFF58595B);
  /// Gris oscuro para texto principal.
  static const textPrimary    = Color(0xFF2D2D2D);
  /// Gris medio para texto secundario.
  static const textSecondary  = Color(0xFF58595B);
  /// Gris claro para texto terciario y placeholders.
  static const textTertiary   = Color(0xFF9A9A9A);
  /// Blanco para textos sobre fondo verde.
  static const textOnPrimary  = Color(0xFFFFFFFF);

  // ── Fondos ─────────────────────────────────────────────────────────────
  /// Fondo general de pantallas.
  static const background     = Color(0xFFF5F7F2);
  /// Superficie de tarjetas y modales.
  static const surface        = Color(0xFFFFFFFF);
  /// Superficie variante suave.
  static const surfaceVariant = Color(0xFFF9FBF5);

  // ── Bordes ─────────────────────────────────────────────────────────────
  /// Borde estándar de cards e inputs.
  static const border         = Color(0xFFDDE5CC);
  /// Borde claro para separadores.
  static const borderLight    = Color(0xFFEEF3E4);

  // ── Estados semánticos ─────────────────────────────────────────────────
  static const success        = Color(0xFF3D8B0F);
  static const successLight   = Color(0xFFD6EFBE);
  static const warning        = Color(0xFFD97706);
  static const warningLight   = Color(0xFFFEF9C3);
  static const error          = Color(0xFFDC2626);
  static const errorLight     = Color(0xFFFEE2E2);
  static const info           = Color(0xFF0369A1);
  static const infoLight      = Color(0xFFE0F2FE);
}

/// Radios de borde estándar.
abstract final class AppRadius {
  static const card     = BorderRadius.all(Radius.circular(16));
  static const button   = BorderRadius.all(Radius.circular(12));
  static const heroCard = BorderRadius.all(Radius.circular(24));
  static const badge    = BorderRadius.all(Radius.circular(999));
  static const input    = BorderRadius.all(Radius.circular(12));
}

/// Sombras estándar.
abstract final class AppShadow {
  static const card = [
    BoxShadow(
      color: Color(0x0C000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static final identity = [
    BoxShadow(
      color: Color(0x4072B52D),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];
}

class AppTheme {
  static ThemeData get lightTheme {
    const primary = AppColors.primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ).copyWith(
        primary: primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.corpGray,
        error: AppColors.error,
        errorContainer: AppColors.errorLight,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x14000000),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),

      // ── Botones elevados ──────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Botones de contorno ───────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Botones de texto ──────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Campos de texto ───────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIconColor: AppColors.primary,
      ),

      // ── Cards ─────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),

      // ── Dividers ──────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // ── FAB ───────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ── Tipografía ────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge:   TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge:      TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.5),
        bodyMedium:     TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
        labelSmall:     TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.9),
      ),
    );
  }
}
