import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Reuse the base URL logic from BackendService
const String _kBaseUrl = kDebugMode
    ? 'http://192.168.1.27:5000/api'
    : 'https://your-production-server.com/api';

enum ApiHealthStatus { unknown, healthy, degraded, down }

class ApiHealthState {
  final ApiHealthStatus status;
  final DateTime lastChecked;
  final int latencyMs;

  const ApiHealthState({
    this.status = ApiHealthStatus.unknown,
    required this.lastChecked,
    this.latencyMs = 0,
  });
}

class ApiHealthProvider extends StateNotifier<ApiHealthState> {
  Timer? _timer;

  ApiHealthProvider() : super(ApiHealthState(lastChecked: DateTime.now())) {
    _init();
  }

  void _init() {
    checkHealth();
    // Poll every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkHealth();
    });
  }

  Future<void> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      // Assuming there's a /health endpoint, or just pinging the base URL
      final response = await http.get(Uri.parse('$_kBaseUrl/health')).timeout(const Duration(seconds: 5));
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        state = ApiHealthState(
          status: ApiHealthStatus.healthy,
          lastChecked: DateTime.now(),
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        state = ApiHealthState(
          status: ApiHealthStatus.degraded,
          lastChecked: DateTime.now(),
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      state = ApiHealthState(
        status: ApiHealthStatus.down,
        lastChecked: DateTime.now(),
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final apiHealthProvider = StateNotifierProvider<ApiHealthProvider, ApiHealthState>((ref) {
  return ApiHealthProvider();
});
