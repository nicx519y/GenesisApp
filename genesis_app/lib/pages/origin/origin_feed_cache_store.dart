import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OriginFeedCacheStore {
  const OriginFeedCacheStore({String? ownerUid}) : _ownerUid = ownerUid;

  static const String storageKey = 'origin_feed_cache_v1';
  static const String anonymousOwnerUid = '__anonymous__';

  final String? _ownerUid;

  Future<Map<String, dynamic>?> loadForYouFirstPage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> saveForYouFirstPage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  String get _storageKey {
    final owner = (_ownerUid ?? '').trim();
    final resolvedOwner = owner.isEmpty ? anonymousOwnerUid : owner;
    return '$storageKey.$resolvedOwner.foryou.page_1';
  }
}
