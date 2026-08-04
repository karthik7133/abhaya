import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkQuality { excellent, good, poor, offline }

class NetworkState {
  final List<ConnectivityResult> connectivityResults;
  final NetworkQuality quality;
  final bool isOffline;

  const NetworkState({
    this.connectivityResults = const [ConnectivityResult.none],
    this.quality = NetworkQuality.offline,
    this.isOffline = true,
  });

  NetworkState copyWith({
    List<ConnectivityResult>? connectivityResults,
    NetworkQuality? quality,
    bool? isOffline,
  }) {
    return NetworkState(
      connectivityResults: connectivityResults ?? this.connectivityResults,
      quality: quality ?? this.quality,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class NetworkProvider extends StateNotifier<NetworkState> {
  NetworkProvider() : super(const NetworkState()) {
    _init();
  }

  void _init() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateState(results);
    });
    Connectivity().checkConnectivity().then(_updateState);
  }

  void _updateState(List<ConnectivityResult> results) {
    bool offline = results.contains(ConnectivityResult.none) && results.length == 1;
    
    // Simplistic quality assignment based on connection type.
    // Real implementation could include latency checks (ping).
    NetworkQuality quality = offline ? NetworkQuality.offline : NetworkQuality.good;
    
    if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)) {
      quality = NetworkQuality.excellent;
    } else if (results.contains(ConnectivityResult.mobile)) {
       quality = NetworkQuality.good;
    }

    state = state.copyWith(
      connectivityResults: results,
      isOffline: offline,
      quality: quality,
    );
  }
}

final networkProvider = StateNotifierProvider<NetworkProvider, NetworkState>((ref) {
  return NetworkProvider();
});
