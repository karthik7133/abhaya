import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../ml/threat_fusion_engine.dart';
import '../ml/audio_classifier.dart';

// ─── Channel & Notification Constants ────────────────────────────────────────

const String _kChannelId   = 'abhaya_guardian_channel';
const String _kChannelName = 'Guardian Active Services';
const int    _kNotifId     = 888;

// ─── Public API ───────────────────────────────────────────────────────────────

/// Initialize the GuardianService engine. Call once in `main()` before runApp.
/// Configures the foreground service notification channel and registers the
/// background isolate entry point. The service does NOT auto-start — the user
/// must explicitly enable Guardian mode from the HomeScreen.
Future<void> initializeGuardianService() async {
  final service = FlutterBackgroundService();

  // Android: create the high-priority notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _kChannelId,
    _kChannelName,
    description: 'Continuously monitoring threat vectors.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin notifPlugin =
      FlutterLocalNotificationsPlugin();
  await notifPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _kChannelId,
      initialNotificationTitle: 'Abhaya Guardian',
      initialNotificationContent: 'Initializing threat sensors...',
      foregroundServiceNotificationId: _kNotifId,
      foregroundServiceTypes: [
        AndroidForegroundType.location,
        AndroidForegroundType.microphone,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onStart,
      onBackground: _onIosBackground,
    ),
  );
}

// ─── iOS Background Handler ───────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ─── Background Isolate Entry Point ──────────────────────────────────────────

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // ── Phase 3: Threat Fusion Engine & Audio Classifier ──────────────────────
  final fusionEngine    = ThreatFusionEngine();
  final audioClassifier = AudioClassifier();
  await audioClassifier.initialize();

  // Rolling max-acceleration shared between accel stream and audio callback
  double currentMaxAccel = 0.0;

  // ── Stream subscriptions (declared early for cleanup closure) ─────────────
  StreamSubscription<AccelerometerEvent>? accelSub;
  StreamSubscription<GyroscopeEvent>?     gyroSub;
  StreamSubscription<Position>?           positionSub;
  Position? currentPosition;

  // ── Service stop handler ──────────────────────────────────────────────────
  service.on('stopService').listen((_) {
    audioClassifier.stop();
    accelSub?.cancel();
    gyroSub?.cancel();
    positionSub?.cancel();
    fusionEngine.reset();
    service.stopSelf();
  });

  // ── Location permission ───────────────────────────────────────────────────
  bool locationEnabled = await Geolocator.isLocationServiceEnabled();
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  final bool canUseLocation = locationEnabled &&
      (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse);

  if (canUseLocation) {
    positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      currentPosition = position;
    }, onError: (e) {
      debugPrint('[Guardian] Location stream error: $e');
    });
  }

  // ── Telemetry & Notification Loop ───────────────────────────────────────
  int lastNotificationScore = -1;
  String lastLevelLabel = '';

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) return;

      final position = currentPosition;

      final score = fusionEngine.currentScore.toInt();
      final levelLabel = score >= ThreatFusionEngine.criticalThreshold
          ? '🔴 CRITICAL'
          : score >= ThreatFusionEngine.warningThreshold
              ? '🟡 ELEVATED'
              : '🟢 SAFE';

      if (lastLevelLabel != levelLabel || (lastNotificationScore - score).abs() >= 10) {
        lastLevelLabel = levelLabel;
        lastNotificationScore = score;

        service.setForegroundNotificationInfo(
          title: 'Abhaya Guardian — $levelLabel',
          content: position != null
              ? 'Score: $score | ${position.speed.toStringAsFixed(1)} m/s'
              : 'Threat Score: $score | Monitoring...',
        );
      }

      service.invoke('updateTelemetry', {
        'lat':       position?.latitude,
        'lng':       position?.longitude,
        'speed':     position?.speed,
        'accuracy':  position?.accuracy,
        'altitude':  position?.altitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  });

  // ── Accelerometer — feeds both anomaly detection & fusion engine ──────────
  accelSub = accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen((AccelerometerEvent event) {
    final mag = event.x.abs() + event.y.abs() + event.z.abs();
    currentMaxAccel = mag; // shared with audio callback

    if (mag > 30.0) {
      service.invoke('abnormalMotionDetected', {
        'acceleration': mag,
        'x':            event.x,
        'y':            event.y,
        'z':            event.z,
        'timestamp':    DateTime.now().toIso8601String(),
      });
    }
  });

  // ── Gyroscope — rapid rotation detection ─────────────────────────────────
  gyroSub = gyroscopeEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen((GyroscopeEvent event) {
    final rotMag = event.x.abs() + event.y.abs() + event.z.abs();
    if (rotMag > 15.0) {
      service.invoke('abnormalRotationDetected', {
        'rotation':  rotMag,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  });

  // ── Audio Inference — drives the Threat Fusion Engine ────────────────────
  // Runs on every 1-second audio window; uses TFLite model or amplitude
  // heuristic fallback. The resulting score is broadcast to the main UI isolate.
  await audioClassifier.startInferenceStream((bool isDistress) {
    final score = fusionEngine.evaluateTelemetry(
      audioDistressDetected: isDistress,
      maxAcceleration:       currentMaxAccel,
      timestamp:             DateTime.now(),
    );

    service.invoke('updateThreatScore', {'score': score});

    // Cross the critical threshold → trigger automated emergency
    if (score >= ThreatFusionEngine.criticalThreshold) {
      service.invoke('triggerEmergency', {
        'score':     score,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  });
}
