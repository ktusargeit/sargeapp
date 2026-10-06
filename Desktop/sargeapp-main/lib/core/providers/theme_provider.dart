import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _apply(ThemeMode.dark);
    _load();
  }

  static const _key = 'theme_mode';

  void _apply(ThemeMode mode) {
    AppColors.setBrightness(
        mode == ThemeMode.light ? Brightness.light : Brightness.dark);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key) ?? 'dark';
      final mode = value == 'light' ? ThemeMode.light : ThemeMode.dark;
      _apply(mode);
      state = mode;
    } catch (_) {
      _apply(ThemeMode.dark);
      state = ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _apply(mode);
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}
