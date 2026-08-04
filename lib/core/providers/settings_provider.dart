import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';

class AppSettings {
  final bool shareLocation;
  final bool audioDetection;
  final bool usageAnalytics;
  final bool requireBiometric;

  const AppSettings({
    this.shareLocation = true,
    this.audioDetection = true,
    this.usageAnalytics = false,
    this.requireBiometric = false,
  });

  AppSettings copyWith({
    bool? shareLocation,
    bool? audioDetection,
    bool? usageAnalytics,
    bool? requireBiometric,
  }) {
    return AppSettings(
      shareLocation: shareLocation ?? this.shareLocation,
      audioDetection: audioDetection ?? this.audioDetection,
      usageAnalytics: usageAnalytics ?? this.usageAnalytics,
      requireBiometric: requireBiometric ?? this.requireBiometric,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final biometric = await SecureStorageService.getBiometricEnabled();
    state = AppSettings(
      shareLocation: prefs.getBool('shareLocation') ?? true,
      audioDetection: prefs.getBool('audioDetection') ?? true,
      usageAnalytics: prefs.getBool('usageAnalytics') ?? false,
      requireBiometric: biometric,
    );
  }

  Future<void> toggleShareLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shareLocation', value);
    state = state.copyWith(shareLocation: value);
  }

  Future<void> toggleAudioDetection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audioDetection', value);
    state = state.copyWith(audioDetection: value);
  }

  Future<void> toggleUsageAnalytics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('usageAnalytics', value);
    state = state.copyWith(usageAnalytics: value);
  }

  Future<void> toggleBiometric(bool value) async {
    await SecureStorageService.setBiometricEnabled(value);
    state = state.copyWith(requireBiometric: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
