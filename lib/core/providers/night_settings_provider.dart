import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Night Settings State ─────────────────────────────────────────────────────

class NightSettings {
  final double sirenVolume;
  final bool autoSosOnNoResponse;
  final bool stealthMode;
  final int autoSosDelaySeconds;
  final int nightStartHour; // 0-23
  final int nightEndHour;   // 0-23

  const NightSettings({
    this.sirenVolume = 80.0,
    this.autoSosOnNoResponse = true,
    this.stealthMode = false,
    this.autoSosDelaySeconds = 60,
    this.nightStartHour = 20, // 8 PM
    this.nightEndHour = 6,    // 6 AM
  });

  NightSettings copyWith({
    double? sirenVolume,
    bool? autoSosOnNoResponse,
    bool? stealthMode,
    int? autoSosDelaySeconds,
    int? nightStartHour,
    int? nightEndHour,
  }) {
    return NightSettings(
      sirenVolume: sirenVolume ?? this.sirenVolume,
      autoSosOnNoResponse: autoSosOnNoResponse ?? this.autoSosOnNoResponse,
      stealthMode: stealthMode ?? this.stealthMode,
      autoSosDelaySeconds: autoSosDelaySeconds ?? this.autoSosDelaySeconds,
      nightStartHour: nightStartHour ?? this.nightStartHour,
      nightEndHour: nightEndHour ?? this.nightEndHour,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NightSettingsNotifier extends StateNotifier<NightSettings> {
  NightSettingsNotifier() : super(const NightSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NightSettings(
      sirenVolume: prefs.getDouble('night_siren_volume') ?? 80.0,
      autoSosOnNoResponse: prefs.getBool('night_auto_sos') ?? true,
      stealthMode: prefs.getBool('night_stealth_mode') ?? false,
      autoSosDelaySeconds: prefs.getInt('night_sos_delay') ?? 60,
      nightStartHour: prefs.getInt('night_start_hour') ?? 20,
      nightEndHour: prefs.getInt('night_end_hour') ?? 6,
    );
  }

  Future<void> setSirenVolume(double volume) async {
    state = state.copyWith(sirenVolume: volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('night_siren_volume', volume);
  }

  Future<void> toggleAutoSos(bool value) async {
    state = state.copyWith(autoSosOnNoResponse: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('night_auto_sos', value);
  }

  Future<void> toggleStealthMode(bool value) async {
    state = state.copyWith(stealthMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('night_stealth_mode', value);
  }

  Future<void> setAutoSosDelay(int seconds) async {
    state = state.copyWith(autoSosDelaySeconds: seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('night_sos_delay', seconds);
  }

  Future<void> setNightStartHour(int hour) async {
    state = state.copyWith(nightStartHour: hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('night_start_hour', hour);
  }

  Future<void> setNightEndHour(int hour) async {
    state = state.copyWith(nightEndHour: hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('night_end_hour', hour);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final nightSettingsProvider =
    StateNotifierProvider<NightSettingsNotifier, NightSettings>((ref) {
  return NightSettingsNotifier();
});
