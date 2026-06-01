import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/settings_cache.dart';

const supportedLocales = [Locale('fr'), Locale('en')];

const localeLabels = {'fr': 'Français', 'en': 'English'};

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code = SettingsCache.locale;
    if (code == null) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await SettingsCache.setLocale('');
    } else {
      await SettingsCache.setLocale(locale.languageCode);
    }
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
