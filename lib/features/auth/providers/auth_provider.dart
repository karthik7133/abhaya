import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/backend_service.dart';

part 'auth_provider.g.dart';

// ─── Auth State ───────────────────────────────────────────────────────────────

enum AuthStatus { idle, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final bool isAuthenticated;
  final bool isAppLocked;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.isAuthenticated = false,
    this.isAppLocked = true, // Default to locked, router decides if biometric is required
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? isAuthenticated,
    bool? isAppLocked,
    bool clearError = false,
  }) {
    return AuthState(
      status:          status          ?? this.status,
      errorMessage:    clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAppLocked:     isAppLocked     ?? this.isAppLocked,
    );
  }
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() => const AuthState();

  /// Sends OTP to the given phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    bool isSignUp = false,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      // Check if account exists before sending OTP
      if (!isSignUp) {
        try {
          final exists = await BackendService.checkPhoneExists(phoneNumber);
          if (!exists) {
            state = state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'No account found with this number. Please create an account.',
            );
            return;
          }
        } catch (backendErr) {
          debugPrint('[Auth] Backend checkPhoneExists warning: $backendErr');
          // If the backend check fails due to cold-start or network, log it but don't block Firebase OTP
        }
      }

      debugPrint('[Auth] Calling AuthService.verifyPhoneNumber for: $phoneNumber');
      await AuthService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          try {
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            await _handleAuthSuccess(userCredential);
          } catch (e) {
            debugPrint('[Auth] Auto-sign-in error: $e');
            state = state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Auto-sign-in failed. Please try manual OTP entry.',
            );
          }
        },
        verificationFailed: (exception) {
          debugPrint('[Auth] Firebase verificationFailed: [${exception.code}] ${exception.message}');
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: _mapFirebaseError(exception),
          );
        },
        codeSent: (verificationId, forceResendingToken) {
          debugPrint('[Auth] Code successfully sent to $phoneNumber. verificationId: $verificationId');
          state = state.copyWith(status: AuthStatus.idle, clearError: true);
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          debugPrint('[Auth] Code auto-retrieval timeout: $verificationId');
        },
      );
    } catch (e) {
      debugPrint('[Auth] Exception during sendOTP: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send OTP: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  /// Verifies the OTP code and signs in the user
  Future<bool> verifyOTP({
    required String verificationId,
    required String smsCode,
    String? name,
    String? email,
    int? age,
    String? gender,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final credential = await AuthService.verifyOTP(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _handleAuthSuccess(credential, name: name, email: email, age: age, gender: gender);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'OTP verification failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> _handleAuthSuccess(
    UserCredential credential, {
    String? name,
    String? email,
    int? age,
    String? gender,
  }) async {
    // Sync user with MongoDB (fire-and-forget, don't block auth flow)
    unawaited(Future(() async {
      try { 
        await BackendService.syncUser(name: name, email: email, age: age, gender: gender); 
      }
      catch (e) { debugPrint('[Auth] Backend sync failed: $e'); }
    }));

    state = state.copyWith(
      status: AuthStatus.authenticated,
      isAuthenticated: true,
      isAppLocked: false,
    );
    return true;
  }

  /// Signs in anonymously for Guest Emergency Mode
  Future<bool> guestSignIn() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final prefs = await SharedPreferences.getInstance();
    try {
      await FirebaseAuth.instance.signInAnonymously();
      await prefs.setBool('is_guest_mode', true);
      state = state.copyWith(status: AuthStatus.authenticated, isAuthenticated: true, isAppLocked: false);
      return true;
    } catch (e) {
      debugPrint('[Auth] Firebase anonymous auth failed, falling back to local guest mode: $e');
      await prefs.setBool('is_guest_mode', true);
      state = state.copyWith(status: AuthStatus.authenticated, isAuthenticated: true, isAppLocked: false);
      return true;
    }
  }

  /// Attempts biometric authentication to unlock the app
  Future<bool> biometricUnlock() async {
    final LocalAuthentication auth = LocalAuthentication();
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: 'Biometrics not supported on this device.');
        return false;
      }
      
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock Abhaya',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      
      if (didAuthenticate) {
        state = state.copyWith(status: AuthStatus.authenticated, isAppLocked: false);
        return true;
      } else {
        state = state.copyWith(status: AuthStatus.idle, clearError: true);
        return false;
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Biometric error: $e');
      return false;
    }
  }

  /// Signs out from both Google and Firebase.
  Future<void> signOut() async {
    await AuthService.signOut();
    state = const AuthState();
  }

  void lockApp() {
    state = state.copyWith(isAppLocked: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true, status: AuthStatus.idle);
  }

  // ── Error Mapping ───────────────────────────────────────────────────────────

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Contact support.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and retry.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please try again.';
      case 'code-expired':
        return 'OTP code expired. Request a new one.';
      case 'app-not-authorized':
        return 'App not authorized in Firebase Console (SHA-1 fingerprint missing or Play Integrity check failed).';
      case 'missing-client-identifier':
        return 'App verification failed. Ensure SHA-1 is added in Firebase Console.';
      case 'captcha-check-failed':
        return 'reCAPTCHA check failed. Ensure Google Play Services are installed.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

// ─── Firebase Auth State Provider ────────────────────────────────────────────

/// Reactive stream of the current Firebase [User].
/// Emits null when signed out, a [User] object when signed in.
/// Used by the router to redirect between /auth and /home.
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges;
});

// ─── Onboarding Provider ──────────────────────────────────────────────────────

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  bool build() => false;

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    state = true;
  }

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }
}
