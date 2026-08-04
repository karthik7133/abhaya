import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─── Auth Service ─────────────────────────────────────────────────────────────

/// Stateless wrapper around [FirebaseAuth].
/// All methods are static — no singleton required.
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Phone Auth (OTP) ────────────────────────────────────────────────────────

  /// Sends an OTP to the given phone number.
  /// Callbacks handle the different verification states.
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verifies the OTP code sent to the user.
  static Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ── Guest Auth ──────────────────────────────────────────────────────────────
  
  /// Signs in anonymously for Guest Emergency Mode.
  static Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('[AuthService] Anonymous Sign-In error: $e');
      rethrow;
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────────────

  /// Signs out from Firebase.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Convenience Getters ─────────────────────────────────────────────────────

  /// The currently signed-in Firebase user, or null if unauthenticated.
  static User? get currentUser => _auth.currentUser;

  /// Stream that emits the [User] on login and null on logout.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
