import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';

import '../../support/mini_phone_audio_player.dart';
import '../../support/mini_phone_music_services.dart';

final _catalog = MusicCatalog(
  preUrl: 'https://cdn.example/',
  tracks: [
    for (final file in ['a.mp3', 'b.mp3'])
      MusicTrack(
        file: file,
        audioUrl: 'https://cdn.example/$file',
        sourceWorldoId: 'o',
        sourceWorldoName: 'O',
        artist: 'A',
        title: file,
        coverUrl: '',
      ),
  ],
);

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Worlds reuse catalogue, progress and ready native decoders', () async {
    final revision = ValueNotifier(0);
    final players = <TestMusicPlayer>[];
    final owner = MiniPhoneMusicOwner(
      namespace: 'prod',
      readUid: () async => 'u',
      accountRevision: revision,
      createMusic: (store) => MiniPhoneMusicService(
        progressStore: store,
        playerFactory: () {
          final player = TestMusicPlayer();
          players.add(player);
          return player;
        },
      ),
    );
    addTearDown(() {
      owner.dispose();
      revision.dispose();
    });
    final first = MiniPhoneSession(
      worldId: 'a',
      musicLease: owner.acquire('a'),
    );
    final music = first.music;
    var catalogueLoads = 0;
    Future<MusicCatalog> load() async {
      catalogueLoads++;
      return _catalog;
    }

    await music.loadCatalog(load);
    await music.toggle();
    await _flush();
    await music.seekTo(const Duration(seconds: 12));
    expect(players, hasLength(2));
    final loads = players.map((p) => p.loads).toList();
    first.dispose();
    await music.progressSaved;
    expect(music.playRequested, isFalse);
    expect(music.isDisposed, isFalse);
    expect(music.analytics, isNull);
    expect(players.every((p) => !p.disposed && !p.playing), isTrue);
    // Even a stale caller cannot start playback between Worlds.
    await music.toggle();
    expect(music.playRequested, isFalse);
    final second = MiniPhoneSession(
      worldId: 'b',
      musicLease: owner.acquire('b'),
    );
    expect(second.music, same(music));
    await second.music.loadCatalog(load);
    expect(catalogueLoads, 1);
    expect(music.positionDuration, const Duration(seconds: 12));
    expect(music.playRequested, isFalse);
    await music.toggle();
    expect(music.playing, isTrue);
    expect(players.map((p) => p.loads).toList(), loads);
    second.dispose();
  });

  test(
    'exit during loading cannot autoplay after immediately entering another World',
    () async {
      final revision = ValueNotifier(0);
      final players = <TestMusicPlayer>[];
      final owner = MiniPhoneMusicOwner(
        namespace: 'prod',
        readUid: () async => 'u',
        accountRevision: revision,
        createMusic: (store) => MiniPhoneMusicService(
          progressStore: store,
          playerFactory: () {
            final player = TestMusicPlayer()..loadGate = Completer<void>();
            players.add(player);
            return player;
          },
        ),
      );
      addTearDown(() {
        owner.dispose();
        revision.dispose();
      });
      final first = owner.acquire('a');
      await first.music.loadCatalog(() async => _catalog);
      final loading = first.music.toggle();
      await _flush();
      first.release();
      final second = owner.acquire('b');
      await loading;
      await _flush();
      expect(second.music, same(first.music));
      expect(players.first.disposed, isFalse);
      expect(players.first.plays, 0);
      expect(second.music.playRequested, isFalse);
      await second.music.toggle();
      expect(second.music.playing, isTrue);
      // A late release from World A must not pause World B.
      first.release();
      expect(second.music.playing, isTrue);
      second.release();
      expect(second.music.playing, isFalse);
    },
  );

  test('account changes and app disposal release resident resources', () async {
    final revision = ValueNotifier(0);
    var uid = 'u';
    final players = <TestMusicPlayer>[];
    final owner = MiniPhoneMusicOwner(
      namespace: 'prod',
      readUid: () async => uid,
      accountRevision: revision,
      createMusic: (store) => MiniPhoneMusicService(
        progressStore: store,
        playerFactory: () {
          final player = TestMusicPlayer();
          players.add(player);
          return player;
        },
      ),
    );
    addTearDown(() {
      owner.dispose();
      revision.dispose();
    });
    final first = owner.acquire('a');
    await first.music.loadCatalog(() async => _catalog);
    await first.music.toggle();
    await first.music.seekTo(const Duration(seconds: 12));
    uid = 'v';
    revision.value++;
    await first.music.released;
    expect(first.music.isDisposed, isTrue);
    expect(players.every((p) => p.disposed), isTrue);
    final second = owner.acquire('b');
    expect(second.music, isNot(same(first.music)));
    await second.music.loadCatalog(() async => _catalog);
    expect(second.music.positionDuration, Duration.zero);
    await second.music.toggle();
    first.release();
    expect(second.music.playing, isTrue);
    owner.dispose();
    await second.music.released;
    expect(players.every((p) => p.disposed), isTrue);
  });

  testWidgets('production World factory borrows the AppServices player', (
    tester,
  ) async {
    final services = musicTestServices(GenesisApi(useMock: true));
    late BuildContext worldContext;
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              worldContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    final first = MiniPhoneSession.forWorld(worldContext, 'a');
    first.dispose();
    final second = MiniPhoneSession.forWorld(worldContext, 'b');
    expect(second.music, same(first.music));
    expect(second.music.isDisposed, isFalse);
    expect(second.music.analytics, same(second.data!.analytics));
    second.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(second.music.isDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
