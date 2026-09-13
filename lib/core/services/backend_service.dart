import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'local_db_service.dart';

// ─── Configuration ────────────────────────────────────────────────────────────
// IMPORTANT: Replace with your machine's local IP address (not localhost/10.0.2.2)
// Find it: Windows → run "ipconfig" → look for "IPv4 Address" on your WiFi adapter
// Example: 'http://192.168.1.10:5000/api'
// ── Network addresses (from ipconfig) ────────────────────────────────────────
// • WiFi adapter     → 192.168.1.22   ← phone on same router  (USE THIS)
// • Hotspot adapter  → 192.168.137.1  ← phone using PC hotspot (swap if needed)
const String _kBaseUrl = 'https://abhaya-nzk5.onrender.com/api';

// ─── Response Models ──────────────────────────────────────────────────────────

class ChatResponse {
  final Map<String, dynamic> userMessage;
  final Map<String, dynamic> aiMessage;
  final bool crisisResourcesShown;

  ChatResponse({
    required this.userMessage,
    required this.aiMessage,
    required this.crisisResourcesShown,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final userMsg = json['userMessage'] as Map<String, dynamic>? ?? {};
    final aiMsg   = json['aiMessage']  as Map<String, dynamic>? ?? {};
    return ChatResponse(
      userMessage:          userMsg,
      aiMessage:            aiMsg,
      // crisisResourcesShown lives on the aiMessage document itself
      crisisResourcesShown: aiMsg['crisisResourcesShown'] as bool? ?? false,
    );
  }
}

// ─── BackendService ───────────────────────────────────────────────────────────

class BackendService {
  // ── Auth Header ──────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('[BackendService] User not signed in.');
    final token = await user.getIdToken(true); // force refresh
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Generic helpers ──────────────────────────────────────────────────────────

  static bool _isNetworkError(dynamic e) {
    final s = e.toString();
    return e is SocketException || s.contains('Failed host lookup') || s.contains('Connection refused') || s.contains('ClientException');
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final res = await http.get(Uri.parse('$_kBaseUrl$path'), headers: await _headers());
      _checkStatus(res);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await LocalDbService.cacheGetResponse(path, data);
      return data;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await LocalDbService.getCachedResponse(path);
        if (cached != null) return cached as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> _getList(String path) async {
    try {
      final res = await http.get(Uri.parse('$_kBaseUrl$path'), headers: await _headers());
      _checkStatus(res);
      final data = jsonDecode(res.body) as List<dynamic>;
      await LocalDbService.cacheGetResponse(path, data);
      return data;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await LocalDbService.getCachedResponse(path);
        if (cached != null) return cached as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> _delete(String path, Map<String, dynamic> body) async {
    final req = http.Request('DELETE', Uri.parse('$_kBaseUrl$path'))
      ..headers.addAll(await _headers())
      ..body = jsonEncode(body);
    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);
    _checkStatus(res);
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      final msg = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Unknown error';
      throw Exception('[BackendService] ${res.statusCode}: $msg');
    }
  }

  // ── Users ────────────────────────────────────────────────────────────────────

  /// Check if a user with the given phone number exists (public endpoint).
  static Future<bool> checkPhoneExists(String phone) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/users/check-phone'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['exists'] as bool;
  }

  /// Call once after login to register or update the user record.
  static Future<Map<String, dynamic>> syncUser({
    String? fcmToken, 
    String? phone, 
    String? name, 
    String? email,
    int? age, 
    String? gender,
  }) =>
      _post('/users/sync', {
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (phone != null) 'phone': phone,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
      });

  static Future<Map<String, dynamic>> getMe() => _get('/users/me');

  static Future<List<dynamic>> searchUsers(String query) => _getList('/users/search?q=$query');

  static Future<void> updateFcmToken(String token) =>
      _post('/users/fcm-token', {'fcmToken': token});

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) =>
      _put('/users/settings', {'settings': settings});

  /// Upload a profile photo from a local [File] to Cloudinary.
  static Future<String> uploadAvatar(File imageFile) async {
    final hdrs = await _headers();
    hdrs.remove('Content-Type'); // let multipart set its own
    final req = http.MultipartRequest('POST', Uri.parse('$_kBaseUrl/users/avatar'))
      ..headers.addAll(hdrs)
      ..files.add(await http.MultipartFile.fromPath('avatar', imageFile.path));
    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['photoUrl'] as String;
  }

  // ── Connections ──────────────────────────────────────────────────────────────

  /// role = 'guardian' → I want to guard [targetPhone]
  /// role = 'child'    → I want [targetPhone] to guard me
  static Future<void> sendConnectionRequest(String targetPhone, String role) =>
      _post('/connections/request', {'targetPhone': targetPhone, 'role': role});

  static Future<void> respondToConnection(String fromUid, bool accept) =>
      _post('/connections/respond', {'fromUid': fromUid, 'accept': accept});

  static Future<List<dynamic>> getPendingRequests() =>
      _getList('/connections/pending');

  static Future<Map<String, dynamic>> getMyNetwork() =>
      _get('/connections/my-network');

  static Future<void> removeConnection(String targetUid) =>
      _delete('/connections/remove', {'targetUid': targetUid});

  // ── Chat ─────────────────────────────────────────────────────────────────────

  /// Returns a Map with { history: List, page, total } for the caller.
  static Future<Map<String, dynamic>> getChatHistory({int page = 1}) async {
    final list = await _getList('/chat/history?page=$page&limit=50');
    return {'history': list, 'page': page};
  }

  static Future<ChatResponse> sendChatMessage(String text) async {
    // AI inference can take up to 2 minutes on first cold-start
    final client = http.Client();
    try {
      final headers = await _headers();
      final res = await client
          .post(
            Uri.parse('$_kBaseUrl/chat/send'),
            headers: headers,
            body: jsonEncode({'text': text}),
          )
          .timeout(
            const Duration(seconds: 150),
            onTimeout: () => throw Exception('AI is still warming up — please try again in a moment.'),
          );
      _checkStatus(res);
      return ChatResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  // ── Emergency ────────────────────────────────────────────────────────────────

  static Future<void> triggerSos({double? lat, double? lng}) =>
      _post('/emergency/sos', {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

  static Future<void> reportThreatScore({
    required double score,
    bool? audioDistress,
    double? maxAcceleration,
    double? lat,
    double? lng,
  }) =>
      _post('/emergency/threat-score', {
        'score': score,
        if (audioDistress != null) 'audioDistress': audioDistress,
        if (maxAcceleration != null) 'maxAcceleration': maxAcceleration,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

  static Future<List<dynamic>> getIncidentHistory() =>
      _getList('/emergency/history');

  static Future<void> resolveEvent(String eventId, {String? notes}) =>
      _put('/emergency/$eventId/resolve', {if (notes != null) 'notes': notes});

  static Future<void> dismissEvent(String eventId) =>
      _put('/emergency/$eventId/dismiss', {});

  // ── Location ─────────────────────────────────────────────────────────────────

  static Future<void> updateLiveLocation({
    required double lat,
    required double lng,
    double? speed,
    bool isGuardianActive = false,
    bool isOfflineSync = false,
  }) async {
    try {
      await _post('/location/update', {
        'lat': lat,
        'lng': lng,
        if (speed != null) 'speed': speed,
        'isGuardianActive': isGuardianActive,
      });
    } catch (e) {
      if (!isOfflineSync && _isNetworkError(e)) {
        await LocalDbService.enqueueRequest('updateLiveLocation', {
          'lat': lat, 'lng': lng, 'speed': speed, 'isGuardianActive': isGuardianActive
        });
      } else {
        rethrow;
      }
    }
  }

  static Future<List<dynamic>> getGuardianFeed() =>
      _getList('/location/feed');

  // ── Mood ─────────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getMoodTrends({int days = 30}) =>
      _getList('/mood/trends?days=$days');

  static Future<Map<String, dynamic>> getTodayMood() =>
      _get('/mood/today');

  // ── Incident Reports ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitIncidentReport({
    required String category,
    required String severity,
    required String description,
    double? lat,
    double? lng,
    bool anonymous = false,
    bool notifyAuthorities = false,
    String? mediaBase64,
    bool isOfflineSync = false,
  }) async {
    try {
      final hdrs = await _headers();
      hdrs.remove('Content-Type');

      final req = http.MultipartRequest('POST', Uri.parse('$_kBaseUrl/incidents/report'))
        ..headers.addAll(hdrs)
        ..fields['category'] = category
        ..fields['severity'] = severity
        ..fields['description'] = description
        ..fields['anonymous'] = anonymous.toString()
        ..fields['notifyAuthorities'] = notifyAuthorities.toString();

      if (lat != null && lng != null) {
        req.fields['location'] = jsonEncode({'lat': lat, 'lng': lng});
      }

      if (mediaBase64 != null && mediaBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(mediaBase64);
          req.files.add(http.MultipartFile.fromBytes('media', bytes));
        } catch (e) {
          debugPrint('[BackendService] Failed to decode base64 media: $e');
        }
      }

      final streamedRes = await req.send();
      final res = await http.Response.fromStream(streamedRes);
      _checkStatus(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      if (!isOfflineSync && _isNetworkError(e)) {
        await LocalDbService.enqueueRequest('submitIncidentReport', {
          'category': category,
          'severity': severity,
          'description': description,
          'lat': lat,
          'lng': lng,
          'anonymous': anonymous,
          'notifyAuthorities': notifyAuthorities,
          'mediaBase64': mediaBase64,
        });
        return {'success': true, 'offlineQueued': true};
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getMyIncidentReports() =>
      _getList('/incidents/my-reports');

  // ── User Data ─────────────────────────────────────────────────────────────────

  /// Permanently delete all user data from the backend.
  static Future<void> clearAllIncidents() async {
    await _delete('/incidents/all', {});
  }

  static Future<void> deleteAllData() async {
    await _delete('/user/data', {});
  }

  // ── Journeys ────────────────────────────────────────────────────────────────
  
  static Future<Map<String, dynamic>> saveJourney(Map<String, dynamic> journeyData) async {
    return await _post('/journeys', journeyData);
  }

  static Future<List<dynamic>> getJourneys() async {
    final res = await _get('/journeys');
    return res['journeys'] as List<dynamic>;
  }

  // ── Contacts & Trusted Network ───────────────────────────────────────────────

  /// Syncs and uploads all device phonebook contacts to backend MongoDB under this user.
  static Future<Map<String, dynamic>> syncDeviceContacts(List<Map<String, dynamic>> contacts) async {
    return await _post('/contacts/sync', {'contacts': contacts});
  }

  /// Retrieves synced device contacts for the current user.
  static Future<List<dynamic>> getDeviceContacts({String? query, int limit = 200}) async {
    final queryParam = query != null && query.isNotEmpty ? '?q=${Uri.encodeComponent(query)}&limit=$limit' : '?limit=$limit';
    final res = await _get('/contacts$queryParam');
    return (res['contacts'] as List<dynamic>?) ?? [];
  }

  /// Retrieves all user-selected trusted emergency contacts from backend MongoDB.
  static Future<List<dynamic>> getTrustedContacts() async {
    final res = await _get('/contacts/trusted');
    return (res['trustedContacts'] as List<dynamic>?) ?? [];
  }

  /// Adds or updates a contact in the trusted contacts table.
  static Future<Map<String, dynamic>> addTrustedContact({
    required String name,
    required String phone,
    String relationship = 'Emergency Contact',
    bool notifyOnSos = true,
    bool notifyOnThreat = true,
    bool notifyOnNightMode = true,
  }) async {
    return await _post('/contacts/trusted', {
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'notifyOnSos': notifyOnSos,
      'notifyOnThreat': notifyOnThreat,
      'notifyOnNightMode': notifyOnNightMode,
    });
  }

  /// Updates settings for a trusted contact by database ID.
  static Future<Map<String, dynamic>> updateTrustedContact(
    String id, {
    String? name,
    String? phone,
    String? relationship,
    bool? notifyOnSos,
    bool? notifyOnThreat,
    bool? notifyOnNightMode,
  }) async {
    return await _put('/contacts/trusted/$id', {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (relationship != null) 'relationship': relationship,
      if (notifyOnSos != null) 'notifyOnSos': notifyOnSos,
      if (notifyOnThreat != null) 'notifyOnThreat': notifyOnThreat,
      if (notifyOnNightMode != null) 'notifyOnNightMode': notifyOnNightMode,
    });
  }

  /// Removes a contact from trusted contacts by database ID.
  static Future<void> removeTrustedContact(String id) async {
    final res = await http.delete(
      Uri.parse('$_kBaseUrl/contacts/trusted/$id'),
      headers: await _headers(),
    );
    _checkStatus(res);
  }

  /// Removes a contact from trusted contacts by phone number.
  static Future<void> removeTrustedContactByPhone(String phone) async {
    final cleanPhone = Uri.encodeComponent(phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), ''));
    final res = await http.delete(
      Uri.parse('$_kBaseUrl/contacts/trusted/by-phone/$cleanPhone'),
      headers: await _headers(),
    );
    _checkStatus(res);
  }
}

