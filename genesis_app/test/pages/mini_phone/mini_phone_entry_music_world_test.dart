import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/entry/mini_phone_entry_artwork.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_progress.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';
import 'package:genesis_flutter_android/pages/mini_phone/preview/mini_phone_demo_store.dart';

import '../../support/mini_phone_audio_player.dart';

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

class _NoUnread extends MiniPhoneDemoStore {
  int count = 0;
  @override
  int get totalUnread => count;

  void update(int value) {
    count = value;
    notifyListeners();
  }
}

class _DelayedProgress implements MiniPhoneMusicProgressStore {
  final restored = Completer<MiniPhoneMusicProgress?>();
  @override
  Future<MiniPhoneMusicProgress?> read() => restored.future;
  @override
  Future<void> write(MiniPhoneMusicProgress progress) async {}
}

Future<void> _mount(
  WidgetTester tester,
  MiniPhoneSession session,
  MiniPhoneEntryStyle style,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: MiniPhoneEntry(
            session: session,
            style: style,
            onPressed: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectIdle(WidgetTester tester) {
  expect(find.byType(MiniPhoneEntryBubble), findsNothing);
  expect(
    tester
        .widget<MiniPhoneEntryArtwork>(find.byType(MiniPhoneEntryArtwork))
        .showMusic,
    isFalse,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final style in MiniPhoneEntryStyle.values) {
    testWidgets('${style.name} resets entry on new and repeated World entry', (
      tester,
    ) async {
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
      addTearDown(owner.dispose);
      addTearDown(revision.dispose);
      final first = MiniPhoneSession(
        worldId: 'a',
        store: _NoUnread(),
        musicLease: owner.acquire('a'),
      );
      await first.music.loadCatalog(() async => _catalog);
      await first.music.next();
      await first.music.seekTo(const Duration(seconds: 12));
      await first.music.pause();
      await _mount(tester, first, style);
      expect(find.byTooltip('Play music'), findsOneWidget);
      final loads = players.map((p) => p.loads).toList();
      final music = first.music;
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      await music.progressSaved;

      for (final world in ['b', 'b']) {
        final unread = _NoUnread();
        final phone = MiniPhoneSession(
          worldId: world,
          store: unread,
          musicLease: owner.acquire(world),
        );
        await _mount(tester, phone, style);
        _expectIdle(tester);
        expect(phone.music, same(music));
        expect(music.activated, isTrue);
        expect(music.track!.file, 'b.mp3');
        expect(music.positionDuration, const Duration(seconds: 12));
        expect(music.playRequested, isFalse);
        expect(players.every((p) => !p.disposed), isTrue);
        unread.update(1);
        await tester.pump();
        final arrival = tester.widget<MiniPhoneEntryBubble>(
          find.byType(MiniPhoneEntryBubble),
        );
        expect(arrival.avatar, isNotNull);
        expect(arrival.onTap, isNull);
        await tester.pump(const Duration(seconds: 3));
        unread.update(0);
        await tester.pump();
        _expectIdle(tester);
        await music.toggle();
        await tester.pump();
        expect(find.byTooltip('Pause music'), findsOneWidget);
        expect(players.map((p) => p.loads).toList(), loads);
        await music.pause();
        await tester.pump();
        expect(find.byTooltip('Play music'), findsOneWidget);
        // Recreating the icon inside the same World keeps its music controls.
        await tester.pumpWidget(const SizedBox.shrink());
        await _mount(tester, phone, style);
        expect(find.byTooltip('Play music'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        phone.dispose();
        await music.progressSaved;
      }
      final saved = await LocalMiniPhoneMusicProgressStore(
        namespace: 'prod',
        owner: Future.value('u'),
      ).read();
      expect(saved!.file, 'b.mp3');
      expect(saved.position, const Duration(seconds: 12));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('late history restoration keeps a fresh World entry idle', (
    tester,
  ) async {
    final progress = _DelayedProgress();
    final music = MiniPhoneMusicService(
      progressStore: progress,
      playerFactory: TestMusicPlayer.new,
    );
    music.attachWorld();
    final phone = MiniPhoneSession(music: music, store: _NoUnread());
    addTearDown(phone.dispose);
    await _mount(tester, phone, MiniPhoneEntryStyle.classicHandset);
    _expectIdle(tester);
    progress.restored.complete(
      const MiniPhoneMusicProgress(
        file: 'b.mp3',
        position: Duration(seconds: 12),
      ),
    );
    await music.loadCatalog(() async => _catalog);
    await tester.pump();
    _expectIdle(tester);
    expect(music.activated, isTrue);
    expect(music.track!.file, 'b.mp3');
    expect(music.positionDuration, const Duration(seconds: 12));
    await music.previous();
    await tester.pump();
    expect(find.byTooltip('Pause music'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    phone.dispose();
  });
}
