import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/profile_avatar_cache.dart';

void main() {
  const avatar = 'https://cdn.example.com/avatar.png';
  const resized = '$avatar?x-oss-process=image/resize,w_160/format,webp';
  final loginBytes = Uint8List.fromList([1, 2, 3]);
  final editedBytes = Uint8List.fromList([4, 5, 6]);
  late MemoryUserSessionStore session;
  late ValueNotifier<int> revision;
  late File file;

  setUp(() async {
    session = MemoryUserSessionStore();
    revision = ValueNotifier(0);
    final directory = await Directory.systemTemp.createTemp('profile-avatar-');
    file = File('${directory.path}/avatar.json');
    addTearDown(() => directory.delete(recursive: true));
    addTearDown(revision.dispose);
  });

  Future<void> login(String uid, String url) async {
    await session.saveUid(uid);
    await session.saveUserInfo({'uid': uid, 'avatar': url});
    revision.value += 1;
  }

  ProfileAvatarCache createCache(Future<Uint8List?> Function(String) download) {
    return ProfileAvatarCache(
      sessionStore: session,
      sessionRevision: revision,
      namespace: 'test',
      cacheFile: () async => file,
      download: download,
    );
  }

  test('warms after login and restores the saved edit from disk', () async {
    final downloads = <String>[];
    final cache = createCache((url) async {
      downloads.add(url);
      return loginBytes;
    });
    try {
      await login('first', avatar);
      await _waitFor(() => cache.bytesFor(avatar) != null);
      expect(cache.bytesFor(avatar), loginBytes);
      expect(downloads, [resized]);
      expect(cache.bytesFor('https://cdn.example.com/another.png'), isNull);

      await cache.replaceFromEdit(avatar, editedBytes);
      expect(cache.bytesFor(avatar), editedBytes);
    } finally {
      cache.dispose();
    }

    final restored = createCache((url) async {
      downloads.add(url);
      return null;
    });
    addTearDown(restored.dispose);
    await _waitFor(() => restored.bytesFor(avatar) != null);
    expect(restored.bytesFor(avatar), editedBytes);
    expect(downloads, [resized]);

    await session.clearUid();
    revision.value += 1;
    expect(restored.bytesFor(avatar), isNull);
    await _waitFor(() => !file.existsSync());
  });

  test('a late download cannot repopulate a signed-out avatar cache', () async {
    final started = Completer<void>();
    final oldDownload = Completer<Uint8List>();
    final cache = createCache((_) {
      started.complete();
      return oldDownload.future;
    });
    addTearDown(cache.dispose);
    await login('first', avatar);
    await started.future;
    await session.clearUid();
    revision.value += 1;
    oldDownload.complete(loginBytes);
    await Future<void>.delayed(Duration.zero);
    expect(cache.bytesFor(avatar), isNull);
    expect(await file.exists(), isFalse);
  });

  test('switching accounts reloads even when the avatar URL is shared', () async {
    var downloads = 0;
    final cache = createCache((_) async {
      downloads += 1;
      return downloads == 1 ? loginBytes : editedBytes;
    });
    addTearDown(cache.dispose);
    await login('first', avatar);
    await _waitFor(() => cache.bytesFor(avatar) != null);
    expect(cache.bytesFor(avatar), loginBytes);

    await login('second', avatar);
    await _waitFor(() => identical(cache.bytesFor(avatar), editedBytes));
    expect(downloads, 2);
  });
}

Future<void> _waitFor(bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Avatar cache did not reach the expected state');
}
