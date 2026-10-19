import '../../l10n/app_language_controller.dart';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum HomeFeedCacheKind { myWorlds }

class HomeFeedCacheStore {
  const HomeFeedCacheStore({String? ownerUid}) : _ownerUid = ownerUid;

  static const String storageKey = 'home_feed_cache_v1';
  static const String anonymousOwnerUid = '__anonymous__';

  final String? _ownerUid;

  Future<Map<String, dynamic>?> load(HomeFeedCacheKind kind) async {
    final languageRevision = appLanguageController.dataRevision;
    final key = _storageKeyForOwner(kind);
    final prefs = await SharedPreferences.getInstance();
    if (languageRevision != appLanguageController.dataRevision) return null;
    final raw = prefs.getString(key);
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
    final key = _storageKeyForOwner(kind);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  String _storageKeyForOwner(HomeFeedCacheKind kind) {
    final owner = (_ownerUid ?? '').trim();
    final resolvedOwner = owner.isEmpty ? anonymousOwnerUid : owner;
    return '$storageKey.$resolvedOwner.${_kindKey(kind)}.language_${appLanguageController.settingLanguage ?? ui.PlatformDispatcher.instance.locale.toLanguageTag()}';
  }

  String _kindKey(HomeFeedCacheKind kind) {
    switch (kind) {
      case HomeFeedCacheKind.myWorlds:
        return 'my_worlds';
    }
  }
}
