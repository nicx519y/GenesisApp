import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../network/genesis_api.dart';
import '../../network/genesis_http_cache_manager.dart';
import '../../network/json_utils.dart';
import '../../utils/genesis_image_resource.dart';
import 'user_session_store.dart';

String resolveProfileAvatarUrl(Map<String, dynamic> user) => asResolvedImageUrl(
  user['avatar'],
  resolveAssetUrl,
  fallback:
      user['avatar_url'] ??
      user['photoUrl'] ??
      user['photo_url'] ??
      user['picture'],
);

typedef _AvatarIdentity = ({String uid, String url});

/// One profile preview per API environment. Role portraits still load their
/// own larger CDN image.
class ProfileAvatarCache extends ChangeNotifier {
  ProfileAvatarCache({
    required UserSessionStore sessionStore,
    required ValueListenable<int> sessionRevision,
    required String namespace,
    Future<File> Function()? cacheFile,
    Future<Uint8List?> Function(String url)? download,
  }) : _sessionStore = sessionStore,
       _sessionRevision = sessionRevision,
       _cacheFile = cacheFile ?? (() => _fileForNamespace(namespace)),
       _download = download ?? _downloadAvatar {
    _sessionStore.userInfoRevision.addListener(_refresh);
    _sessionRevision.addListener(_resetForSession);
    _refresh();
  }

  final UserSessionStore _sessionStore;
  final ValueListenable<int> _sessionRevision;
  final Future<File> Function() _cacheFile;
  final Future<Uint8List?> Function(String url) _download;
  _AvatarIdentity? _identity;
  Uint8List? _bytes;
  Future<void> _diskWork = Future.value();
  int _request = 0;
  int _generation = 0;
  bool _loading = false;
  bool _disposed = false;

  Uint8List? bytesFor(String url) =>
      _identity?.url == url.trim() ? _bytes : null;

  Future<void> replaceFromEdit(String url, Uint8List bytes) =>
      _sync(++_request, edited: (url: url.trim(), bytes: bytes));

  void _refresh() => unawaited(_sync(++_request));

  void _resetForSession() {
    _generation += 1;
    _identity = null;
    _loading = false;
    _setBytes(null);
    _refresh();
  }

  Future<void> _sync(
    int request, {
    ({String url, Uint8List bytes})? edited,
  }) async {
    final _AvatarIdentity? next;
    try {
      final uid = await _sessionStore.readLoginUid();
      final user = uid == null ? null : await _sessionStore.readUserInfo();
      final owner = asString(user?['uid']).trim();
      final url = user != null && (owner.isEmpty || owner == uid)
          ? resolveProfileAvatarUrl(user)
          : '';
      final uri = Uri.tryParse(url);
      next =
          uid != null &&
              uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host.isNotEmpty
          ? (uid: uid, url: url)
          : null;
    } catch (_) {
      return;
    }
    if (_disposed || request != _request) return;
    final seed = next != null && next.url == edited?.url ? edited?.bytes : null;
    if (next == _identity && seed == null && (_loading || _bytes != null)) {
      return;
    }
    final generation = ++_generation;
    if (next != _identity) {
      _identity = next;
      _setBytes(null);
    }
    _loading = true;
    try {
      if (seed == null) {
        final cached = await _readDisk(next, generation);
        if (!_isCurrent(generation) || next == null) return;
        if (cached != null) {
          _setBytes(cached);
          return;
        }
      }
      if (next == null) return;
      final bytes =
          seed ??
          await _download(buildGenesisCdnResizeUrl(next.url, width: 160));
      if (!_isCurrent(generation) || bytes == null || bytes.isEmpty) return;
      _setBytes(bytes);
      await _writeDisk(next, bytes, generation);
    } catch (_) {
      // A preview cache miss must never interrupt sign-in or profile updates.
    } finally {
      if (_isCurrent(generation)) _loading = false;
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setBytes(Uint8List? bytes) {
    if (identical(_bytes, bytes)) return;
    _bytes = bytes;
    notifyListeners();
  }

  Future<Uint8List?> _readDisk(_AvatarIdentity? identity, int generation) =>
      _onDisk((file) async {
        if (!_isCurrent(generation) || !await file.exists()) return null;
        if (identity != null) {
          try {
            final data = asJsonMap(jsonDecode(await file.readAsString()));
            if (data['uid'] == identity.uid && data['url'] == identity.url) {
              final bytes = base64Decode(asString(data['bytes']));
              if (bytes.isNotEmpty) return bytes;
            }
          } catch (_) {
            // Discard a corrupt cache entry and try the CDN.
          }
        }
        if (_isCurrent(generation)) await file.delete();
        return null;
      });

  Future<void> _writeDisk(
    _AvatarIdentity identity,
    Uint8List bytes,
    int generation,
  ) => _onDisk((file) async {
    if (!_isCurrent(generation)) return;
    final temporary = File('${file.path}.${identityHashCode(this)}.tmp');
    try {
      await temporary.writeAsString(
        jsonEncode({
          'uid': identity.uid,
          'url': identity.url,
          'bytes': base64Encode(bytes),
        }),
      );
      if (_isCurrent(generation)) await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  });

  Future<T?> _onDisk<T>(Future<T?> Function(File) operation) {
    final work = _diskWork.then((_) async {
      try {
        return await operation(await _cacheFile());
      } catch (_) {
        return null;
      }
    });
    _diskWork = work.then<void>((_) {});
    return work;
  }

  static Future<File> _fileForNamespace(String namespace) async {
    final directory = await getApplicationSupportDirectory();
    final key = sha256.convert(utf8.encode(namespace));
    return File('${directory.path}/profile-avatar-v1-$key.json');
  }

  static Future<Uint8List?> _downloadAvatar(String url) async {
    final response = await GenesisHttpFileService().get(url);
    if (response.statusCode != 200) return null;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.content) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  void dispose() {
    _disposed = true;
    _bytes = null;
    _sessionStore.userInfoRevision.removeListener(_refresh);
    _sessionRevision.removeListener(_resetForSession);
    super.dispose();
  }
}
