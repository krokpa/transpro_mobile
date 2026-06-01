import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/settings_cache.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return _fromString(SettingsCache.themeMode);
  }

  Future<void> setMode(ThemeMode mode) async {
    await SettingsCache.setThemeMode(_toString(mode));
    state = mode;
  }

  static ThemeMode _fromString(String s) => switch (s) {
    'dark'  => ThemeMode.dark,
    'light' => ThemeMode.light,
    _       => ThemeMode.system,
  };

  static String _toString(ThemeMode m) => switch (m) {
    ThemeMode.dark   => 'dark',
    ThemeMode.light  => 'light',
    ThemeMode.system => 'system',
  };
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
