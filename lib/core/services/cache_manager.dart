import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static CacheManager? _instance;
  late SharedPreferences _prefs;

  CacheManager._();

  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      _instance = CacheManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Generic JSON Storage ───────────────────────────────────────────────────
  
  Future<bool> setJson(String key, Map<String, dynamic> data) async {
    return _prefs.setString(key, jsonEncode(data));
  }

  Map<String, dynamic>? getJson(String key) {
    final str = _prefs.getString(key);
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // ─── Primitive Storage ──────────────────────────────────────────────────────

  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);
  int? getInt(String key) => _prefs.getInt(key);

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);

  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);
  double? getDouble(String key) => _prefs.getDouble(key);

  // ─── Cache Management ───────────────────────────────────────────────────────

  Future<bool> remove(String key) => _prefs.remove(key);

  Future<bool> clearAll() => _prefs.clear();
  
  bool containsKey(String key) => _prefs.containsKey(key);
}
