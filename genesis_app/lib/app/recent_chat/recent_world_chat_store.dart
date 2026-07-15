import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bootstrap/service_registry.dart';

const String _recentWorldChatKeyPrefix = 'recent_world_chat:';

class RecentWorldChatRecord {
  const RecentWorldChatRecord({
    required this.uid,
    required this.worldId,
    required this.locationId,
    required this.locationPathIds,
    required this.updatedAt,
  });

  final String uid;
  final String worldId;
  final String locationId;
  final List<String> locationPathIds;
  final int updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uid': uid,
      'world_id': worldId,
      'location_id': locationId,
      'location_path_ids': locationPathIds,
      'updated_at': updatedAt,
    };
  }

  static RecentWorldChatRecord? fromJson(Map<String, dynamic> json) {
    final uid = _mapString(json, 'uid');
    final worldId = _mapString(json, 'world_id');
    final locationId = _mapString(json, 'location_id');
    if (uid.isEmpty || worldId.isEmpty || locationId.isEmpty) return null;
    return RecentWorldChatRecord(
      uid: uid,
      worldId: worldId,
      locationId: locationId,
      locationPathIds: _locationPathIdsFromJson(json, locationId),
      updatedAt: _mapInt(json, 'updated_at'),
    );
  }
}

class RecentWorldChatStore {
  RecentWorldChatStore();

  final ValueNotifier<RecentWorldChatRecord?> listenable =
      ValueNotifier<RecentWorldChatRecord?>(null);

  Future<RecentWorldChatRecord?> loadForUid(String uid) async {
    final resolvedUid = uid.trim();
    if (resolvedUid.isEmpty) {
      listenable.value = null;
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUid(resolvedUid));
    final record = _decode(raw);
    listenable.value = record?.uid == resolvedUid ? record : null;
    return listenable.value;
  }

  Future<void> markRecentChat({
    required String uid,
    required String worldId,
    required String locationId,
    List<String> locationPathIds = const <String>[],
  }) async {
    final resolvedUid = uid.trim();
    final resolvedWorldId = worldId.trim();
    final resolvedLocationId = locationId.trim();
    if (resolvedUid.isEmpty ||
        resolvedWorldId.isEmpty ||
        resolvedLocationId.isEmpty) {
      return;
    }
    final record = RecentWorldChatRecord(
      uid: resolvedUid,
      worldId: resolvedWorldId,
      locationId: resolvedLocationId,
      locationPathIds: _orderedNonEmptyStrings([
        ...locationPathIds,
        resolvedLocationId,
      ]),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForUid(resolvedUid), jsonEncode(record.toJson()));
    listenable.value = record;
  }

  static String _keyForUid(String uid) => '$_recentWorldChatKeyPrefix$uid';

  static RecentWorldChatRecord? _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return RecentWorldChatRecord.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

final RecentWorldChatStore recentWorldChatStore = RecentWorldChatStore();

Future<String> resolveRecentWorldChatUid(AppServices services) async {
  final sessionUid = (await services.sessionStore.readUid())?.trim() ?? '';
  if (sessionUid.isNotEmpty) return sessionUid;

  final userInfo = await services.sessionStore.readUserInfo();
  final cachedUid = _mapString(userInfo, 'uid');
  if (cachedUid.isNotEmpty) return cachedUid;

  return (services.identityAuth.currentProfile()?.uid ?? '').trim();
}

String _mapString(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  final text = value?.toString().trim() ?? '';
  return text;
}

int _mapInt(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _locationPathIdsFromJson(
  Map<String, dynamic> json,
  String fallbackLocationId,
) {
  final raw = json['location_path_ids'];
  if (raw is Iterable) {
    return _orderedNonEmptyStrings([
      ...raw.map((value) => value?.toString() ?? ''),
      fallbackLocationId,
    ]);
  }
  return _orderedNonEmptyStrings([fallbackLocationId]);
}

List<String> _orderedNonEmptyStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (!seen.add(key)) continue;
    result.add(trimmed);
  }
  return List<String>.unmodifiable(result);
}
