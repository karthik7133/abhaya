import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Telemetry Data Model ─────────────────────────────────────────────────────

class TelemetrySnapshot {
  final double? latitude;
  final double? longitude;
  final double? speed;
  final double? accuracy;
  final double? altitude;
  final DateTime timestamp;
  final bool hasLocation;

  const TelemetrySnapshot({
    this.latitude,
    this.longitude,
    this.speed,
    this.accuracy,
    this.altitude,
    required this.timestamp,
    this.hasLocation = false,
  });

  factory TelemetrySnapshot.empty() => TelemetrySnapshot(
        timestamp: DateTime.now(),
        hasLocation: false,
      );

  factory TelemetrySnapshot.fromMap(Map<String, dynamic> map) {
    return TelemetrySnapshot(
      latitude:    map['lat']      as double?,
      longitude:   map['lng']      as double?,
      speed:       map['speed']    as double?,
      accuracy:    map['accuracy'] as double?,
      altitude:    map['altitude'] as double?,
      timestamp:   DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      hasLocation: map['lat'] != null,
    );
  }

  factory TelemetrySnapshot.fromPosition(Position p) => TelemetrySnapshot(
        latitude:    p.latitude,
        longitude:   p.longitude,
        speed:       p.speed,
        accuracy:    p.accuracy,
        altitude:    p.altitude,
        timestamp:   p.timestamp,
        hasLocation: true,
      );

  String get speedFormatted {
    if (speed == null) return '--';
    if (speed! < 1.0) return '0.0 km/h'; // Filter out GPS noise (speeds < 3.6 km/h)
    return '${(speed! * 3.6).toStringAsFixed(1)} km/h';
  }

  String get locationFormatted => hasLocation
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'Unavailable';
}

// ─── Motion Event Model ───────────────────────────────────────────────────────

class MotionAlert {
  final double magnitude;
  final String type; // 'impact' | 'rotation'
  final DateTime timestamp;

  const MotionAlert({
    required this.magnitude,
    required this.type,
    required this.timestamp,
  });
}

// ─── Guardian Status ──────────────────────────────────────────────────────────

enum GuardianStatus { idle, starting, active, error }

// ─── Guardian State ───────────────────────────────────────────────────────────

class GuardianState {
  final GuardianStatus status;
  final TelemetrySnapshot telemetry;
  final MotionAlert? lastMotionAlert;
  final bool locationPermissionGranted;
  final String? errorMessage;
  final double threatScore;
  final bool isEmergency;

  const GuardianState({
    this.status = GuardianStatus.idle,
    required this.telemetry,
    this.lastMotionAlert,
    this.locationPermissionGranted = false,
    this.errorMessage,
    this.threatScore = 0.0,
    this.isEmergency = false,
  });

  bool get isActive => status == GuardianStatus.active;

  GuardianState copyWith({
    GuardianStatus? status,
    TelemetrySnapshot? telemetry,
    MotionAlert? lastMotionAlert,
    bool? locationPermissionGranted,
    String? errorMessage,
    double? threatScore,
    bool? isEmergency,
    bool clearMotionAlert = false,
    bool clearError = false,
  }) {
    return GuardianState(
      status:                    status ?? this.status,
      telemetry:                 telemetry ?? this.telemetry,
      lastMotionAlert:           clearMotionAlert ? null : (lastMotionAlert ?? this.lastMotionAlert),
      locationPermissionGranted: locationPermissionGranted ?? this.locationPermissionGranted,
      errorMessage:              clearError ? null : (errorMessage ?? this.errorMessage),
      threatScore:               threatScore ?? this.threatScore,
      isEmergency:               isEmergency ?? this.isEmergency,
    );
  }
}

// ─── Guardian Notifier ────────────────────────────────────────────────────────

class GuardianNotifier extends StateNotifier<GuardianState> {
  final FlutterBackgroundService _service = FlutterBackgroundService();
  StreamSubscription? _telemetrySub;
  StreamSubscription? _motionSub;
  StreamSubscription? _rotationSub;
  StreamSubscription? _threatScoreSub;
  StreamSubscription? _emergencySub;

  // Direct GPS stream fallback when background service fails
  StreamSubscription<Position>? _directGpsSub;
  Timer? _gpsFallbackTimer;

  GuardianNotifier()
      : super(GuardianState(telemetry: TelemetrySnapshot.empty()));

  Future<void> startGuardian() async {
    state = state.copyWith(status: GuardianStatus.starting, clearError: true);

    // ── Step 1: Request all permissions from main thread ──────────────────────
    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      state = state.copyWith(
        status: GuardianStatus.error,
        errorMessage: 'Location permission denied. Please enable it in Settings.',
      );
      return;
    }
    state = state.copyWith(locationPermissionGranted: true);

    // Also request notification permission (Android 13+)
    await Permission.notification.request();

    // ── Step 2: Try to verify location service is actually ON ─────────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: GuardianStatus.error,
        errorMessage: 'GPS is turned off. Please enable Location Services.',
      );
      return;
    }

    // ── Step 3: Mark active immediately so UI updates ─────────────────────────
    state = state.copyWith(status: GuardianStatus.active);

    // ── Step 4: Start direct GPS stream (works without background service) ────
    _startDirectGpsStream();

    // ── Step 5: Also try the background service (optional — sensor fusion) ────
    try {
      final started = await _service.startService();
      if (started) {
        _bindServiceStreams();
        debugPrint('[Guardian] Background service started successfully');
      } else {
        debugPrint('[Guardian] Background service failed to start — using direct GPS');
      }
    } catch (e) {
      // Background service failed (SecurityException etc.) — that's OK
      // Direct GPS stream is already running
      debugPrint('[Guardian] Background service error: $e — continuing with direct GPS');
    }
  }

  /// Direct GPS streaming without background service.
  /// Updates telemetry every 5 seconds using Geolocator.
  void _startDirectGpsStream() {
    // Show last known position immediately (instant — no network needed)
    Geolocator.getLastKnownPosition().then((pos) {
      if (pos != null && mounted) {
        state = state.copyWith(
          telemetry: TelemetrySnapshot.fromPosition(pos),
        );
      }
    }).catchError((_) {});

    // Then start streaming live updates
    _directGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres
      ),
    ).listen((position) {
      if (mounted) {
        state = state.copyWith(
          telemetry: TelemetrySnapshot.fromPosition(position),
        );
        _updateThreatFromContext();
      }
    }, onError: (e) {
      debugPrint('[Guardian] GPS stream error: $e');
      // Fall back to polling
      _gpsFallbackTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchGpsNow());
    });

    // Also poll once immediately as backup
    _fetchGpsNow();
  }

  Future<void> _fetchGpsNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        state = state.copyWith(
          telemetry: TelemetrySnapshot.fromPosition(position),
        );
        _updateThreatFromContext();
      }
    } catch (e) {
      // On timeout try last known position silently
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          state = state.copyWith(telemetry: TelemetrySnapshot.fromPosition(last));
        }
      } catch (_) {}
    }
  }

  void _updateThreatFromContext() {
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour <= 5;
    // Blend current score with time-of-day heuristic
    final timeScore = isNight ? 25.0 : 5.0;
    final blended = (state.threatScore * 0.7 + timeScore * 0.3).clamp(0.0, 100.0);
    state = state.copyWith(threatScore: blended);
  }

  Future<void> stopGuardian() async {
    // Cancel direct GPS
    _directGpsSub?.cancel();
    _gpsFallbackTimer?.cancel();
    _directGpsSub = null;
    _gpsFallbackTimer = null;

    // Stop background service
    try {
      _service.invoke('stopService');
    } catch (_) {}

    await _telemetrySub?.cancel();
    await _motionSub?.cancel();
    await _rotationSub?.cancel();
    await _threatScoreSub?.cancel();
    await _emergencySub?.cancel();

    state = state.copyWith(
      status:           GuardianStatus.idle,
      telemetry:        TelemetrySnapshot.empty(),
      threatScore:      0.0,
      isEmergency:      false,
      clearMotionAlert: true,
    );
  }

  void _bindServiceStreams() {
    // GPS from background service (overrides direct GPS when available)
    _telemetrySub = _service.on('updateTelemetry').listen((event) {
      if (event == null) return;
      state = state.copyWith(
        telemetry: TelemetrySnapshot.fromMap(Map<String, dynamic>.from(event)),
      );
    });

    _motionSub = _service.on('abnormalMotionDetected').listen((event) {
      if (event == null) return;
      state = state.copyWith(
        lastMotionAlert: MotionAlert(
          magnitude: (event['acceleration'] as num).toDouble(),
          type:      'impact',
          timestamp: DateTime.tryParse(event['timestamp'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    });

    _rotationSub = _service.on('abnormalRotationDetected').listen((event) {
      if (event == null) return;
      state = state.copyWith(
        lastMotionAlert: MotionAlert(
          magnitude: (event['rotation'] as num).toDouble(),
          type:      'rotation',
          timestamp: DateTime.tryParse(event['timestamp'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    });

    _threatScoreSub = _service.on('updateThreatScore').listen((event) {
      if (event == null) return;
      final score = (event['score'] as num).toDouble();
      state = state.copyWith(threatScore: score);
    });

    _emergencySub = _service.on('triggerEmergency').listen((event) {
      if (event == null) return;
      state = state.copyWith(isEmergency: true);
    });
  }

  void clearMotionAlert() => state = state.copyWith(clearMotionAlert: true);
  void triggerEmergency() => state = state.copyWith(isEmergency: true);
  void dismissEmergency() => state = state.copyWith(isEmergency: false);

  @override
  void dispose() {
    _directGpsSub?.cancel();
    _gpsFallbackTimer?.cancel();
    _telemetrySub?.cancel();
    _motionSub?.cancel();
    _rotationSub?.cancel();
    _threatScoreSub?.cancel();
    _emergencySub?.cancel();
    super.dispose();
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

final guardianProvider =
    StateNotifierProvider<GuardianNotifier, GuardianState>((ref) {
  return GuardianNotifier();
});
