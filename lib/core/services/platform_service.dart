import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class PlatformService {
  // ─── Platform Checks ────────────────────────────────────────────────────────
  
  static bool get isWeb => kIsWeb;
  
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  static bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  static bool get isLinux {
    if (kIsWeb) return false;
    return Platform.isLinux;
  }

  // ─── Environment Checks ─────────────────────────────────────────────────────

  static bool get isDebugMode => kDebugMode;
  static bool get isReleaseMode => kReleaseMode;
  static bool get isProfileMode => kProfileMode;

  // ─── Capabilities ───────────────────────────────────────────────────────────

  /// Can the current platform run background tasks natively using dart UI isolates?
  static bool get supportsBackgroundTasks {
    return isAndroid || isIOS;
  }

  /// Does the platform support native biometric auth (FaceID/TouchID/Fingerprint)?
  static bool get supportsBiometrics {
    return isAndroid || isIOS || isMacOS || isWindows;
  }
}
