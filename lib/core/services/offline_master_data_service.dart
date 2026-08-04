import 'dart:convert';
import 'cache_manager.dart';

class OfflineMasterDataService {
  static const String _statesKey = 'master_data_states';
  static const String _districtsKey = 'master_data_districts';
  static const String _policeStationsKey = 'master_data_police_stations';

  final CacheManager _cache;

  OfflineMasterDataService(this._cache);

  // ─── Save Data ──────────────────────────────────────────────────────────────

  Future<void> saveStates(List<String> states) async {
    await _cache.setString(_statesKey, jsonEncode(states));
  }

  Future<void> saveDistricts(String state, List<String> districts) async {
    final key = '${_districtsKey}_$state';
    await _cache.setString(key, jsonEncode(districts));
  }

  Future<void> savePoliceStations(String district, List<Map<String, dynamic>> stations) async {
    final key = '${_policeStationsKey}_$district';
    await _cache.setString(key, jsonEncode(stations));
  }

  // ─── Fetch Data ─────────────────────────────────────────────────────────────

  List<String> getStates() {
    final str = _cache.getString(_statesKey);
    if (str != null) {
      return List<String>.from(jsonDecode(str));
    }
    return [];
  }

  List<String> getDistricts(String state) {
    final key = '${_districtsKey}_$state';
    final str = _cache.getString(key);
    if (str != null) {
      return List<String>.from(jsonDecode(str));
    }
    return [];
  }

  List<Map<String, dynamic>> getPoliceStations(String district) {
    final key = '${_policeStationsKey}_$district';
    final str = _cache.getString(key);
    if (str != null) {
      final List<dynamic> decoded = jsonDecode(str);
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── Synchronization ────────────────────────────────────────────────────────

  /// Intended to be called when the app launches and network is available
  Future<void> syncMasterData(Future<Map<String, dynamic>> Function() fetchFromApi) async {
    try {
      final data = await fetchFromApi();
      // Example structure expected from API
      if (data.containsKey('states')) {
        await saveStates(List<String>.from(data['states']));
      }
      // Populate districts and stations similarly...
    } catch (e) {
      // Failed to sync, will rely on cached data
    }
  }
}
