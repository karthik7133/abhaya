import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Contact Model ────────────────────────────────────────────────────────────

class NightContact {
  final String id;
  final String name;
  final String phone;
  final bool enabled;

  const NightContact({
    required this.id,
    required this.name,
    required this.phone,
    this.enabled = true,
  });

  NightContact copyWith({
    String? id,
    String? name,
    String? phone,
    bool? enabled,
  }) {
    return NightContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'enabled': enabled,
      };

  factory NightContact.fromJson(Map<String, dynamic> json) => NightContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        enabled: json['enabled'] as bool? ?? true,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NightContactsNotifier extends StateNotifier<List<NightContact>> {
  static const _prefsKey = 'night_contacts';

  NightContactsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      state = raw
          .map((s) => NightContact.fromJson(
              jsonDecode(s) as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      state.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> addContact(String name, String phone) async {
    if (name.trim().isEmpty || phone.trim().isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    state = [
      ...state,
      NightContact(id: id, name: name.trim(), phone: phone.trim()),
    ];
    await _save();
  }

  Future<void> removeContact(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _save();
  }

  Future<void> toggleContact(String id) async {
    state = state
        .map((c) => c.id == id ? c.copyWith(enabled: !c.enabled) : c)
        .toList();
    await _save();
  }

  Future<void> updateContact(String id, String name, String phone) async {
    state = state
        .map((c) =>
            c.id == id ? c.copyWith(name: name.trim(), phone: phone.trim()) : c)
        .toList();
    await _save();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final nightContactsProvider =
    StateNotifierProvider<NightContactsNotifier, List<NightContact>>((ref) {
  return NightContactsNotifier();
});
