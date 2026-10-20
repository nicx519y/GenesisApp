import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_progress.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/platform/system_image_picker_activity.dart';
import '../../support/mini_phone_audio_player.dart';
import '../../support/mini_phone_music_services.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/pages/world/world_page.dart';

MusicCatalog _catalog() => MusicCatalog(
  preUrl: 'https://cdn.example/',
  tracks: [
    for (var i = 0; i < 2; i++)
      MusicTrack(
        file: '$i.mp3',
        audioUrl: 'https://cdn.example/$i.mp3',
        sourceWorldoId: 'o',
        sourceWorldoName: 'O',
        artist: 'A',
        title: 'T$i',
        coverUrl: 'assets/mini_phone/loc_1_1_1.jpg',
      ),
  ],
);
LocalMiniPhoneMusicProgressStore _store({
  String world = 'a',
  String owner = 'u',
  String env = 'prod',
  Future<SharedPreferences> Function()? preferences,
}) => LocalMiniPhoneMusicProgressStore(
  namespace: env,
  legacyWorldId: world,
  owner: Future.value(owner),
  preferences: preferences,
);
Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _saved = MiniPhoneMusicProgress(
  file: '1.mp3',
  position: Duration(milliseconds: 12567),
  duration: Duration(seconds: 90),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'local progress is shared across worlds but isolates account and environment',
    () async {
      await _store().write(_saved);
      expect((await _store().read())!.position, _saved.position);
      expect((await _store(world: 'b').read())!.position, _saved.position);
      expect(await _store(owner: 'v').read(), isNull);
      expect(await _store(env: 'debug').read(), isNull);
    },
  );
  test('reopening waits for the exit write and later writes win', () async {
    final gate = Completer<SharedPreferences>();
    final first = _store(preferences: () => gate.future).write(_saved);
    await _flush();
    final second = _store(world: 'b').write(
      const MiniPhoneMusicProgress(
        file: '0.mp3',
        position: Duration(seconds: 3),
      ),
    );
    final read = _store().read();
    gate.complete(await SharedPreferences.getInstance());
    await Future.wait([first, second]);
    expect((await read)!.file, '0.mp3');
  });
  test('first valid legacy world seeds shared progress only once', () async {
    SharedPreferences.setMockInitialValues({
      'miniphone_music_v1:prod:u:a': '{"file":"1.mp3","position_ms":12000}',
      'miniphone_music_v1:prod:u:b': '{"file":"0.mp3","position_ms":3000}',
    });
    final results = await Future.wait([
      _store().read(),
      _store(world: 'b').read(),
    ]);
    expect(results.map((result) => result!.file), everyElement('1.mp3'));
    await _store(world: 'b').write(_saved);
    expect((await _store().read())!.position, _saved.position);
    expect(await _store(owner: 'v').read(), isNull);
    expect(await _store(env: 'debug').read(), isNull);
  });
  test(
    'invalid legacy progress does not prevent another world migration',
    () async {
      SharedPreferences.setMockInitialValues({
        'miniphone_music_v1:prod:u:a': 'invalid',
        'miniphone_music_v1:prod:u:b': '{"file":"1.mp3","position_ms":12000}',
      });
      expect(await _store().read(), isNull);
      expect((await _store(world: 'b').read())!.file, '1.mp3');
      expect((await _store().read())!.file, '1.mp3');
    },
  );
  test('legacy migration cannot overwrite a pending shared save', () async {
    SharedPreferences.setMockInitialValues({
      'miniphone_music_v1:prod:u:b': '{"file":"0.mp3","position_ms":3000}',
    });
    final gate = Completer<SharedPreferences>();
    final write = _store(preferences: () => gate.future).write(_saved);
    await _flush();
    final read = _store(world: 'b').read();
    gate.complete(await SharedPreferences.getInstance());
    await write;
    expect((await read)!.position, _saved.position);
  });
  test(
    'invalid local records are ignored and positions clamp to duration',
    () async {
      const key = 'miniphone_music_v2:prod:u';
      final prefs = await SharedPreferences.getInstance();
      for (final raw in [
        'oops',
        '{}',
        '{"file":"1.mp3","position_ms":-1}',
        '{"file":"1.mp3","position_ms":1,"duration_ms":0}',
      ]) {
        await prefs.setString(key, raw);
        expect(await _store().read(), isNull);
      }
      await prefs.setString(
        key,
        '{"file":"1.mp3","position_ms":200,"duration_ms":100}',
      );
      expect(
        (await _store().read())!.position,
        const Duration(milliseconds: 100),
      );
    },
  );
  test(
    'restoration remains paused, plays at cached milliseconds and exit saves',
    () async {
      await _store().write(_saved);
      final players = <TestMusicPlayer>[];
      final music = MiniPhoneMusicService(
        progressStore: _store(),
        playerFactory: () {
          final p = TestMusicPlayer();
          players.add(p);
          return p;
        },
      );
      await music.loadCatalog(() async => _catalog());
      expect(music.track!.file, '1.mp3');
      expect(music.positionDuration, _saved.position);
      expect(music.playRequested, isFalse);
      expect(players, isEmpty);
      await music.toggle();
      await _flush();
      expect(players.first.position, _saved.position);
      await music.seekTo(const Duration(milliseconds: 23456));
      music.dispose();
      await Future.wait([music.released, music.progressSaved]);
      expect(players.every((p) => p.disposed && !p.playing), isTrue);
      final reopened = MiniPhoneMusicService(
        progressStore: _store(world: 'b'),
        playerFactory: TestMusicPlayer.new,
      );
      addTearDown(reopened.dispose);
      await reopened.loadCatalog(() async => _catalog());
      expect(reopened.positionDuration, const Duration(milliseconds: 23456));
      expect(reopened.playRequested, isFalse);
      await music.next();
      expect(
        (await _store().read())!.position,
        const Duration(milliseconds: 23456),
      );
    },
  );
  test('deleted cached song falls back to first track at zero', () async {
    await _store().write(
      const MiniPhoneMusicProgress(
        file: 'deleted.mp3',
        position: Duration(seconds: 40),
      ),
    );
    final music = MiniPhoneMusicService(
      progressStore: _store(),
      playerFactory: TestMusicPlayer.new,
    );
    addTearDown(music.dispose);
    await music.loadCatalog(() async => _catalog());
    expect(music.index, 0);
    expect(music.positionDuration, Duration.zero);
    expect(music.playing, isFalse);
  });
  test(
    'picker keeps playing; real background and manual pause do not resume',
    () async {
      final picker = SystemImagePickerActivity();
      final music = MiniPhoneMusicService(
        pickerActivity: picker,
        playerFactory: TestMusicPlayer.new,
      );
      addTearDown(() {
        music.dispose();
        picker.dispose();
      });
      await music.loadCatalog(() async => _catalog());
      await music.toggle();
      picker.debugSet(active: true);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        music.didChangeAppLifecycleState(state);
        expect(music.playing, isTrue);
      }
      picker.debugSet(active: true, backgrounded: true);
      await _flush();
      expect(music.playing, isFalse);
      music.didChangeAppLifecycleState(AppLifecycleState.resumed);
      picker.debugSet(active: false);
      expect(music.playRequested, isFalse);
      await music.toggle();
      picker.debugSet(active: true);
      await music.pause();
      picker.debugSet(active: false);
      music.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(music.playRequested, isFalse);
    },
  );
  test(
    'disposing a world session interrupts in-flight play and both decoders',
    () async {
      final player = TestMusicPlayer()..loadGate = Completer<void>();
      final music = MiniPhoneMusicService(playerFactory: () => player);
      final phone = MiniPhoneSession(worldId: 'a', music: music);
      await music.loadCatalog(() async => _catalog());
      final playing = music.toggle();
      await _flush();
      phone.dispose();
      await Future.wait([playing, music.released]);
      expect(phone.isDisposed, isTrue);
      expect(player.disposed, isTrue);
      expect(player.plays, 0);
    },
  );
  testWidgets('session disposal closes its tracked phone route', (
    tester,
  ) async {
    final phone = MiniPhoneSession(
      music: MiniPhoneMusicService(playerFactory: TestMusicPlayer.new),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => phone.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Phone route')),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Phone route'), findsOneWidget);
    phone.dispose();
    await tester.pumpAndSettle();
    expect(find.text('Phone route'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
  testWidgets(
    'removing the real World page stops a playing session and stores progress',
    (tester) async {
      final players = <TestMusicPlayer>[];
      final music = MiniPhoneMusicService(
        progressStore: _store(),
        playerFactory: () {
          final p = TestMusicPlayer();
          players.add(p);
          return p;
        },
      );
      final phone = MiniPhoneSession(worldId: 'a', music: music);
      final services = musicTestServices(GenesisApi(useMock: true));
      await music.loadCatalog(() async => _catalog());
      await music.toggle();
      await music.seekTo(const Duration(milliseconds: 4567));
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: WorldPage(wid: '', miniPhoneSession: phone),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Future.wait([music.released, music.progressSaved]);
      });
      expect(phone.isDisposed, isTrue);
      expect(players.every((p) => p.disposed && !p.playing), isTrue);
      expect(
        (await _store().read())!.position,
        const Duration(milliseconds: 4567),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
