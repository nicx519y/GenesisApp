import 'package:shared_preferences/shared_preferences.dart';

class OriginLaunchPending {
  const OriginLaunchPending({
    required this.originId,
    required this.worldId,
    required this.startedAt,
    this.initialLocationId = '',
  });

  final String originId;
  final String worldId;
  final DateTime startedAt;
  final String initialLocationId;

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
  static const String _initialLocationIdKey =
      'pending_origin_launch_initial_location_id';

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
      initialLocationId: prefs.getString(_initialLocationIdKey)?.trim() ?? '',
    );
  }

  static Future<void> save({
    required String originId,
    required String worldId,
    String initialLocationId = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_originIdKey, originId.trim());
    await prefs.setString(_worldIdKey, worldId.trim());
    await prefs.setString(
      _startedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    final resolvedInitialLocationId = initialLocationId.trim();
    if (resolvedInitialLocationId.isEmpty) {
      await prefs.remove(_initialLocationIdKey);
    } else {
      await prefs.setString(_initialLocationIdKey, resolvedInitialLocationId);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_originIdKey);
    await prefs.remove(_worldIdKey);
    await prefs.remove(_startedAtKey);
    await prefs.remove(_initialLocationIdKey);
  }
}
