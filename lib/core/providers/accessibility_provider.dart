import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityState {
  final bool highContrastEnabled;
  final double textScaleFactorOverride;

  const AccessibilityState({
    this.highContrastEnabled = false,
    this.textScaleFactorOverride = 1.0,
  });

  AccessibilityState copyWith({
    bool? highContrastEnabled,
    double? textScaleFactorOverride,
  }) {
    return AccessibilityState(
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      textScaleFactorOverride:
          textScaleFactorOverride ?? this.textScaleFactorOverride,
    );
  }
}

class AccessibilityProvider extends StateNotifier<AccessibilityState> {
  AccessibilityProvider() : super(const AccessibilityState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AccessibilityState(
      highContrastEnabled: prefs.getBool('accessibility_high_contrast') ?? false,
      textScaleFactorOverride:
          prefs.getDouble('accessibility_text_scale') ?? 1.0,
    );
  }

  Future<void> toggleHighContrast() async {
    final next = !state.highContrastEnabled;
    state = state.copyWith(highContrastEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessibility_high_contrast', next);
  }

  Future<void> setTextScale(double scale) async {
    state = state.copyWith(textScaleFactorOverride: scale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('accessibility_text_scale', scale);
  }
}

final accessibilityProvider =
    StateNotifierProvider<AccessibilityProvider, AccessibilityState>((ref) {
  return AccessibilityProvider();
});
