import 'dart:io';

import '../channels/genesis_method_channels.dart';
import 'memory_user_session_store.dart';
import 'user_session_store.dart';

bool get _supportsNativeSessionStore => Platform.isAndroid || Platform.isIOS;

class NativeUserSessionStore implements UserSessionStore {
  NativeUserSessionStore({UserSessionStore? fallback})
    : _fallback = fallback ?? MemoryUserSessionStore();

  final UserSessionStore _fallback;

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
    if (!_supportsNativeSessionStore) return _fallback.readUid();
    final uid = await GenesisMethodChannels.device.invokeMethod<String>(
      GenesisMethodChannels.getUid,
    );
    final value = (uid ?? '').trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<String?> readAuthToken() async {
    if (!_supportsNativeSessionStore) return _fallback.readAuthToken();
    final token = await GenesisMethodChannels.device.invokeMethod<String>(
      GenesisMethodChannels.getAuthToken,
    );
    final value = (token ?? '').trim();
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
  Future<void> clearUid() async {
    await _fallback.clearUid();
    if (!_supportsNativeSessionStore) return;
    await GenesisMethodChannels.device.invokeMethod<void>(
      GenesisMethodChannels.clearUid,
    );
  }
}
