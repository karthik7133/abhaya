import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';

// ─── Background Isolate Handler ───────────────────────────────────────────────

/// Must be a top-level function — runs in a separate isolate when the app is
/// killed or in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // flutter_local_notifications handles the system tray automatically when
  // FCM has a `notification` payload. No extra work needed here.
}

// ─── FCM Alert Model ──────────────────────────────────────────────────────────

/// Typed in-app alert produced from an FCM message payload.
class FcmAlert {
  final String title;
  final String body;
  final FcmAlertType type;

  const FcmAlert({
    required this.title,
    required this.body,
    required this.type,
  });
}

enum FcmAlertType {
  sos,         // critical — red
  threat,      // warning  — amber
  guardian,    // info     — amber
  system,      // info     — teal
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

/// Emits the latest FCM alert that arrived while the app is in the foreground.
/// Null = no pending alert.
final fcmAlertProvider = StateProvider<FcmAlert?>((ref) => null);

/// Exposes the raw FCM message stream (foreground only) as a broadcast stream.
final fcmMessageStreamProvider = StreamProvider<RemoteMessage>((ref) {
  return FcmService.messageStream;
});

/// The device's FCM registration token.
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  return FcmService.getToken();
});

// ─── FCM Service ──────────────────────────────────────────────────────────────

/// Centralises all Firebase Cloud Messaging setup.
/// Call [initialize] once in `main()` after Firebase.initializeApp().
class FcmService {
  static const String _kAlertChannelId   = 'abhaya_alert_channel';
  static const String _kAlertChannelName = 'Abhaya Safety Alerts';

  static final StreamController<RemoteMessage> _controller =
      StreamController<RemoteMessage>.broadcast();

  /// Broadcast stream of FCM messages received while app is in the foreground.
  static Stream<RemoteMessage> get messageStream => _controller.stream;

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<void> initialize(ProviderContainer container) async {
    // Register the background handler first
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permissions (required on iOS; harmless on Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      announcement:  false,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
    );

    // Create the high-importance Android notification channel for FCM
    await _createAndroidChannel();

    // Foreground presentation — show heads-up notification even while app is open
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── Foreground message listener ───────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _controller.add(message);

      // Convert to typed alert and push to Riverpod state so UI can react
      final alert = _buildAlert(message);
      if (alert != null) {
        container.read(fcmAlertProvider.notifier).state = alert;
      }
    });

    // ── Notification tap — app in background ─────────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // TODO: deep-link navigation based on message.data['route'] in Phase 5
    });

    // ── Notification tap — app was terminated ────────────────────────────────
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // app launched from a notification tap — handle similarly
    }

    // Log token for development
    final token = await getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }
  }

  // ── Token ───────────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<void> _createAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _kAlertChannelId,
      _kAlertChannelName,
      description: 'Emergency and safety push alerts from Abhaya.',
      importance:  Importance.max,
      playSound:   true,
    );

    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Maps an FCM [RemoteMessage] to a typed [FcmAlert] based on the
  /// `data.type` field in the message payload.
  static FcmAlert? _buildAlert(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'Abhaya Alert';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        '';

    final typeStr = message.data['type'] as String? ?? 'system';
    final FcmAlertType type;
    switch (typeStr) {
      case 'sos_alert':
        type = FcmAlertType.sos;
        break;
      case 'threat_elevated':
        type = FcmAlertType.threat;
        break;
      case 'guardian_joined':
        type = FcmAlertType.guardian;
        break;
      default:
        type = FcmAlertType.system;
    }

    return FcmAlert(title: title, body: body, type: type);
  }
}
