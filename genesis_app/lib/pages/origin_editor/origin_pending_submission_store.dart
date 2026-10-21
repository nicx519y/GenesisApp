import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/session/user_session_store.dart';
import '../create/create_origin_draft_store.dart';

class OriginPendingSubmission {
  const OriginPendingSubmission({
    required this.originId,
    required this.startedAt,
    this.originName = '',
    this.ownerUid = CreateOriginDraftStore.anonymousOwner,
  });

  final String originId;
  final DateTime startedAt;
  final String originName;
  final String ownerUid;

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

  static Future<OriginPendingSubmission?> loadCreating({
    String? ownerUid,
    UserSessionStore? sessionStore,
  }) async {
    final owner = await _owner(ownerUid, sessionStore);
    return _load(
      _creatingOriginIdKey,
      _creatingStartedAtKey,
      _creatingOriginNameKey,
      owner,
    );
  }

  static Future<void> saveCreating(
    String originId, {
    String originName = '',
    String? ownerUid,
    UserSessionStore? sessionStore,
  }) async {
    final owner = await _owner(ownerUid, sessionStore);
    return _save(
      _creatingOriginIdKey,
      _creatingStartedAtKey,
      _creatingOriginNameKey,
      owner,
      originId,
      originName,
    );
  }

  static Future<void> clearCreating({
    String? ownerUid,
    UserSessionStore? sessionStore,
  }) async {
    final owner = await _owner(ownerUid, sessionStore);
    return _clear(
      _creatingOriginIdKey,
      _creatingStartedAtKey,
      _creatingOriginNameKey,
      owner,
    );
  }

  static Future<OriginPendingSubmission?> loadPublishing() {
    return _load(
      _publishingOriginIdKey,
      _publishingStartedAtKey,
      _publishingOriginNameKey,
      CreateOriginDraftStore.anonymousOwner,
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
      CreateOriginDraftStore.anonymousOwner,
      originId,
      originName,
    );
  }

  static Future<void> clearPublishing() {
    return _clear(
      _publishingOriginIdKey,
      _publishingStartedAtKey,
      _publishingOriginNameKey,
      CreateOriginDraftStore.anonymousOwner,
    );
  }

  static Future<OriginPendingSubmission?> _load(
    String originIdKey,
    String startedAtKey,
    String originNameKey,
    String owner,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final originId = prefs.getString(_key(originIdKey, owner))?.trim() ?? '';
    if (originId.isEmpty) return null;

    final startedAtText =
        prefs.getString(_key(startedAtKey, owner))?.trim() ?? '';
    final startedAt =
        DateTime.tryParse(startedAtText)?.toUtc() ?? DateTime.now().toUtc();
    return OriginPendingSubmission(
      originId: originId,
      startedAt: startedAt,
      originName: prefs.getString(_key(originNameKey, owner))?.trim() ?? '',
      ownerUid: owner,
    );
  }

  static Future<void> _save(
    String originIdKey,
    String startedAtKey,
    String originNameKey,
    String owner,
    String originId,
    String originName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(originIdKey, owner), originId.trim());
    await prefs.setString(
      _key(startedAtKey, owner),
      DateTime.now().toUtc().toIso8601String(),
    );
    final normalizedOriginName = originName.trim();
    if (normalizedOriginName.isEmpty) {
      await prefs.remove(_key(originNameKey, owner));
    } else {
      await prefs.setString(_key(originNameKey, owner), normalizedOriginName);
    }
  }

  static Future<void> _clear(
    String originIdKey,
    String startedAtKey,
    String originNameKey,
    String owner,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(originIdKey, owner));
    await prefs.remove(_key(startedAtKey, owner));
    await prefs.remove(_key(originNameKey, owner));
  }

  static Future<String> _owner(
    String? ownerUid,
    UserSessionStore? sessionStore,
  ) => ownerUid == null
      ? CreateOriginDraftStore.readOwnerUid(sessionStore: sessionStore)
      : Future.value(
          ownerUid.trim().isEmpty || ownerUid.startsWith('guest_')
              ? CreateOriginDraftStore.anonymousOwner
              : ownerUid.trim(),
        );

  static String _key(String key, String ownerUid) {
    if (ownerUid == CreateOriginDraftStore.anonymousOwner) return key;
    final suffix = base64Url.encode(utf8.encode(ownerUid)).replaceAll('=', '');
    return '${key}_owner_$suffix';
  }
}
