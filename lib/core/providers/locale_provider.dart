import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends StateNotifier<Locale> {
  LocaleProvider() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_language') ?? 'en';
    debugPrint('[LocaleProvider] Loaded saved language: $savedLang');
    state = Locale(savedLang);
  }

  Future<void> setLocale(Locale locale) async {
    debugPrint('[LocaleProvider] setLocale called: ${state.languageCode} → ${locale.languageCode}');
    if (state != locale) {
      state = locale;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', locale.languageCode);
      debugPrint('[LocaleProvider] ✅ Locale updated to ${locale.languageCode} and saved');
    } else {
      debugPrint('[LocaleProvider] ⚠️ Same locale selected, no change');
    }
  }

  Future<void> toggleLanguage() async {
    // Cycle: en → hi → te → en
    if (state.languageCode == 'en') {
      await setLocale(const Locale('hi'));
    } else if (state.languageCode == 'hi') {
      await setLocale(const Locale('te'));
    } else {
      await setLocale(const Locale('en'));
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleProvider, Locale>((ref) {
  return LocaleProvider();
});
