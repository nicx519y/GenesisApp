import 'package:shared_preferences/shared_preferences.dart';

class OriginLaunchPending {
  const OriginLaunchPending({
    required this.originId,
    required this.worldId,
    required this.startedAt,
  });

  final String originId;
  final String worldId;
  final DateTime startedAt;

  bool get isExpired =>
      DateTime.now().toUtc().difference(startedAt.toUtc()) >
      OriginLaunchPendingStore.timeout;
}

class OriginLaunchPendingStore {
  OriginLaunchPendingStore._();

  static const Duration timeout = Duration(minutes: 2);

  static const String _originIdKey = 'pending_origin_launch_origin_id';
  static const String _worldIdKey = 'pending_origin_launch_wid';
  static const String _startedAtKey = 'pending_origin_launch_started_at';

  static Future<OriginLaunchPending?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final originId = prefs.getString(_originIdKey)?.trim() ?? '';
    final worldId = prefs.getString(_worldIdKey)?.trim() ?? '';
    if (originId.isEmpty || worldId.isEmpty) return null;

    final startedAtText = prefs.getString(_startedAtKey)?.trim() ?? '';
    final startedAt =
        DateTime.tryParse(startedAtText)?.toUtc() ?? DateTime.now().toUtc();
    return OriginLaunchPending(
      originId: originId,
      worldId: worldId,
      startedAt: startedAt,
    );
  }

  static Future<void> save({
    required String originId,
    required String worldId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_originIdKey, originId.trim());
    await prefs.setString(_worldIdKey, worldId.trim());
    await prefs.setString(
      _startedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_originIdKey);
    await prefs.remove(_worldIdKey);
    await prefs.remove(_startedAtKey);
  }
}
