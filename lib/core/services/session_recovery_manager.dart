import 'package:flutter/widgets.dart';
import 'cache_manager.dart';

class SessionRecoveryManager {
  static const String _lastRouteKey = 'session_last_route';
  static const String _activeEmergencyKey = 'session_active_emergency';

  final CacheManager _cache;

  SessionRecoveryManager(this._cache);

  /// Saves the last visited route to SharedPreferences
  Future<void> saveLastRoute(String routeName) async {
    await _cache.setString(_lastRouteKey, routeName);
  }

  /// Retrieves the last visited route
  String? getLastRoute() {
    return _cache.getString(_lastRouteKey);
  }

  /// Clears the last visited route
  Future<void> clearLastRoute() async {
    await _cache.remove(_lastRouteKey);
  }

  /// Marks an active emergency to be recovered if the app is killed
  Future<void> setActiveEmergency(bool isActive) async {
    await _cache.setBool(_activeEmergencyKey, isActive);
  }

  /// Checks if there was an active emergency when the app was last closed
  bool hasActiveEmergency() {
    return _cache.getBool(_activeEmergencyKey) ?? false;
  }
}

/// A mixin or observer can be used with GoRouter to automatically save routes.
class RouteRecoveryObserver extends NavigatorObserver {
  final SessionRecoveryManager recoveryManager;

  RouteRecoveryObserver(this.recoveryManager);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      recoveryManager.saveLastRoute(route.settings.name!);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute?.settings.name != null) {
      recoveryManager.saveLastRoute(previousRoute!.settings.name!);
    }
  }
}
