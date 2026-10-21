import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_cache.dart';

MusicTrack song(int id, {String host = 'audio.test'}) => MusicTrack(
  likeCount: 0,
  isLiked: false,
  file: '$id.mp3',
  audioUrl: 'https://$host/$id.mp3',
  sourceWorldoId: 'o',
  sourceWorldoName: 'O',
  artist: 'A',
  title: '$id',
  coverUrl: 'https://$host/$id.jpg',
);

void main() {
  late Directory directory;
  late LocalMiniPhoneMusicCache cache;
  late List<String> downloads;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('miniphone-music-test-');
    downloads = [];
    cache = LocalMiniPhoneMusicCache(
      directory: () async => directory,
      download: (url) async {
        downloads.add(url);
        return [1, 2, 3];
      },
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'complete files persist across cache instances and match full URL',
    () async {
      expect(await cache.find(song(0)), isNull);
      expect(downloads, isEmpty);
      await cache.remember(song(0));
      final uri = (await cache.find(song(0)))!;
      expect(uri.scheme, 'file');
      expect(uri.path, endsWith('.mp3'));
      expect(await File.fromUri(uri).readAsBytes(), [1, 2, 3]);
      final reopened = LocalMiniPhoneMusicCache(
        directory: () async => directory,
      );
      expect(await reopened.find(song(0)), uri);
      expect(await reopened.find(song(0, host: 'other.test')), isNull);
      await cache.remember(song(0));
      expect(downloads, hasLength(1));
    },
  );

  test(
    'only new insertion evicts oldest; playback never reorders entries',
    () async {
      for (var i = 0; i < 10; i++) {
        await cache.remember(song(i));
        final file = File.fromUri((await cache.find(song(i)))!);
        await file.setLastModified(
          DateTime(2000, 1, 1).add(Duration(seconds: i)),
        );
      }
      // Old entries do not expire, even after reopening or playing them again.
      await cache.remember(song(0));
      expect(await cache.find(song(0)), isNotNull);
      expect(await directory.list().length, 10);
      await cache.remember(song(10));
      expect(await cache.find(song(0)), isNull);
      for (var i = 1; i <= 10; i++) {
        expect(await cache.find(song(i)), isNotNull);
      }
      expect(await directory.list().length, 10);
      await cache.remember(song(11));
      expect(await cache.find(song(1)), isNull);
      expect(await directory.list().length, 10);
    },
  );

  test(
    'in-flight download deduplicates and never blocks cached lookups',
    () async {
      await cache.remember(song(0));
      final gate = Completer<List<int>>();
      var requests = 0;
      final downloading = LocalMiniPhoneMusicCache(
        directory: () async => directory,
        download: (_) {
          requests++;
          return gate.future;
        },
      );
      final first = downloading.remember(song(1));
      final second = downloading.remember(song(1));
      expect(identical(first, second), isTrue);
      expect(await downloading.find(song(0)), isNotNull);
      expect(await downloading.find(song(1)), isNull);
      gate.complete([4, 5, 6]);
      await Future.wait([first, second]);
      expect(requests, 1);
      expect(await downloading.find(song(1)), isNotNull);
    },
  );

  test('failed download leaves all ten entries intact and can retry', () async {
    for (var i = 0; i < 10; i++) {
      await cache.remember(song(i));
    }
    var fail = true;
    final failing = LocalMiniPhoneMusicCache(
      directory: () async => directory,
      download: (_) async {
        if (fail) throw const HttpException('offline');
        return [1];
      },
    );
    await failing.remember(song(10));
    expect(await directory.list().length, 10);
    for (var i = 0; i < 10; i++) {
      expect(await cache.find(song(i)), isNotNull);
    }
    expect(await cache.find(song(10)), isNull);
    fail = false;
    await failing.remember(song(10));
    expect(await cache.find(song(10)), isNotNull);
    expect(await directory.list().length, 10);
  });
}
