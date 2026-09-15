import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../channels/genesis_method_channels.dart';
import 'memory_user_session_store.dart';
import 'user_session_store.dart';

bool get _supportsNativeSessionStore => Platform.isAndroid || Platform.isIOS;

class NativeUserSessionStore implements UserSessionStore {
  NativeUserSessionStore({UserSessionStore? fallback})
    : _fallback = fallback ?? MemoryUserSessionStore();

  final UserSessionStore _fallback;
  final ValueNotifier<int> _userInfoRevision = ValueNotifier<int>(0);

  @override
  ValueListenable<int> get userInfoRevision => _userInfoRevision;

  @override
  Future<void> saveUid(String uid) async {
    final value = uid.trim();
    if (value.isEmpty) return;
    await _fallback.saveUid(value);
    if (!_supportsNativeSessionStore) return;
    await GenesisMethodChannels.device.invokeMethod<void>(
      GenesisMethodChannels.setUid,
      {'uid': value},
    );
  }

  @override
  Future<String?> readUid() async {
    final cached = await _fallback.readUid();
    if (cached != null) return cached;
    if (!_supportsNativeSessionStore) return null;
    final uid = await GenesisMethodChannels.device.invokeMethod<String>(
      GenesisMethodChannels.getUid,
    );
    final value = (uid ?? '').trim();
    if (value.isNotEmpty) await _fallback.saveUid(value);
    return value.isEmpty ? null : value;
  }

  /// Dedicated cold-start read; regular session reads keep their existing API.
  Future<String?> readStartupLoginUid(Map<String, Object> timing) async {
    final cached = await _fallback.readUid();
    if (cached != null || !_supportsNativeSessionStore) {
      final uid = cached?.trim() ?? '';
      return uid.isEmpty || uid.startsWith('guest_') ? null : uid;
    }
    final snapshot = await GenesisMethodChannels.device
        .invokeMapMethod<String, dynamic>('getStartupUid');
    for (final key in [
      'native_read_ms',
      'native_queue_ms',
      'native_total_ms',
    ]) {
      final value = snapshot?[key];
      if (value is num && value >= 0) timing[key] = value.toInt();
    }
    if (snapshot == null || snapshot['uid'] is! String) {
      throw const FormatException('Invalid startup UID response');
    }
    final uid = (snapshot['uid'] as String).trim();
    if (uid.isNotEmpty) await _fallback.saveUid(uid);
    return uid.isEmpty || uid.startsWith('guest_') ? null : uid;
  }

  @override
  Future<String?> readAuthToken() async {
    final cached = await _fallback.readAuthToken();
    if (cached != null) return cached;
    if (!_supportsNativeSessionStore) return null;
    final token = await GenesisMethodChannels.device.invokeMethod<String>(
      GenesisMethodChannels.getAuthToken,
    );
    final value = (token ?? '').trim();
    if (value.isNotEmpty) await _fallback.saveAuthToken(value);
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> saveAuthToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) return;
    await _fallback.saveAuthToken(value);
    if (!_supportsNativeSessionStore) return;
    await GenesisMethodChannels.device.invokeMethod<void>(
      GenesisMethodChannels.setAuthToken,
      {'token': value},
    );
  }

  @override
  Future<Map<String, dynamic>?> readUserInfo() async {
    final cached = await _fallback.readUserInfo();
    if (cached != null) return cached;
    if (!_supportsNativeSessionStore) return null;
    final json = await GenesisMethodChannels.device.invokeMethod<String>(
      GenesisMethodChannels.getUserInfo,
    );
    final value = (json ?? '').trim();
    if (value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final userInfo = Map<String, dynamic>.from(decoded);
        await _fallback.saveUserInfo(userInfo);
        return userInfo;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    if (userInfo.isEmpty) return;
    final value = Map<String, dynamic>.from(userInfo);
    await _fallback.saveUserInfo(value);
    try {
      if (_supportsNativeSessionStore) {
        await GenesisMethodChannels.device.invokeMethod<void>(
          GenesisMethodChannels.setUserInfo,
          {'userInfo': jsonEncode(value)},
        );
      }
    } finally {
      _userInfoRevision.value += 1;
    }
  }

  @override
  Future<void> clearUid() async {
    await _fallback.clearUid();
    try {
      if (_supportsNativeSessionStore) {
        await GenesisMethodChannels.device.invokeMethod<void>(
          GenesisMethodChannels.clearUid,
        );
      }
    } finally {
      _userInfoRevision.value += 1;
    }
  }
}
