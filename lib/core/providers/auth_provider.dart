import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final String? verificationId; // Used for OTP

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.verificationId,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    String? verificationId,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  AuthProvider() : super(const AuthState()) {
    _init();
  }

  void _init() {
    AuthService.authStateChanges.listen((user) {
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
      }
    });
  }

  Future<void> signInAsGuest() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await AuthService.signInAnonymously();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> requestOTP(String phoneNumber) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await AuthService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (e) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: e.message ?? 'Verification failed',
          );
        },
        codeSent: (verificationId, resendToken) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated, 
            verificationId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> verifyOTP(String smsCode) async {
    if (state.verificationId == null) return;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await AuthService.verifyOTP(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid OTP',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    await AuthService.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});
