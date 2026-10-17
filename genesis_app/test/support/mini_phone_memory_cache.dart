import 'dart:convert';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_cache.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_cache_storage.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';

class MemoryMiniPhoneCacheStorage implements MiniPhoneCacheStorage {
  final snapshots = <String, String>{};
  bool failWrites = false, failReads = false;

  @override
  Future<MiniPhoneCache> load(MiniPhoneCacheScope scope) async {
    if (failReads) throw StateError('Cache read unavailable');
    return MiniPhoneCache.fromJson(
      phoneMap(jsonDecode(snapshots[scope.key] ?? '{}')),
    );
  }

  @override
  Future<void> save(
    MiniPhoneCacheScope scope,
    Map<String, dynamic> snapshot,
  ) async {
    if (failWrites) throw StateError('Cache write unavailable');
    snapshots[scope.key] = jsonEncode(snapshot);
  }

  @override
  Future<List<PhoneMessage>> loadBefore(
    MiniPhoneCacheScope scope,
    int sessionId,
    int beforeId,
    int limit,
  ) async {
    final cache = await load(scope);
    return cache
        .history(sessionId)
        .reversed
        .where((m) => m.id < beforeId)
        .take(limit)
        .toList();
  }
}
