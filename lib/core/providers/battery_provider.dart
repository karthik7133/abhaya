import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Battery State Model ──────────────────────────────────────────────────────

enum ChargeStatus { charging, discharging, full, unknown }

class BatteryInfo {
  final int level;           // 0–100
  final ChargeStatus status;

  const BatteryInfo({required this.level, required this.status});

  String get levelString => '$level%';

  bool get isCharging => status == ChargeStatus.charging || status == ChargeStatus.full;
}

// ─── Battery Notifier ─────────────────────────────────────────────────────────

class BatteryNotifier extends StateNotifier<BatteryInfo> {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _stateSub;
  Timer? _pollTimer;

  BatteryNotifier()
      : super(const BatteryInfo(level: 100, status: ChargeStatus.unknown)) {
    _init();
  }

  Future<void> _init() async {
    await _fetchLevel();

    // React to charging/discharging changes immediately
    _stateSub = _battery.onBatteryStateChanged.listen((_) => _fetchLevel());

    // Periodic poll — battery level doesn't emit a stream natively
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchLevel());
  }

  Future<void> _fetchLevel() async {
    try {
      final level  = await _battery.batteryLevel;
      final rawState = await _battery.batteryState;
      if (mounted) {
        state = BatteryInfo(level: level, status: _map(rawState));
      }
    } catch (_) {
      // Fail silently — keep last known state
    }
  }

  ChargeStatus _map(BatteryState s) {
    switch (s) {
      case BatteryState.charging:
        return ChargeStatus.charging;
      case BatteryState.discharging:
        return ChargeStatus.discharging;
      case BatteryState.full:
        return ChargeStatus.full;
      default:
        return ChargeStatus.unknown;
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// Provides the device's real-time battery level & charge status.
final batteryProvider =
    StateNotifierProvider<BatteryNotifier, BatteryInfo>((ref) {
  return BatteryNotifier();
});
