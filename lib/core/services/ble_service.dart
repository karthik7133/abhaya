import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';

// ─── BLE Device Model ─────────────────────────────────────────────────────────

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleDevice {
  final String name;
  final String macAddress;
  final int rssi;     // signal strength in dBm

  const BleDevice({
    required this.name,
    required this.macAddress,
    required this.rssi,
  });

  String get signalBars {
    if (rssi > -60) return '████';   // Excellent
    if (rssi > -75) return '███░';   // Good
    if (rssi > -90) return '██░░';   // Fair
    return '█░░░';                    // Weak
  }
}

// ─── BLE State ────────────────────────────────────────────────────────────────

class BleState {
  final BleConnectionState connectionState;
  final BleDevice? connectedDevice;
  final List<BleDevice> discoveredDevices;
  final int? heartRate;        // bpm from the band, null if not connected
  final int? steps;           // step count from phone pedometer
  final String? errorMessage;

  const BleState({
    this.connectionState = BleConnectionState.disconnected,
    this.connectedDevice,
    this.discoveredDevices = const [],
    this.heartRate,
    this.steps,
    this.errorMessage,
  });

  bool get isConnected => connectionState == BleConnectionState.connected;
  bool get isScanning  => connectionState == BleConnectionState.scanning;

  BleState copyWith({
    BleConnectionState? connectionState,
    BleDevice? connectedDevice,
    List<BleDevice>? discoveredDevices,
    int? heartRate,
    int? steps,
    String? errorMessage,
    bool clearError = false,
    bool clearDevice = false,
    bool clearHr = false,
    bool clearSteps = false,
  }) {
    return BleState(
      connectionState:   connectionState   ?? this.connectionState,
      connectedDevice:   clearDevice       ? null : (connectedDevice ?? this.connectedDevice),
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      heartRate:         clearHr           ? null : (heartRate ?? this.heartRate),
      steps:             clearSteps        ? null : (steps ?? this.steps),
      errorMessage:      clearError        ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── BLE Notifier ─────────────────────────────────────────────────────────────
// NOTE: This is a sophisticated mock that simulates the full BLE pairing flow.
// In production, swap `_simulateScan` and `_simulateConnect` for `flutter_blue_plus`
// calls: `FlutterBluePlus.startScan(...)` and `device.connect()`.

class BleNotifier extends StateNotifier<BleState> {
  Timer? _scanTimer;
  Timer? _hrTimer;
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  int _steps = 0;

  BleNotifier() : super(const BleState()) {
    _initPedometer();
  }

  void _initPedometer() {
    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (mounted) {
            _steps = event.steps;
            state = state.copyWith(steps: _steps);
          }
        },
        onError: (error) {
          debugPrint('Pedometer error: $error');
        },
      );

      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        (PedestrianStatus event) {
          debugPrint('Pedestrian status: ${event.status}');
        },
        onError: (error) {
          debugPrint('Pedestrian status error: $error');
        },
      );
    } catch (e) {
      debugPrint('Pedometer not available: $e');
    }
  }

  /// Starts a 5-second BLE scan and populates the discovered device list.
  Future<void> startScan() async {
    if (state.isScanning) return;

    state = state.copyWith(
      connectionState:   BleConnectionState.scanning,
      discoveredDevices: [],
      clearError:        true,
    );

    // Simulate progressive device discovery over 5 seconds
    int found = 0;
    const mockDevices = [
      ('Abhaya Band v2', 'AA:BB:CC:DD:EE:FF', -58),
      ('GENERIC_HR_01',  '11:22:33:44:55:66', -72),
      ('MI Band 8',      'DE:AD:BE:EF:CA:FE', -81),
    ];

    _scanTimer = Timer.periodic(const Duration(milliseconds: 1800), (t) {
      if (!mounted) { t.cancel(); return; }
      if (found < mockDevices.length) {
        final d = mockDevices[found++];
        state = state.copyWith(
          discoveredDevices: [
            ...state.discoveredDevices,
            BleDevice(name: d.$1, macAddress: d.$2, rssi: d.$3),
          ],
        );
      } else {
        t.cancel();
        if (mounted && !state.isConnected) {
          state = state.copyWith(connectionState: BleConnectionState.disconnected);
        }
      }
    });
  }

  void stopScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (state.isScanning) {
      state = state.copyWith(connectionState: BleConnectionState.disconnected);
    }
  }

  /// Connects to the given [device]. Simulates a 2-second pairing handshake.
  Future<void> connect(BleDevice device) async {
    _scanTimer?.cancel();
    state = state.copyWith(
      connectionState: BleConnectionState.connecting,
      discoveredDevices: [],
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    state = state.copyWith(
      connectionState: BleConnectionState.connected,
      connectedDevice: device,
      heartRate: 72,
    );

    // Start simulated heart-rate stream from wearable
    _startHeartRateStream();

    debugPrint('[BLE] Connected to ${device.name} (${device.macAddress})');
  }

  void disconnect() {
    _hrTimer?.cancel();
    _hrTimer = null;
    state = state.copyWith(
      connectionState: BleConnectionState.disconnected,
      clearDevice:     true,
      clearHr:         true,
    );
  }

  /// Simulates live heart-rate data from the wearable every 3 seconds.
  void _startHeartRateStream() {
    int baseHr = 72;
    _hrTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      // Jitter ±5 bpm to simulate a real sensor
      final jitter = (DateTime.now().millisecond % 11) - 5;
      baseHr = (baseHr + jitter).clamp(55, 130);
      state = state.copyWith(heartRate: baseHr);
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _hrTimer?.cancel();
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    super.dispose();
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

final bleProvider = StateNotifierProvider<BleNotifier, BleState>((ref) {
  return BleNotifier();
});
