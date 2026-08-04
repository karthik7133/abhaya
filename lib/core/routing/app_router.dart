import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/lock_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/navigation_shell.dart';
import '../../features/guardians/presentation/guardians_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/chat/presentation/ai_chat_screen.dart';
import '../../features/chat/presentation/guardian_chat_screen.dart';
import '../../features/navigation/presentation/safe_route_screen.dart';
import '../../features/history/presentation/incident_history_screen.dart';
import '../../features/safety_learning/presentation/safety_learning_screen.dart';
import '../../features/privacy/presentation/privacy_settings_screen.dart';
import '../../features/evidence/presentation/evidence_screen.dart';
import '../../features/journey/presentation/journey_guardian_screen.dart';
import '../../features/night_mode/presentation/night_safety_screen.dart';
import '../../features/night_mode/presentation/journey_report_screen.dart';
import '../../features/journey/presentation/journey_history_screen.dart';
import '../../features/incidents/presentation/incident_reporting_screen.dart';
import '../../features/incidents/presentation/media_capture_screen.dart';
import '../permissions/permission_gate_screen.dart';
/// Abhaya declarative router with ShellRoute for persistent glassmorphic nav dock.
///
/// Route hierarchy:
///   /onboarding              → first launch experience
///   /auth                   → Google Sign-In gateway
///   /home                   → home (inside NavigationShell)
///   /guardians              → trust circle (inside NavigationShell)
///   /community              → spatial intel (inside NavigationShell)
///   /profile                → account & settings (inside NavigationShell)

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// ── Auth ChangeNotifier — drives GoRouter refresh on Firebase auth changes ─────

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch firebaseUserProvider so the Provider rebuilds on auth changes,
  // but the real refresh trigger is the _AuthStateListenable below.
  ref.watch(firebaseUserProvider);

  return GoRouter(
    navigatorKey:      _rootNavigatorKey,
    initialLocation:   '/',
    debugLogDiagnostics: false,
    refreshListenable: _AuthStateListenable(),
    redirect: (context, state) async {
      final prefs          = await SharedPreferences.getInstance();
      final onboardingSeen = prefs.getBool('onboarding_complete') ?? false;
      final isGuestMode    = prefs.getBool('is_guest_mode') ?? false;
      final isLoggedIn     = FirebaseAuth.instance.currentUser != null || isGuestMode;
      final permsDone      = prefs.getBool('permissions_granted') ?? false;
      final location       = state.matchedLocation;

      final biometricReq   = await SecureStorageService.getBiometricEnabled();
      
      // ── Step 1: Onboarding gate ────────────────────────────────────────────
      if (!onboardingSeen && location != '/onboarding') {
        return '/onboarding';
      }

      // ── Step 2: Auth gate ──────────────────────────────────────────────────
      if (onboardingSeen && !isLoggedIn && location != '/auth') {
        return '/auth';
      }

      // ── Step 3: Biometric Lock gate ────────────────────────────────────────
      if (isLoggedIn && biometricReq) {
        final authState = ref.read(authNotifierProvider);
        if (authState.isAppLocked && location != '/lock') {
          return '/lock';
        }
      }

      // Logged in & unlocked → skip the auth/lock page if already authenticated
      if (isLoggedIn && (location == '/auth' || location == '/lock')) {
        final authState = ref.read(authNotifierProvider);
        final isLocked = biometricReq && authState.isAppLocked;
        if (!isLocked) {
          return permsDone ? '/home' : '/permissions';
        }
      }

      // ── Step 4: Permissions gate (once per install) ────────────────────────
      if (isLoggedIn && !permsDone && location != '/permissions') {
        return '/permissions';
      }

      // ── Step 5: Root redirect ──────────────────────────────────────────────
      if (onboardingSeen && location == '/') {
        if (!isLoggedIn) return '/auth';
        if (biometricReq && ref.read(authNotifierProvider).isAppLocked) return '/lock';
        return permsDone ? '/home' : '/permissions';
      }

      return null; // allow navigation
    },
    routes: [
      GoRoute(
        path:    '/',
        builder: (_, __) => const SizedBox.shrink(), // handled by redirect
      ),
      GoRoute(
        path:             '/onboarding',
        name:             'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path:             '/auth',
        name:             'auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path:             '/lock',
        name:             'lock',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const LockScreen(),
      ),
      GoRoute(
        path:             '/permissions',
        name:             'permissions',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const PermissionGateScreen(),
      ),

      // ── Full-screen chat routes (push over shell, no nav dock) ─────────────
      GoRoute(
        path:             '/ai-assistant',
        name:             'ai-assistant',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const AiChatScreen(),
      ),
      GoRoute(
        path:             '/guardian-chat',
        name:             'guardian-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => GuardianChatScreen(
          guardianName: state.uri.queryParameters['name'] ?? 'Primary Node (Father)',
          guardianRole: state.uri.queryParameters['role'] ?? 'Guardian',
        ),
      ),
      GoRoute(
        path:             '/safe-route',
        name:             'safe-route',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const SafeRouteScreen(),
      ),
      GoRoute(
        path:             '/incident-history',
        name:             'incident-history',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const IncidentHistoryScreen(),
      ),
      GoRoute(
        path:             '/safety-learning',
        name:             'safety-learning',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const SafetyLearningScreen(),
      ),
      GoRoute(
        path:             '/privacy-settings',
        name:             'privacy-settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path:             '/evidence',
        name:             'evidence',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const EvidenceScreen(),
      ),
      GoRoute(
        path:             '/journey',
        name:             'journey',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, state) => JourneyGuardianScreen(
          initialDestination: state.uri.queryParameters['destination'],
          initialEtaMinutes: int.tryParse(
              state.uri.queryParameters['eta'] ?? ''),
          destLat: double.tryParse(state.uri.queryParameters['destLat'] ?? ''),
          destLng: double.tryParse(state.uri.queryParameters['destLng'] ?? ''),
          initialDistanceKm: double.tryParse(state.uri.queryParameters['distance'] ?? ''),
        ),
      ),
      GoRoute(
        path:             '/night-mode',
        name:             'night-mode',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const NightSafetyScreen(),
      ),
      GoRoute(
        path:             '/incident-report',
        name:             'incident-report',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const IncidentReportingScreen(),
      ),
      GoRoute(
        path:             '/journey-report',
        name:             'journey-report',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, state) => JourneyReportScreen(
          sessionJson: state.uri.queryParameters['session'] ?? '{}',
        ),
      ),
      GoRoute(
        path:             '/journey-history',
        name:             'journey-history',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const JourneyHistoryScreen(),
      ),
      GoRoute(
        path:             '/media-capture',
        name:             'media-capture',
        parentNavigatorKey: _rootNavigatorKey,
        builder:          (_, __) => const MediaCaptureScreen(),
      ),

      // ── Shell: persistent floating nav dock wraps these routes ──────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => NavigationShell(child: child),
        routes: [
          GoRoute(
            path:        '/home',
            name:        'home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path:        '/guardians',
            name:        'guardians',
            pageBuilder: (_, __) => const NoTransitionPage(child: GuardiansScreen()),
          ),
          GoRoute(
            path:        '/community',
            name:        'community',
            pageBuilder: (_, __) => const NoTransitionPage(child: CommunityScreen()),
          ),
          GoRoute(
            path:        '/profile',
            name:        'profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: Text(
          'Route not found: ${state.error}',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    ),
  );
});
