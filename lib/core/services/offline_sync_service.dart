import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_db_service.dart';
import 'backend_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  void startListening() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        syncPendingData();
      }
    });
    // Attempt sync immediately on start
    syncPendingData();
  }

  void stopListening() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        _isSyncing = false;
        return;
      }

      final pending = await LocalDbService.getPendingRequests();
      if (pending.isEmpty) {
        _isSyncing = false;
        return;
      }
      
      debugPrint('[OfflineSyncService] Attempting to sync ${pending.length} pending requests.');

      for (final row in pending) {
        final id = row['id'] as int;
        final action = row['action'] as String;
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        bool success = false;
        try {
          if (action == 'submitIncidentReport') {
            await BackendService.submitIncidentReport(
              category: payload['category'],
              severity: payload['severity'],
              description: payload['description'],
              lat: payload['lat'],
              lng: payload['lng'],
              anonymous: payload['anonymous'] ?? false,
              notifyAuthorities: payload['notifyAuthorities'] ?? false,
              mediaBase64: payload['mediaBase64'],
              isOfflineSync: true,
            );
            success = true;
          } else if (action == 'updateLiveLocation') {
             await BackendService.updateLiveLocation(
               lat: payload['lat'],
               lng: payload['lng'],
               speed: payload['speed'],
               isGuardianActive: payload['isGuardianActive'] ?? false,
               isOfflineSync: true,
             );
             success = true;
          }
        } catch (e) {
           debugPrint('[OfflineSyncService] Failed to sync action $action: $e');
        }

        if (success) {
          await LocalDbService.removePendingRequest(id);
          debugPrint('[OfflineSyncService] Successfully synced request #$id');
        } else {
          // If a request fails (likely due to network), stop processing the queue for now
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
