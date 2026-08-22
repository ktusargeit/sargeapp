import 'package:flutter/material.dart';

/// Centralized color system supporting pure-black dark theme and white light theme.
class AppColors {
  AppColors._();

  // ── Brand & accent colors (theme-independent) ──────────────────────────────
  static const Color sargeGold = Color(0xFFD4AF37);
  /// Yönetim Kurulu (board) accent — şaşaalı altın tonları.
  static const Color gold = sargeGold;
  static const Color goldLight = Color(0xFFF6E27A);
  static const Color goldDark = Color(0xFF9B7A1F);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueAccent = Color(0xFF3B82F6);
  static const Color primaryGreen = Color(0xFF35D07F);
  static const Color success = Color(0xFF35D07F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color panelBlue = Color(0xFF3B82F6);
  static const Color panelBlueDark = Color(0xFF1E3A5F);
  static const Color depoAccent = Color(0xFF14B8A6);
  static const Color depoAccentDark = Color(0xFF0F766E);
  static const Color teamAccent = Color(0xFF8B5CF6);
  static const Color teamAccentDark = Color(0xFF5B21B6);
  static const Color tasksAccent = Color(0xFF10B981);
  static const Color tasksAccentDark = Color(0xFF047857);
  static const Color settingsAccent = Color(0xFF6366F1);
  static const Color depoRed = depoAccent;
  static const Color teamOrange = teamAccent;
  static const Color tasksGreen = tasksAccent;
  static const Color settingsPurple = settingsAccent;
  static const Color darkGreen = Color(0xFF0E3A25);

  // WhatsApp-style chat bubble colors (theme-aware).
  static const Color _darkOwnBubble = Color(0xFF123F2C);   // dark green tint
  static const Color _lightOwnBubble = Color(0xFFDCF8C6);  // WhatsApp light green

  static Color statusAvailable = success;
  static Color statusInUse = info;
  static Color statusMaintenance = warning;
  static Color statusMissing = error;
  static Color statusDamaged = error;
  static Color statusLost = const Color(0xFF64748B);

  // ── Dark neutral values ────────────────────────────────────────────────────
  static const Color _darkBackground = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF0D0D0D);
  static const Color _darkSurface2 = Color(0xFF1A1A1A);
  static const Color _darkSurface3 = Color(0xFF262626);
  static const Color _darkBorder = Color(0xFF333333);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextSecondary = Color(0xFF94A3B8);

  // ── Light neutral values ───────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightSurface2 = Color(0xFFEEEEEE);
  static const Color lightSurface3 = Color(0xFFE0E0E0);
  static const Color lightBorder = Color(0xFFD0D0D0);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF666666);

  /// Active theme brightness. Kept in sync by [ThemeModeNotifier] so that the
  /// neutral tokens below (background, surface, text, etc.) resolve to the
  /// correct palette for the selected theme.
  static Brightness _brightness = Brightness.dark;

  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get isLight => _brightness == Brightness.light;

  // ── Theme-aware neutral tokens ─────────────────────────────────────────────
  static Color get background =>
      isLight ? lightBg : _darkBackground;
  static Color get surface => isLight ? lightSurface : _darkSurface;
  static Color get surface2 => isLight ? lightSurface2 : _darkSurface2;
  static Color get surface3 => isLight ? lightSurface3 : _darkSurface3;
  static Color get border => isLight ? lightBorder : _darkBorder;
  static Color get textPrimary =>
      isLight ? lightTextPrimary : _darkTextPrimary;
  static Color get textSecondary =>
      isLight ? lightTextSecondary : _darkTextSecondary;

  /// WhatsApp-style chat bubble color for the current user's own messages.
  static Color get ownBubble =>
      isLight ? _lightOwnBubble : _darkOwnBubble;

  // Page scaffolds follow the same theme-aware background color.
  static Color get panelBg => background;
  static Color get depoBg => background;
  static Color get teamBg => background;
  static Color get tasksBg => background;
}