// lib/services/account_history_service.dart
// Cuentas usadas en el dispositivo (solo metadatos locales; el cambio real es vía Google).

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final int lastUsedMs;

  const SavedAccount({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.lastUsedMs,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'lastUsedMs': lastUsedMs,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> j) {
    return SavedAccount(
      uid: j['uid'] as String? ?? '',
      email: j['email'] as String? ?? '',
      displayName: j['displayName'] as String?,
      photoUrl: j['photoUrl'] as String?,
      lastUsedMs: (j['lastUsedMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class AccountHistoryService {
  static const _key = 'dolarsabio_saved_accounts_v1';
  static const _max = 12;

  static Future<List<SavedAccount>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((a) => a.uid.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> touchUser(User user) async {
    final list = await load();
    list.removeWhere((a) => a.uid == user.uid);
    list.insert(
      0,
      SavedAccount(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        lastUsedMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    while (list.length > _max) {
      list.removeLast();
    }
    await _save(list);
  }

  static Future<void> removeUid(String uid) async {
    final list = await load()..removeWhere((a) => a.uid == uid);
    await _save(list);
  }

  static Future<void> _save(List<SavedAccount> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
