import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/accessibility_provider.dart';
import 'core/services/guardian_service.dart';
import 'core/services/fcm_service.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/local_db_service.dart';
import 'core/services/offline_sync_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (fails silently if file doesn't exist to not crash without key)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not found.');
  }

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Offline DB & Sync ─────────────────────────────────────────────────────
  await LocalDbService.init();
  OfflineSyncService().startListening();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Background Guardian service ───────────────────────────────────────────
  // Service does NOT auto-start — user enables from the home dashboard.
  await initializeGuardianService();

  // ── FCM — must be done AFTER ProviderContainer is available ───────────────
  // We create a temporary container to pass into FcmService so it can write
  // to fcmAlertProvider from the background.
  final container = ProviderContainer();
  await FcmService.initialize(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AbhayaApp(),
    ),
  );
}

class AbhayaApp extends ConsumerStatefulWidget {
  const AbhayaApp({super.key});

  @override
  ConsumerState<AbhayaApp> createState() => _AbhayaAppState();
}

class _AbhayaAppState extends ConsumerState<AbhayaApp> {
  late final AppLifecycleListener _listener;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onStateChange: _onStateChanged,
    );
  }

  void _onStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final diff = DateTime.now().difference(_pausedTime!);
        // Require biometric if app was in background for > 3 minutes (180s)
        if (diff.inSeconds > 180) {
          final settings = ref.read(settingsProvider);
          if (settings.requireBiometric) {
            ref.read(authNotifierProvider.notifier).lockApp();
          }
        }
      }
      _pausedTime = null;
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final accessibility = ref.watch(accessibilityProvider);
    
    final baseTheme = accessibility.highContrastEnabled 
        ? AppTheme.highContrast 
        : AppTheme.dark;
    
    return MaterialApp.router(
      title: 'Abhaya — AI Safety Ecosystem',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: accessibility.textScaleFactorOverride,
          ),
          child: child!,
        );
      },
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('te'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
