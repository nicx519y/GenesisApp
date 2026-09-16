import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OriginFeedCacheStore {
  const OriginFeedCacheStore({String? ownerUid, String? gender})
    : _ownerUid = ownerUid,
      _gender = gender;

  static const String storageKey = 'origin_feed_cache_v2';
  static const String anonymousOwnerUid = '__anonymous__';

  final String? _ownerUid;
  final String? _gender;

  /// Manual selections (including All) take precedence over a saved GET value.
  Future<String?> loadPreferredGender() async =>
      await loadManualGender() ?? await loadLastConfirmedGender();

  /// An explicit choice survives page/app restarts. Empty means manual All;
  /// null means the user has not chosen a filter and still follows their profile.
  Future<String?> loadManualGender() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get('origin_feed_manual_gender_v1.$_resolvedOwner');
    return value is String && _isValidGender(value) ? value : null;
  }

  Future<void> saveManualGender(String gender) async {
    if (!_isValidGender(gender)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'origin_feed_manual_gender_v1.$_resolvedOwner',
      gender,
    );
  }

  /// The last confirmed preference can be used immediately on the next launch.
  Future<String?> loadLastConfirmedGender() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get('origin_feed_gender_v1.$_resolvedOwner');
    return value is String && _isValidGender(value) ? value : null;
  }

  Future<void> saveLastConfirmedGender(String? gender) async {
    final value = gender?.trim() ?? '';
    if (!_isValidGender(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('origin_feed_gender_v1.$_resolvedOwner', value);
  }

  /// A submitted form replaces the previous choice, even a manual All.
  Future<void> saveSubmittedGender(String? gender) async {
    final value = gender == 'All' ? '' : gender?.trim() ?? '';
    if (!_isValidGender(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('origin_feed_gender_v1.$_resolvedOwner', value);
    await prefs.remove('origin_feed_manual_gender_v1.$_resolvedOwner');
  }

  static bool _isValidGender(String value) =>
      const {'', 'Male', 'Female', 'Non_binary'}.contains(value);

  Future<Map<String, dynamic>?> loadForYouFirstPage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
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

  Future<void> saveForYouFirstPage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  String get _resolvedOwner {
    final owner = (_ownerUid ?? '').trim();
    return owner.isEmpty ? anonymousOwnerUid : owner;
  }

  String get _storageKey {
    final gender = (_gender ?? '').trim();
    final suffix = gender.isEmpty ? '' : '.gender_$gender';
    return '$storageKey.$_resolvedOwner.foryou.page_1$suffix';
  }
}
