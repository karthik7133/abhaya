import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class NightSafetyState {
  final bool isNightModeActive;
  final TimeOfDay nightStart;
  final TimeOfDay nightEnd;

  const NightSafetyState({
    required this.isNightModeActive,
    this.nightStart = const TimeOfDay(hour: 18, minute: 0), // 6 PM default
    this.nightEnd = const TimeOfDay(hour: 6, minute: 0),   // 6 AM default
  });

  NightSafetyState copyWith({
    bool? isNightModeActive,
    TimeOfDay? nightStart,
    TimeOfDay? nightEnd,
  }) {
    return NightSafetyState(
      isNightModeActive: isNightModeActive ?? this.isNightModeActive,
      nightStart: nightStart ?? this.nightStart,
      nightEnd: nightEnd ?? this.nightEnd,
    );
  }
}

class NightSafetyProvider extends StateNotifier<NightSafetyState> {
  NightSafetyProvider() : super(const NightSafetyState(isNightModeActive: false)) {
    _evaluateNightMode();
  }

  void _evaluateNightMode() {
    final now = TimeOfDay.now();
    bool isActive = false;

    // Logic for cross-midnight times (e.g. 18:00 to 06:00)
    if (state.nightStart.hour > state.nightEnd.hour) {
      if (now.hour >= state.nightStart.hour || now.hour < state.nightEnd.hour) {
        isActive = true;
      } else if (now.hour == state.nightStart.hour && now.minute >= state.nightStart.minute) {
        isActive = true;
      } else if (now.hour == state.nightEnd.hour && now.minute <= state.nightEnd.minute) {
        isActive = true;
      }
    } else {
      // Normal daytime period (e.g. 18:00 to 22:00)
      if (now.hour > state.nightStart.hour && now.hour < state.nightEnd.hour) {
        isActive = true;
      } else if (now.hour == state.nightStart.hour && now.minute >= state.nightStart.minute) {
        isActive = true;
      } else if (now.hour == state.nightEnd.hour && now.minute <= state.nightEnd.minute) {
        isActive = true;
      }
    }

    if (state.isNightModeActive != isActive) {
      state = state.copyWith(isNightModeActive: isActive);
    }
  }

  void toggle() {
    state = state.copyWith(isNightModeActive: !state.isNightModeActive);
  }

  void setCustomNightHours(TimeOfDay start, TimeOfDay end) {
    state = state.copyWith(nightStart: start, nightEnd: end);
    _evaluateNightMode();
  }
}

final nightSafetyProvider = StateNotifierProvider<NightSafetyProvider, NightSafetyState>((ref) {
  return NightSafetyProvider();
});
