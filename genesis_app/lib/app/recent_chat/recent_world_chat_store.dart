import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bootstrap/service_registry.dart';

const String _recentWorldChatKeyPrefix = 'recent_world_chat:';
const String _worldActivityTagKeyPrefix = 'world_activity_tags:';

class WorldActivityTagState {
  const WorldActivityTagState({
    required this.uid,
    this.lastMessageWorldId = '',
    this.lastTickWorldId = '',
    this.lastLaunchWorldId = '',
  });

  factory WorldActivityTagState.empty(String uid) {
    return WorldActivityTagState(uid: uid.trim());
  }

  final String uid;
  final String lastMessageWorldId;
  final String lastTickWorldId;
  final String lastLaunchWorldId;

  WorldActivityTagState copyWith({
    String? lastMessageWorldId,
    String? lastTickWorldId,
    String? lastLaunchWorldId,
  }) {
    return WorldActivityTagState(
      uid: uid,
      lastMessageWorldId: lastMessageWorldId ?? this.lastMessageWorldId,
      lastTickWorldId: lastTickWorldId ?? this.lastTickWorldId,
      lastLaunchWorldId: lastLaunchWorldId ?? this.lastLaunchWorldId,
    );
  }

  String labelForWorldId(String worldId) {
    final resolvedWorldId = worldId.trim();
    if (resolvedWorldId.isEmpty) return '';
    if (resolvedWorldId == lastMessageWorldId) return 'Last Message';
    if (resolvedWorldId == lastTickWorldId) return 'Last Tick';
    if (resolvedWorldId == lastLaunchWorldId) return 'Last Launch';
    return '';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uid': uid,
      'last_message_world_id': lastMessageWorldId,
      'last_tick_world_id': lastTickWorldId,
      'last_launch_world_id': lastLaunchWorldId,
    };
  }

  static WorldActivityTagState? fromJson(Map<String, dynamic> json) {
    final uid = _mapString(json, 'uid');
    if (uid.isEmpty) return null;
    return WorldActivityTagState(
      uid: uid,
      lastMessageWorldId: _mapString(json, 'last_message_world_id'),
      lastTickWorldId: _mapString(json, 'last_tick_world_id'),
      lastLaunchWorldId: _mapString(json, 'last_launch_world_id'),
    );
  }
}

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
    await worldActivityTagStore.markLastMessage(
      uid: resolvedUid,
      worldId: resolvedWorldId,
    );
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

class WorldActivityTagStore {
  WorldActivityTagStore();

  final ValueNotifier<WorldActivityTagState?> listenable =
      ValueNotifier<WorldActivityTagState?>(null);

  Future<WorldActivityTagState?> loadForUid(String uid) async {
    final resolvedUid = uid.trim();
    if (resolvedUid.isEmpty) {
      listenable.value = null;
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final state = _decode(prefs.getString(_keyForUid(resolvedUid)));
    final resolvedState = state?.uid == resolvedUid
        ? state
        : WorldActivityTagState.empty(resolvedUid);
    listenable.value = resolvedState;
    return resolvedState;
  }

  Future<void> markLastMessage({required String uid, required String worldId}) {
    return _update(
      uid: uid,
      worldId: worldId,
      apply: (state, resolvedWorldId) =>
          state.copyWith(lastMessageWorldId: resolvedWorldId),
    );
  }

  Future<void> markLastTick({required String uid, required String worldId}) {
    return _update(
      uid: uid,
      worldId: worldId,
      apply: (state, resolvedWorldId) =>
          state.copyWith(lastTickWorldId: resolvedWorldId),
    );
  }

  Future<void> markLastLaunch({required String uid, required String worldId}) {
    return _update(
      uid: uid,
      worldId: worldId,
      apply: (state, resolvedWorldId) =>
          state.copyWith(lastLaunchWorldId: resolvedWorldId),
    );
  }

  Future<void> _update({
    required String uid,
    required String worldId,
    required WorldActivityTagState Function(
      WorldActivityTagState state,
      String resolvedWorldId,
    )
    apply,
  }) async {
    final resolvedUid = uid.trim();
    final resolvedWorldId = worldId.trim();
    if (resolvedUid.isEmpty || resolvedWorldId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = _decode(prefs.getString(_keyForUid(resolvedUid)));
    final current = stored?.uid == resolvedUid
        ? stored!
        : WorldActivityTagState.empty(resolvedUid);
    final next = apply(current, resolvedWorldId);
    await prefs.setString(_keyForUid(resolvedUid), jsonEncode(next.toJson()));
    listenable.value = next;
  }

  static String _keyForUid(String uid) => '$_worldActivityTagKeyPrefix$uid';

  static WorldActivityTagState? _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return WorldActivityTagState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

final WorldActivityTagStore worldActivityTagStore = WorldActivityTagStore();

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
