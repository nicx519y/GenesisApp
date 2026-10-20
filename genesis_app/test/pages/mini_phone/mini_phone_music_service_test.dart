import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';
import '../../support/mini_phone_audio_player.dart';
import '../../support/mini_phone_collect_probe.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_analytics.dart';
import 'dart:convert';

MusicCatalog catalog([int count = 3]) => MusicCatalog(
  preUrl: 'https://cdn.example/',
  tracks: [
    for (var i = 0; i < count; i++)
      MusicTrack(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<TestMusicPlayer> players;
  late MiniPhoneMusicService music;
  void Function(TestMusicPlayer player, int number)? configure;
  setUp(() {
    players = [];
    configure = null;
    music = MiniPhoneMusicService(
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
