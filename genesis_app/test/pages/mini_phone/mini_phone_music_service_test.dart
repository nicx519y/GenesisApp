import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_cache.dart';
import '../../support/mini_phone_audio_player.dart';
import '../../support/mini_phone_collect_probe.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_analytics.dart';
import 'dart:convert';

MusicCatalog catalog([int count = 3]) => MusicCatalog(
  preUrl: 'https://cdn.example/',
  tracks: [
    for (var i = 0; i < count; i++)
      MusicTrack(
        likeCount: 0,
        isLiked: false,
        file: '$i.mp3',
        audioUrl: 'https://cdn.example/$i.mp3',
        sourceWorldoId: 'o_test',
        sourceWorldoName: 'Worldo',
        artist: 'Artist',
        title: 'Track $i',
        coverUrl: 'https://cdn.example/$i.jpg',
      ),
  ],
);
Future<void> flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class TestAudioCache implements MiniPhoneMusicCache {
  final entries = <String, Uri>{};
  final heard = <String>[];
  @override
  Future<Uri?> find(MusicTrack track) async => entries[track.file];
  @override
  Future<void> remember(MusicTrack track) async {
    heard.add(track.file);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<TestMusicPlayer> players;
  late MiniPhoneMusicService music;
  late TestAudioCache cache;
  void Function(TestMusicPlayer player, int number)? configure;
  setUp(() {
    players = [];
    configure = null;
    cache = TestAudioCache();
    music = MiniPhoneMusicService(
      audioCache: cache,
      playerFactory: () {
        final player = TestMusicPlayer();
        configure?.call(player, players.length);
        players.add(player);
        player.onPlay = () => expect(
          players.where((p) => p.playing).length,
          1,
          reason: 'Only one native decoder may be audible',
        );
        return player;
      },
    );
  });
  tearDown(() async {
    music.dispose();
    await flush();
  });

  test(
    'engagement refresh merges requests and preserves tracks and decoders',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      final tracks = music.tracks;
      final selected = music.track;
      final decoders = players.toList();
      final position = music.positionDuration;
      final gate = Completer<MusicCatalog>();
      var calls = 0;
      Future<MusicCatalog> loader() {
        calls++;
        return gate.future;
      }

      final first = music.refreshLikes(loader);
      final second = music.refreshLikes(loader);
      expect(identical(first, second), isTrue);
      await flush();
      expect(calls, 1);
      final song = selected!;
      gate.complete(
        MusicCatalog(
          preUrl: 'https://changed.test/',
          tracks: [
            MusicTrack(
              file: song.file,
              audioUrl: 'https://changed.test/audio.mp3',
              sourceWorldoId: song.sourceWorldoId,
              sourceWorldoName: song.sourceWorldoName,
              artist: song.artist,
              title: 'Changed metadata',
              coverUrl: song.coverUrl,
              likeCount: 1000,
              isLiked: true,
            ),
          ],
        ),
      );
      await first;
      expect(identical(music.tracks, tracks), isTrue);
      expect(identical(music.track, selected), isTrue);
      expect(players, decoders);
      expect(decoders.every((p) => !p.disposed), isTrue);
      expect(music.playing, isTrue);
      expect(music.positionDuration, position);
      expect(music.likes.likeCount(song.file), 1000);
      expect(music.likes.isLiked(song.file), isTrue);
      await music.refreshLikes(() => throw StateError('offline'));
      expect(music.likes.likeCount(song.file), 1000);
      expect(music.track, same(selected));
      expect(music.catalogError, isNotNull);
    },
  );

  test(
    'plays matching local audio first and only caches audible selections',
    () async {
      cache.entries['0.mp3'] = Uri.file('/cache/0.mp3');
      cache.entries['1.mp3'] = Uri.file('/cache/1.mp3');
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      expect(players[0].url, 'file:///cache/0.mp3');
      expect(players[1].url, 'file:///cache/1.mp3');
      expect(cache.heard, ['0.mp3']);
      await music.next();
      expect(cache.heard, ['0.mp3', '1.mp3']);
    },
  );

  test('unreadable cached audio falls back to streaming', () async {
    cache.entries['0.mp3'] = Uri.file('/cache/broken.mp3');
    configure = (player, number) {
      if (number == 0) player.failLoads = 1;
    };
    await music.loadCatalog(() async => catalog(1));
    await music.toggle();
    expect(players.single.loads, 2);
    expect(players.single.url, 'https://cdn.example/0.mp3');
    expect(music.playbackError, isNull);
    expect(music.playing, isTrue);
  });

  test(
    'buffering and a pending seek stay interactive; latest seek wins',
    () async {
      await music.loadCatalog(() async => catalog(1));
      await music.toggle();
      final player = players.single;
      player.processingState = ProcessingState.buffering;
      player.emitState();
      expect(music.canSeek, isTrue);
      player.seekGate = Completer<void>();
      final first = music.seek(20);
      await flush();
      expect(music.loading, isTrue);
      expect(music.canSeek, isTrue);
      final second = music.seek(40);
      final third = music.seek(60);
      // A new native target must not wait for the previous target to buffer.
      expect(player.seekTargets.last, const Duration(seconds: 60));
      expect(music.position, 60);
      player.position = const Duration(seconds: 21);
      player.positions.add(player.position);
      expect(music.position, 60);
      player.seekGate!.complete();
      await Future.wait([first, second, third]);
      expect(player.seekTargets, [
        const Duration(seconds: 20),
        const Duration(seconds: 40),
        const Duration(seconds: 60),
      ]);
      expect(music.position, 60);
      expect(music.playing, isTrue);
    },
  );

  test(
    'exit during a seek retains the latest target for the next World',
    () async {
      await music.loadCatalog(() async => catalog(1));
      await music.toggle();
      final player = players.single;
      player.seekGate = Completer<void>();
      final seeking = music.seek(60);
      music.detachWorld();
      expect(music.position, 60);
      music.attachWorld();
      player.seekGate!.complete();
      await seeking;
      await music.toggle();
      expect(music.position, 60);
      expect(music.playing, isTrue);
    },
  );

  test(
    'seek during initial buffering applies latest target before playback',
    () async {
      final gate = Completer<void>();
      configure = (player, _) => player.loadGate = gate;
      await music.loadCatalog(() async => catalog(1));
      final starting = music.toggle();
      await flush();
      final player = players.single;
      player.duration = const Duration(seconds: 90);
      player.durations.add(player.duration);
      expect(music.canSeek, isTrue);
      final first = music.seek(15);
      final last = music.seek(45);
      player.onPlay = () => expect(player.position.inSeconds, 45);
      gate.complete();
      await Future.wait([starting, first, last]);
      expect(player.seekTargets, [const Duration(seconds: 45)]);
      expect(music.position, 45);
    },
  );

  test(
    'switching songs discards a pending seek from the previous song',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      players.first.seekGate = Completer<void>();
      final seeking = music.seek(60);
      await flush();
      final switching = music.next();
      players.first.seekGate!.complete();
      await Future.wait([seeking, switching]);
      expect(music.track!.file, '1.mp3');
      expect(music.position, 0);
      expect(players[1].seekTargets, isEmpty);
    },
  );

  test(
    'Collect tracks only user music commands and drops closed open ID',
    () async {
      final collect = MiniPhoneCollectProbe();
      addTearDown(collect.dispose);
      music.analytics = MiniPhoneAnalytics(
        worldId: 'w',
        enabled: () => true,
        generation: () => 0,
      );
      final open = music.analytics!.beginOpen();
      await music.loadCatalog(() async => catalog());
      await music.userToggle('music');
      await music.userToggle('home');
      await music.userNext('music');
      await music.userPrevious('music');
      final events = await collect.take();
      expect(events.map((e) => e.object3), [
        'play',
        'pause',
        'next',
        'previous',
      ]);
      expect(events.map((e) => e.object2), [
        '0.mp3',
        '0.mp3',
        '0.mp3',
        '1.mp3',
      ]);
      expect(jsonDecode(events.first.extData)['open_id'], open);
      await music.next();
      await music.pause();
      expect(await collect.take(), isEmpty);
      music.analytics!.endOpen(open);
      await music.userToggle('dock');
      final dock = (await collect.take()).single;
      expect(jsonDecode(dock.extData), {'source': 'dock'});
    },
  );

  test(
    'catalogue loads are deduplicated and cached without creating decoders',
    () async {
      final gate = Completer<MusicCatalog>();
      var calls = 0;
      Future<MusicCatalog> loader() {
        calls++;
        return gate.future;
      }

      final first = music.loadCatalog(loader);
      final second = music.loadCatalog(loader);
      await flush();
      expect(calls, 1);
      expect(music.catalogLoading, isTrue);
      gate.complete(catalog());
      await Future.wait([first, second]);
      await music.loadCatalog(loader);
      expect(calls, 1);
      expect(players, isEmpty);
      expect(music.nextTrack!.file, '1.mp3');
    },
  );
  test('synchronous catalogue failure is retryable', () async {
    await music.loadCatalog(() => throw StateError('offline'));
    expect(music.catalogError, isNotNull);
    await music.loadCatalog(() async => catalog());
    expect(music.catalogError, isNull);
  });
  test(
    'play prepares only current and next; next reuses the buffered decoder',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      expect(players, hasLength(2));
      expect(players[0].url, 'https://cdn.example/0.mp3');
      expect(players[1].url, 'https://cdn.example/1.mp3');
      expect(players[1].plays, 0);
      expect(music.duration, 90);
      expect(music.bufferedPosition, const Duration(seconds: 5));
      final preparedLoads = players[1].loads;
      await music.next();
      await flush();
      expect(music.index, 1);
      expect(music.playing, isTrue);
      expect(players[1].loads, preparedLoads);
      expect(players[1].plays, 1);
      expect(players[0].url, 'https://cdn.example/2.mp3');
      expect(players, hasLength(2));
    },
  );
  test(
    'seek uses milliseconds and previous preserves the three-second rule',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      await music.seekTo(const Duration(milliseconds: 10500));
      expect(music.positionDuration, const Duration(milliseconds: 10500));
      await music.previous();
      expect(music.index, 0);
      expect(music.position, 0);
      await music.previous();
      expect(music.index, 2);
      await music.next();
      expect(music.index, 0);
      await music.seek(120);
      expect(music.position, 90);
      await music.seekTo(const Duration(seconds: -1));
      expect(music.position, 0);
    },
  );
  test(
    'next and previous start playback before any track has played',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.next();
      await flush();
      expect(music.index, 1);
      expect(music.playing, isTrue);
      expect(music.activated, isTrue);
      await music.pause();
      await music.previous();
      await flush();
      expect(music.index, 0);
      expect(music.playing, isTrue);
      await music.pause();
      await music.next();
      await flush();
      expect(music.index, 1);
      expect(music.playing, isTrue);
    },
  );
  test(
    'previous restarts and plays a paused track beyond three seconds',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      await music.seek(10);
      await music.pause();
      await music.previous();
      await flush();
      expect(music.index, 0);
      expect(music.position, 0);
      expect(music.playing, isTrue);
    },
  );
  test('single-song navigation resumes the existing paused player', () async {
    await music.loadCatalog(() async => catalog(1));
    await music.toggle();
    await music.pause();
    await music.next();
    await flush();
    expect(music.playing, isTrue);
    await music.pause();
    await music.previous();
    await flush();
    expect(music.playing, isTrue);
    expect(players, hasLength(1));
    expect(players.single.loads, 1);
  });
  test(
    'backgrounding during a navigation load prevents delayed autoplay',
    () async {
      final gate = Completer<void>();
      configure = (player, _) => player.loadGate = gate;
      await music.loadCatalog(() async => catalog());
      final switching = music.next();
      await flush();
      music.didChangeAppLifecycleState(AppLifecycleState.paused);
      music.didChangeAppLifecycleState(AppLifecycleState.resumed);
      gate.complete();
      await switching;
      await flush();
      expect(music.playing, isFalse);
      expect(music.playRequested, isFalse);
      expect(players.single.plays, 0);
    },
  );
  test(
    'completion advances automatically and wraps using only two decoders',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      players[0].completeTrack();
      await flush();
      expect(music.index, 1);
      expect(players[1].plays, 1);
      players[1].completeTrack();
      await flush();
      expect(music.index, 2);
      players[0].completeTrack();
      await flush();
      expect(music.index, 0);
      expect(players, hasLength(2));
    },
  );
  test('single-song catalogues loop without allocating a standby', () async {
    await music.loadCatalog(() async => catalog(1));
    await music.toggle();
    await flush();
    expect(music.nextTrack, isNull);
    expect(players, hasLength(1));
    players.single.completeTrack();
    await flush();
    expect(music.index, 0);
    expect(music.playing, isTrue);
    expect(players, hasLength(1));
    expect(players.single.loads, 1);
    expect(players.single.seeks, 1);
    expect(music.positionDuration, Duration.zero);
  });
  test(
    'pause during initial load cannot later start sound or preloading',
    () async {
      final gate = Completer<void>();
      configure = (player, _) => player.loadGate = gate;
      await music.loadCatalog(() async => catalog());
      final starting = music.toggle();
      await flush();
      await music.toggle();
      gate.complete();
      await starting;
      await flush();
      expect(players.single.plays, 0);
      expect(music.playRequested, isFalse);
    },
  );
  test(
    'background cancels standby load and returning foreground does not play',
    () async {
      final gate = Completer<void>();
      configure = (player, number) {
        if (number == 1) player.loadGate = gate;
      };
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      music.didChangeAppLifecycleState(AppLifecycleState.paused);
      await flush();
      expect(players[1].stops, greaterThan(0));
      expect(music.playing, isFalse);
      music.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(players.where((p) => p.playing), isEmpty);
      expect(players[1].plays, 0);
      await music.toggle();
      await flush();
      expect(music.playing, isTrue);
      expect(players, hasLength(2));
    },
  );
  test(
    'background also cancels a ready standby whose initial buffer is unfinished',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      players[1].buffer(const Duration(seconds: 1));
      music.didChangeAppLifecycleState(AppLifecycleState.paused);
      await flush();
      expect(players[1].stops, 1);
      music.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(players[1].loads, 1);
      expect(music.playRequested, isFalse);
      await music.toggle();
      await flush();
      expect(players[1].loads, 2);
      expect(players[1].playing, isFalse);
    },
  );
  test(
    'failed standby never interrupts active audio and next retries it',
    () async {
      configure = (player, number) {
        if (number == 1) player.failLoads = 1;
      };
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      expect(music.playing, isTrue);
      expect(music.playbackError, isNull);
      await music.next();
      await flush();
      expect(music.index, 1);
      expect(music.playing, isTrue);
      expect(players[1].loads, 2);
    },
  );
  test(
    'current load failure clears intent and supports retry or skipping',
    () async {
      configure = (player, number) {
        if (number == 0) player.failLoads = 1;
      };
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      expect(music.playbackError, isNotNull);
      expect(music.loading, isFalse);
      expect(music.playRequested, isFalse);
      await music.next();
      expect(music.index, 1);
      expect(music.playbackError, isNull);
      expect(music.playing, isTrue);
      await music.toggle();
      expect(music.playing, isFalse);
      await music.toggle();
      expect(music.playing, isTrue);
    },
  );
  test(
    'selection switches metadata and clears old progress before next is ready',
    () async {
      final gate = Completer<void>();
      configure = (player, number) {
        if (number == 1) player.loadGate = gate;
      };
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      await music.seek(20);
      final switching = music.next();
      expect(music.track!.file, '1.mp3');
      expect(music.position, 0);
      expect(music.bufferedPosition, Duration.zero);
      expect(music.duration, isNull);
      expect(players[0].playing, isFalse);
      await music.pause();
      gate.complete();
      await switching;
      expect(music.playing, isFalse);
    },
  );
  test(
    'rapid selection cancels obsolete loads and never plays the skipped song',
    () async {
      final gate = Completer<void>();
      configure = (player, number) {
        if (number == 1) player.loadGate = gate;
      };
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      final first = music.next();
      await flush();
      final second = music.next();
      await Future.wait([first, second]);
      await flush();
      expect(music.index, 2);
      expect(music.playbackError, isNull);
      expect(players[1].url, 'https://cdn.example/2.mp3');
      expect(players[1].plays, 1);
      expect(players, hasLength(2));
    },
  );
  test(
    'buffer updates and native audio interruptions update the shared state',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      players[0].buffer(const Duration(seconds: 15));
      expect(music.bufferedPosition, const Duration(seconds: 15));
      players[0].playing = false;
      players[0].emitState();
      expect(music.playRequested, isFalse);
    },
  );
  test(
    'stream errors pause active audio and disposal releases both decoders',
    () async {
      await music.loadCatalog(() async => catalog());
      await music.toggle();
      await flush();
      players[0].errors.add(PlayerException(1, 'network failure', null));
      await flush();
      expect(music.playbackError, isNotNull);
      expect(music.playing, isFalse);
      music.dispose();
      await flush();
      expect(players.every((p) => p.disposed), isTrue);
      expect(players[0].states.hasListener, isFalse);
    },
  );
}
