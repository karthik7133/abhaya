import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';
import 'local_db_service.dart';

class ContactSyncService {
  static const String _kLastSyncKey = 'contacts_last_synced_ms';
  static const String _kSyncCountKey = 'contacts_synced_count';
  static bool _isSyncing = false;

  static bool get isSyncing => _isSyncing;

  /// Fire-and-forget background sync. Safe to call anywhere (permission gate, login, main).
  static void syncContactsInBackground({VoidCallback? onComplete}) {
    unawaited(
      syncContacts().then((count) {
        if (onComplete != null) onComplete();
      }).catchError((err) {
        debugPrint('[ContactSyncService] Background sync error: $err');
      }),
    );
  }

  /// Extracts contacts from phonebook and uploads to backend MongoDB under user's name.
  /// Returns the count of synced contacts, or -1 if permission denied or user not logged in.
  static Future<int> syncContacts({bool force = false}) async {
    if (_isSyncing) {
      debugPrint('[ContactSyncService] Sync already in progress, skipping duplicate call.');
      return -1;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[ContactSyncService] Cannot sync contacts: user not logged in.');
      return -1;
    }

    // Check Contacts permission
    final permStatus = await Permission.contacts.status;
    if (!permStatus.isGranted) {
      final res = await Permission.contacts.request();
      if (!res.isGranted) {
        debugPrint('[ContactSyncService] Contacts permission not granted.');
        return -1;
      }
    }

    _isSyncing = true;
    try {
      debugPrint('[ContactSyncService] 🔄 Reading phone contacts...');
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.email},
      );

      debugPrint('[ContactSyncService] Found ${contacts.length} device contacts. Preparing upload...');

      final List<Map<String, dynamic>> payload = [];
      for (final c in contacts) {
        final phoneNumbers = c.phones
            .map((p) => p.number.replaceAll(RegExp(r'[\s\-\(\)\.]'), ''))
            .where((p) => p.length >= 3)
            .toList();

        if (phoneNumbers.isEmpty) continue; // Only sync contacts with valid phone numbers

        final emails = c.emails.map((e) => e.address.trim()).where((e) => e.isNotEmpty).toList();

        final displayName = c.displayName ?? '';
        payload.add({
          'name': displayName.isNotEmpty ? displayName : phoneNumbers.first,
          'phones': phoneNumbers,
          'emails': emails,
          'deviceContactId': c.id,
        });
      }

      if (payload.isEmpty) {
        debugPrint('[ContactSyncService] No contacts with phone numbers found to upload.');
        _isSyncing = false;
        return 0;
      }

      debugPrint('[ContactSyncService] 🚀 Uploading ${payload.length} contacts to DB for user: ${user.displayName ?? user.uid}...');
      final res = await BackendService.syncDeviceContacts(payload);
      final count = (res['count'] as int?) ?? payload.length;

      // Cache locally for offline fast-access
      await LocalDbService.cacheGetResponse('/contacts', {
        'contacts': payload.map((p) => {
          'name': p['name'],
          'primaryPhone': (p['phones'] as List).first,
          'phoneNumbers': p['phones'],
          'emails': p['emails'],
        }).toList(),
      });

      // Save sync timestamps
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSyncKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_kSyncCountKey, count);

      debugPrint('[ContactSyncService] ✅ Successfully synced and uploaded $count contacts to MongoDB!');
      return count;
    } catch (e) {
      debugPrint('[ContactSyncService] ❌ Failed to upload contacts: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Returns last synced date and count from SharedPreferences.
  static Future<Map<String, dynamic>> getLastSyncInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastSyncKey);
    final count = prefs.getInt(_kSyncCountKey) ?? 0;
    return {
      'lastSyncDate': ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
      'count': count,
    };
  }
}
