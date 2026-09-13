import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_service.dart';
import '../services/contact_sync_service.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class TrustedContactItem {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool notifyOnSos;
  final bool notifyOnThreat;
  final bool notifyOnNightMode;

  const TrustedContactItem({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = 'Emergency Contact',
    this.notifyOnSos = true,
    this.notifyOnThreat = true,
    this.notifyOnNightMode = true,
  });

  TrustedContactItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? notifyOnSos,
    bool? notifyOnThreat,
    bool? notifyOnNightMode,
  }) {
    return TrustedContactItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      notifyOnSos: notifyOnSos ?? this.notifyOnSos,
      notifyOnThreat: notifyOnThreat ?? this.notifyOnThreat,
      notifyOnNightMode: notifyOnNightMode ?? this.notifyOnNightMode,
    );
  }

  factory TrustedContactItem.fromJson(Map<String, dynamic> json) {
    return TrustedContactItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      phone: (json['phone'] ?? '').toString(),
      relationship: (json['relationship'] ?? 'Emergency Contact').toString(),
      notifyOnSos: json['notifyOnSos'] as bool? ?? true,
      notifyOnThreat: json['notifyOnThreat'] as bool? ?? true,
      notifyOnNightMode: json['notifyOnNightMode'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'notifyOnSos': notifyOnSos,
        'notifyOnThreat': notifyOnThreat,
        'notifyOnNightMode': notifyOnNightMode,
      };
}

// ─── State ───────────────────────────────────────────────────────────────────

class TrustedContactsState {
  final bool isLoading;
  final bool isSyncingPhonebook;
  final List<TrustedContactItem> trustedContacts;
  final List<Map<String, dynamic>> deviceContacts;
  final String searchQuery;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const TrustedContactsState({
    this.isLoading = false,
    this.isSyncingPhonebook = false,
    this.trustedContacts = const [],
    this.deviceContacts = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.lastSyncTime,
  });

  TrustedContactsState copyWith({
    bool? isLoading,
    bool? isSyncingPhonebook,
    List<TrustedContactItem>? trustedContacts,
    List<Map<String, dynamic>>? deviceContacts,
    String? searchQuery,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return TrustedContactsState(
      isLoading: isLoading ?? this.isLoading,
      isSyncingPhonebook: isSyncingPhonebook ?? this.isSyncingPhonebook,
      trustedContacts: trustedContacts ?? this.trustedContacts,
      deviceContacts: deviceContacts ?? this.deviceContacts,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  /// Check if a phone number is in the trusted list
  bool isPhoneTrusted(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    return trustedContacts.any((c) => c.phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '') == clean);
  }

  TrustedContactItem? getTrustedItem(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    try {
      return trustedContacts.firstWhere(
        (c) => c.phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '') == clean,
      );
    } catch (_) {
      return null;
    }
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TrustedContactsNotifier extends StateNotifier<TrustedContactsState> {
  TrustedContactsNotifier() : super(const TrustedContactsState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Future.wait([
        fetchTrustedContacts(),
        fetchDeviceContacts(),
      ]);
      final info = await ContactSyncService.getLastSyncInfo();
      state = state.copyWith(
        isLoading: false,
        lastSyncTime: info['lastSyncDate'] as DateTime?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchTrustedContacts() async {
    try {
      final rawList = await BackendService.getTrustedContacts();
      final items = rawList
          .map((item) => TrustedContactItem.fromJson(item as Map<String, dynamic>))
          .toList();
      state = state.copyWith(trustedContacts: items);
    } catch (e) {
      debugPrint('[TrustedContacts] Error fetching trusted: $e');
    }
  }

  Future<void> fetchDeviceContacts({String? query}) async {
    try {
      final raw = await BackendService.getDeviceContacts(query: query);
      final list = raw.map((c) => Map<String, dynamic>.from(c as Map)).toList();
      state = state.copyWith(deviceContacts: list, searchQuery: query ?? state.searchQuery);
    } catch (e) {
      debugPrint('[TrustedContacts] Error fetching device contacts: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchDeviceContacts(query: query);
  }

  /// Toggle whether a contact is in the trusted notification table
  Future<void> toggleTrusted({
    required String name,
    required String phone,
    String relationship = 'Family / Close Friend',
    bool notifyOnSos = true,
    bool notifyOnThreat = true,
    bool notifyOnNightMode = true,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    final existing = state.getTrustedItem(cleanPhone);

    if (existing != null) {
      // Remove from trusted
      // Optimistic update
      final updated = state.trustedContacts.where((c) => c.id != existing.id).toList();
      state = state.copyWith(trustedContacts: updated);

      try {
        await BackendService.removeTrustedContact(existing.id);
      } catch (e) {
        // Rollback
        await fetchTrustedContacts();
        rethrow;
      }
    } else {
      // Add to trusted
      try {
        final res = await BackendService.addTrustedContact(
          name: name,
          phone: cleanPhone,
          relationship: relationship,
          notifyOnSos: notifyOnSos,
          notifyOnThreat: notifyOnThreat,
          notifyOnNightMode: notifyOnNightMode,
        );

        if (res['contact'] != null) {
          final newItem = TrustedContactItem.fromJson(res['contact'] as Map<String, dynamic>);
          state = state.copyWith(
            trustedContacts: [newItem, ...state.trustedContacts],
          );
        } else {
          await fetchTrustedContacts();
        }
      } catch (e) {
        debugPrint('[TrustedContacts] Failed to add trusted contact: $e');
        rethrow;
      }
    }
  }

  /// Update notification flags (SOS, Threat, Night escort) or relationship for a trusted contact
  Future<void> updateNotificationFlags(
    String id, {
    bool? notifyOnSos,
    bool? notifyOnThreat,
    bool? notifyOnNightMode,
    String? relationship,
  }) async {
    // Optimistic update
    state = state.copyWith(
      trustedContacts: state.trustedContacts.map((c) {
        if (c.id == id) {
          return c.copyWith(
            notifyOnSos: notifyOnSos,
            notifyOnThreat: notifyOnThreat,
            notifyOnNightMode: notifyOnNightMode,
            relationship: relationship,
          );
        }
        return c;
      }).toList(),
    );

    try {
      await BackendService.updateTrustedContact(
        id,
        notifyOnSos: notifyOnSos,
        notifyOnThreat: notifyOnThreat,
        notifyOnNightMode: notifyOnNightMode,
        relationship: relationship,
      );
    } catch (e) {
      await fetchTrustedContacts();
      rethrow;
    }
  }

  /// Manually sync phonebook contacts now and refresh
  Future<int> syncPhonebookNow() async {
    state = state.copyWith(isSyncingPhonebook: true);
    try {
      final count = await ContactSyncService.syncContacts(force: true);
      await Future.wait([
        fetchDeviceContacts(query: state.searchQuery),
        fetchTrustedContacts(),
      ]);
      final info = await ContactSyncService.getLastSyncInfo();
      state = state.copyWith(
        isSyncingPhonebook: false,
        lastSyncTime: info['lastSyncDate'] as DateTime?,
      );
      return count;
    } catch (e) {
      state = state.copyWith(isSyncingPhonebook: false);
      rethrow;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final trustedContactsProvider =
    StateNotifierProvider<TrustedContactsNotifier, TrustedContactsState>((ref) {
  return TrustedContactsNotifier();
});
