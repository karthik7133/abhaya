import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_health_provider.dart';
import 'network_provider.dart';

enum AppServiceMode { 
  online,     // Network Good, API Healthy
  degraded,   // Network Poor or API Degraded
  offline     // No Network or API Down
}

class ServiceAvailabilityState {
  final AppServiceMode mode;
  final String message;

  const ServiceAvailabilityState({
    this.mode = AppServiceMode.offline,
    this.message = 'Initializing...',
  });
}

class ServiceAvailabilityProvider extends StateNotifier<ServiceAvailabilityState> {
  final Ref ref;

  ServiceAvailabilityProvider(this.ref) : super(const ServiceAvailabilityState()) {
    _init();
  }

  void _init() {
    ref.listen<NetworkState>(networkProvider, (prev, next) => _evaluateState());
    ref.listen<ApiHealthState>(apiHealthProvider, (prev, next) => _evaluateState());
    _evaluateState();
  }

  void _evaluateState() {
    final network = ref.read(networkProvider);
    final api = ref.read(apiHealthProvider);

    if (network.isOffline || api.status == ApiHealthStatus.down) {
      state = const ServiceAvailabilityState(
        mode: AppServiceMode.offline,
        message: 'You are currently offline. Critical SOS functions remain active.',
      );
    } else if (network.quality == NetworkQuality.poor || api.status == ApiHealthStatus.degraded) {
      state = const ServiceAvailabilityState(
        mode: AppServiceMode.degraded,
        message: 'Connection is weak. Some features may be delayed.',
      );
    } else {
      state = const ServiceAvailabilityState(
        mode: AppServiceMode.online,
        message: 'All systems operational.',
      );
    }
  }
}

final serviceAvailabilityProvider = StateNotifierProvider<ServiceAvailabilityProvider, ServiceAvailabilityState>((ref) {
  return ServiceAvailabilityProvider(ref);
});
