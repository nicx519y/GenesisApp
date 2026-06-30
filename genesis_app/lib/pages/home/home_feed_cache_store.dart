import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum HomeFeedCacheKind { myWorlds, popular }

class HomeFeedCacheStore {
  const HomeFeedCacheStore({String? ownerUid}) : _ownerUid = ownerUid;

  static const String storageKey = 'home_feed_cache_v1';
  static const String anonymousOwnerUid = '__anonymous__';

  final String? _ownerUid;

  Future<Map<String, dynamic>?> load(HomeFeedCacheKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKeyForOwner(kind));
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

  Future<void> save(HomeFeedCacheKind kind, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKeyForOwner(kind), jsonEncode(data));
  }

  String _storageKeyForOwner(HomeFeedCacheKind kind) {
    final owner = (_ownerUid ?? '').trim();
    final resolvedOwner = owner.isEmpty ? anonymousOwnerUid : owner;
    return '$storageKey.$resolvedOwner.${_kindKey(kind)}';
  }

  String _kindKey(HomeFeedCacheKind kind) {
    switch (kind) {
      case HomeFeedCacheKind.myWorlds:
        return 'my_worlds';
      case HomeFeedCacheKind.popular:
        return 'popular';
    }
  }
}
