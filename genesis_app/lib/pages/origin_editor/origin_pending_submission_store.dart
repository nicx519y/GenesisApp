import 'package:shared_preferences/shared_preferences.dart';

class OriginPendingSubmission {
  const OriginPendingSubmission({
    required this.originId,
    required this.startedAt,
    this.originName = '',
  });

  final String originId;
  final DateTime startedAt;
  final String originName;

  bool get isExpired =>
      DateTime.now().toUtc().difference(startedAt.toUtc()) >
      OriginPendingSubmissionStore.timeout;
}

class OriginPendingSubmissionStore {
  OriginPendingSubmissionStore._();

  static const Duration timeout = Duration(minutes: 2);

  static const String _creatingOriginIdKey = 'creaing_origin_id';
  static const String _creatingStartedAtKey = 'creating_origin_started_at';
  static const String _creatingOriginNameKey = 'creating_origin_name';
  static const String _publishingOriginIdKey = 'publishing_origin_id';
  static const String _publishingStartedAtKey = 'publishing_origin_started_at';
  static const String _publishingOriginNameKey = 'publishing_origin_name';

  static Future<OriginPendingSubmission?> loadCreating() {
    return _load(
      _creatingOriginIdKey,
      _creatingStartedAtKey,
      _creatingOriginNameKey,
    );
  }

  static Future<void> saveCreating(String originId, {String originName = ''}) {
    return _save(
      _creatingOriginIdKey,
      _creatingStartedAtKey,
      _creatingOriginNameKey,
      originId,
      originName,
    );
  }

  static Future<void> clearCreating() {
    return _clear(
      _creatingOriginIdKey,
      _creatingStartedAtKey,
      _creatingOriginNameKey,
    );
  }

  static Future<OriginPendingSubmission?> loadPublishing() {
    return _load(
      _publishingOriginIdKey,
      _publishingStartedAtKey,
      _publishingOriginNameKey,
    );
  }

  static Future<void> savePublishing(
    String originId, {
    String originName = '',
  }) {
    return _save(
      _publishingOriginIdKey,
      _publishingStartedAtKey,
      _publishingOriginNameKey,
      originId,
      originName,
    );
  }

  static Future<void> clearPublishing() {
    return _clear(
      _publishingOriginIdKey,
      _publishingStartedAtKey,
      _publishingOriginNameKey,
    );
  }

  static Future<OriginPendingSubmission?> _load(
    String originIdKey,
    String startedAtKey,
    String originNameKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final originId = prefs.getString(originIdKey)?.trim() ?? '';
    if (originId.isEmpty) return null;

    final startedAtText = prefs.getString(startedAtKey)?.trim() ?? '';
    final startedAt =
        DateTime.tryParse(startedAtText)?.toUtc() ?? DateTime.now().toUtc();
    return OriginPendingSubmission(
      originId: originId,
      startedAt: startedAt,
      originName: prefs.getString(originNameKey)?.trim() ?? '',
    );
  }

  static Future<void> _save(
    String originIdKey,
    String startedAtKey,
    String originNameKey,
    String originId,
    String originName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(originIdKey, originId.trim());
    await prefs.setString(
      startedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    final normalizedOriginName = originName.trim();
    if (normalizedOriginName.isEmpty) {
      await prefs.remove(originNameKey);
    } else {
      await prefs.setString(originNameKey, normalizedOriginName);
    }
  }

  static Future<void> _clear(
    String originIdKey,
    String startedAtKey,
    String originNameKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(originIdKey);
    await prefs.remove(startedAtKey);
    await prefs.remove(originNameKey);
  }
}
