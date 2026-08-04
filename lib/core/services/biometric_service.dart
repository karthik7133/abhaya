import 'package:flutter/foundation.dart';
// Note: In a real app, this would use the `local_auth` package.
// We are mocking it here for the MVP architecture.

class BiometricService {
  /// Checks if biometrics are available on the device
  static Future<bool> isBiometricAvailable() async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 200));
    return true; // Assume true for testing
  }

  /// Authenticates the user using biometrics (FaceID/TouchID)
  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      // Mock implementation of local_auth
      debugPrint('[BiometricService] Requesting biometric auth for: $localizedReason');
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulate successful auth
      return true;
    } catch (e) {
      debugPrint('[BiometricService] Auth error: $e');
      return false;
    }
  }
}
