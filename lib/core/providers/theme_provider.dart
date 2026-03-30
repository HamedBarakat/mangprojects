import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

const _kThemeKey = 'user_theme_id';

class AppThemeNotifier extends Notifier<AppThemeConfig> {
  static const _default = AppThemeConfig(
    variant: AppThemeVariant.cyan,
    brightness: Brightness.dark,
  );

  @override
  AppThemeConfig build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kThemeKey);
    if (id != null) {
      state = AppThemeConfig.fromId(id);
    }
  }

  Future<void> setVariant(AppThemeVariant variant) async {
    // White is always light — force brightness
    if (variant == AppThemeVariant.white) {
      state = AppThemeConfig(variant: variant, brightness: Brightness.light);
    } else {
      state = state.copyWith(variant: variant);
    }
    await _persist();
  }

  Future<void> toggleBrightness() async {
    // White is always light, ignore toggle
    if (state.variant == AppThemeVariant.white) return;
    final next = state.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    state = state.copyWith(brightness: next);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, state.id);
  }
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppThemeConfig>(
  AppThemeNotifier.new,
);
