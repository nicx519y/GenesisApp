import 'package:flutter/foundation.dart';

import '../bootstrap/service_registry.dart';

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
}

class RecentWorldChatStore {
  RecentWorldChatStore();

  final ValueNotifier<RecentWorldChatRecord?> listenable =
      ValueNotifier<RecentWorldChatRecord?>(null);

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
    listenable.value = record;
  }
}

final RecentWorldChatStore recentWorldChatStore = RecentWorldChatStore();

Future<String> resolveRecentWorldChatUid(AppServices services) async {
  final sessionUid = (await services.sessionStore.readUid())?.trim() ?? '';
  if (sessionUid.isNotEmpty) return sessionUid;

  final userInfo = await services.sessionStore.readUserInfo();
  final cachedUid = _mapString(userInfo, 'uid');
  if (cachedUid.isNotEmpty) return cachedUid;
  return '';
}

String _mapString(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  final text = value?.toString().trim() ?? '';
  return text;
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
