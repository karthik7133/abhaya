import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'telemetry_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─── Route Type & Option ──────────────────────────────────────────────────────

enum SafeRouteType { safest, fastest, balanced }

class SafeRouteOption {
  final SafeRouteType type;
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final int safetyScore;

  const SafeRouteOption({
    required this.type,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.safetyScore,
  });
}

// ─── Safe Route State ─────────────────────────────────────────────────────────

class SafeRouteState {
  final String destination;
  final SafeRouteType selectedRoute;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final List<SafeRouteOption> routes;
  final bool isFetchingRoute;

  const SafeRouteState({
    this.destination = '',
    this.selectedRoute = SafeRouteType.safest,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.routes = const [],
    this.isFetchingRoute = false,
  });

  bool get hasOrigin => originLat != null && originLng != null;
  bool get hasDestination => destination.isNotEmpty && destLat != null && destLng != null;

  SafeRouteOption? get activeRouteOption {
    try {
      return routes.firstWhere((r) => r.type == selectedRoute);
    } catch (_) {
      return routes.isNotEmpty ? routes.first : null;
    }
  }

  List<LatLng> get routePoints => activeRouteOption?.points ?? [];

  double get distanceKm {
    if (activeRouteOption != null) {
      return activeRouteOption!.distanceMeters / 1000.0;
    }
    if (destLat != null && destLng != null && hasOrigin) {
      return _haversine(originLat!, originLng!, destLat!, destLng!);
    }
    return 0.0;
  }

  Duration get estimatedTime {
    if (activeRouteOption != null) {
      return Duration(seconds: activeRouteOption!.durationSeconds);
    }
    final speedKmH = selectedRoute == SafeRouteType.safest ? 4.5 : 6.0;
    final minutes = (distanceKm / speedKmH * 60).round();
    return Duration(minutes: minutes.clamp(3, 90));
  }

  double get routeDistanceKm => distanceKm;

  SafeRouteState copyWith({
    String? destination,
    SafeRouteType? selectedRoute,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    List<SafeRouteOption>? routes,
    bool? isFetchingRoute,
  }) {
    return SafeRouteState(
      destination: destination ?? this.destination,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      routes: routes ?? this.routes,
      isFetchingRoute: isFetchingRoute ?? this.isFetchingRoute,
    );
  }

  static double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;
}

// ─── Safe Route Notifier ──────────────────────────────────────────────────────

class SafeRouteNotifier extends StateNotifier<SafeRouteState> {
  final Ref _ref;

  SafeRouteNotifier(this._ref) : super(const SafeRouteState()) {
    _syncOriginFromGps();
  }

  void _syncOriginFromGps() {
    final telemetry = _ref.read(guardianProvider).telemetry;
    if (telemetry.hasLocation) {
      state = state.copyWith(
        originLat: telemetry.latitude,
        originLng: telemetry.longitude,
      );
    }
  }

  void updateOriginFromTelemetry(TelemetrySnapshot telemetry) {
    if (telemetry.hasLocation) {
      state = state.copyWith(
        originLat: telemetry.latitude,
        originLng: telemetry.longitude,
      );
    }
  }

  Future<void> setDestination(String destination, LatLng destCoords, {LatLng? currentLocFallback}) async {
    state = state.copyWith(
      destination: destination,
      destLat: destCoords.latitude,
      destLng: destCoords.longitude,
      isFetchingRoute: true,
      originLat: state.originLat ?? currentLocFallback?.latitude,
      originLng: state.originLng ?? currentLocFallback?.longitude,
    );
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_safe_route_destination', destination);

    if (state.hasOrigin) {
      await _fetchOSRMRoute(
        LatLng(state.originLat!, state.originLng!),
        destCoords,
      );
    } else {
      state = state.copyWith(isFetchingRoute: false);
    }
  }

  Future<void> _fetchOSRMRoute(LatLng start, LatLng end) async {
    final apiKey = dotenv.env['ORS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('ORS_API_KEY is not set in .env');
      state = state.copyWith(isFetchingRoute: false);
      return;
    }

    try {
      final safestOpt = _fetchORSProfile(start, end, apiKey, 'foot-walking', SafeRouteType.safest, 92);
      final fastestOpt = _fetchORSProfile(start, end, apiKey, 'driving-car', SafeRouteType.fastest, 68);
      final balancedOpt = _fetchORSProfile(start, end, apiKey, 'cycling-regular', SafeRouteType.balanced, 80);

      final results = await Future.wait([safestOpt, fastestOpt, balancedOpt]);
      final validRoutes = results.whereType<SafeRouteOption>().toList();

      if (validRoutes.isNotEmpty) {
        state = state.copyWith(
          routes: validRoutes,
          isFetchingRoute: false,
        );
        return;
      }
    } catch (e) {
      debugPrint('Error fetching ORS routes: $e');
    }
    
    state = state.copyWith(isFetchingRoute: false);
  }

  Future<SafeRouteOption?> _fetchORSProfile(
    LatLng start, LatLng end, String apiKey, String profile, SafeRouteType type, int safetyScore
  ) async {
    try {
      final url = Uri.parse(
          'https://api.openrouteservice.org/v2/directions/$profile?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}');
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final feature = features[0];
          final geometry = feature['geometry']['coordinates'] as List;
          final properties = feature['properties']['segments'][0];

          final points = geometry.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          return SafeRouteOption(
            type: type,
            points: points,
            distanceMeters: (properties['distance'] as num).toDouble(),
            durationSeconds: (properties['duration'] as num).toInt(),
            safetyScore: safetyScore,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch ORS profile $profile: $e');
    }
    return null;
  }

  void selectRoute(SafeRouteType type) {
    state = state.copyWith(selectedRoute: type);
  }

  void clearDestination() {
    state = state.copyWith(
      destination: '',
      destLat: null,
      destLng: null,
      routes: const [],
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final safeRouteProvider =
    StateNotifierProvider<SafeRouteNotifier, SafeRouteState>((ref) {
  final notifier = SafeRouteNotifier(ref);

  // Keep origin synced with live GPS
  ref.listen(guardianProvider.select((s) => s.telemetry), (_, telemetry) {
    notifier.updateOriginFromTelemetry(telemetry);
  });

  return notifier;
});

// ─── Recent Destinations Provider ────────────────────────────────────────────

class RecentDestinationsNotifier extends StateNotifier<List<String>> {
  RecentDestinationsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('recent_destinations') ?? [];
  }

  Future<void> addDestination(String dest) async {
    if (dest.isEmpty) return;
    final updated = [dest, ...state.where((d) => d != dest)].take(5).toList();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_destinations', updated);
  }
}

final recentDestinationsProvider =
    StateNotifierProvider<RecentDestinationsNotifier, List<String>>((ref) {
  return RecentDestinationsNotifier();
});
