import 'package:genesis_flutter_android/network/models/world.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/entry/mini_phone_entry_artwork.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';
import 'package:genesis_flutter_android/pages/mini_phone/preview/mini_phone_demo_store.dart';
import 'package:genesis_flutter_android/pages/mini_phone/preview/mini_phone_preview_avatar.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_ui.dart';

class _Unread extends MiniPhoneDemoStore {
  int count = 0;
  @override
  int get totalUnread => count;
  void update(int value) {
    count = value;
    notifyListeners();
  }
}

class _Music extends MiniPhoneMusicService {
  bool activePlayback = false;
  int toggles = 0;
  @override
  bool get playing => activePlayback;
  @override
  bool get playRequested => activePlayback;
  @override
  Future<void> toggle() async {
    toggles++;
    activated = true;
    activePlayback = !activePlayback;
    notifyListeners();
  }
}

void main() {
  final boundary = GlobalKey();
  late _Unread unread;
  late _Music music;
  late MiniPhoneSession session;
  var opens = 0;

  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    unread = _Unread();
    music = _Music();
    session = MiniPhoneSession(store: unread, music: music);
    opens = 0;
  });
  tearDown(() => session.dispose());

  Future<void> mount(
    WidgetTester tester, {
    MiniPhoneEntryStyle? style = MiniPhoneEntryStyle.arcaneGrimoire,
    WorldMapStyle? mapStyle,
    bool worldDetailReady = true,
    bool reducedMotion = false,
    bool dock = false,
    double bottomInset = 20,
    double? leftBottomInset,
  }) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF1F1D24),
          body: MiniPhoneSessionScope(
            session: session,
            worldDetailReady: worldDetailReady,
            mapStyle: mapStyle,
            child: dock
                ? MiniPhoneEdgeDock(
                    style: style,
                    positionStore: MiniPhoneDockPosition('entry-style-test'),
                    topInset: 0,
                    bottomInset: bottomInset,
                    leftBottomInset: leftBottomInset,
                    onPressed: (phone) {
                      expect(identical(phone, session), isTrue);
                      opens++;
                    },
                  )
                : Center(
                    child: MiniPhoneEntry(
                      session: session,
                      style: style,
                      onPressed: () => opens++,
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['MINIPHONE_ENTRY_CAPTURE_DIR'];
    if (dir == null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final box =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await box.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  MiniPhoneEntryArtwork art(WidgetTester tester) =>
      tester.widget(find.byType(MiniPhoneEntryArtwork));
  Finder note() => find.byWidgetPredicate(
    (w) => w is MiniIcon && w.name == 'music-musical-note',
  );

  for (final style in MiniPhoneEntryStyle.values) {
    testWidgets('${style.name} arrival restarts, settles unread, then clears', (
      tester,
    ) async {
      await mount(tester, style: style);
      expect(
        find.text('18:05'),
        style == MiniPhoneEntryStyle.classicHandset
            ? findsOneWidget
            : findsNothing,
      );
      expect(art(tester).unread, isFalse);
      await capture(tester, '${style.name}-idle');
      unread.update(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 405));
      expect(art(tester).arrivalProgress, closeTo(.135, .001));
      expect(art(tester).unread, isTrue);
      await capture(tester, '${style.name}-arrival');
      unread.update(128);
      await tester.pump();
      expect(art(tester).arrivalProgress, 0);
      expect(find.text('128'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3001));
      expect(art(tester).arriving, isFalse);
      expect(art(tester).unread, isTrue);
      await capture(tester, '${style.name}-unread');
      unread.update(0);
      await tester.pump();
      expect(art(tester).unread, isFalse);
      expect(find.text('128'), findsNothing);
      await tester.tap(find.byType(MiniPhoneEntry));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${style.name} music controls work with unread priority and expanded hit area',
      (tester) async {
        await mount(tester, style: style);
        await music.toggle();
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(note(), findsOneWidget);
        expect(art(tester).showMusic, isTrue);
        await capture(tester, '${style.name}-playing');
        final entry = tester.getTopLeft(find.byType(MiniPhoneEntry));
        // Outside the 26px circle, inside the 44px interactive region.
        await tester.tapAt(entry + const Offset(-3, -40));
        await tester.pump();
        expect(music.toggles, 2);
        expect(music.playing, isFalse);
        expect(find.byTooltip('Play music'), findsOneWidget);
        await capture(tester, '${style.name}-paused');
        unread.update(2);
        await tester.pump();
        expect(note(), findsNothing);
        expect(art(tester).unread, isTrue);
        expect(art(tester).showMusic, isFalse);
        await tester.pump(const Duration(milliseconds: 3001));
        expect(find.byType(MiniAvatar), findsNothing);
        await capture(tester, '${style.name}-unread-music');
        await tester.tap(find.byTooltip('Play music'));
        await tester.pump();
        expect(music.toggles, 3);
        expect(music.playing, isTrue);
        expect(opens, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${style.name} reduced motion skips arrival and dock keeps style after dragging',
      (tester) async {
        unread.update(3);
        await mount(tester, style: style, reducedMotion: true, dock: true);
        expect(art(tester).arriving, isFalse);
        final entry = find.byType(MiniPhoneEntry);
        final before = tester.getCenter(entry);
        await tester.drag(entry, const Offset(-500, -200));
        await tester.pump();
        expect(tester.getCenter(entry).dx, lessThan(before.dx));
        expect(tester.widget<MiniPhoneEntry>(entry).style, style);
        await tester.tap(entry);
        expect(opens, 1);
        unread.update(4);
        await tester.pump();
        expect(art(tester).arriving, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'dock crosses both halves without jumping and avoids zoom controls on release',
    (tester) async {
      await mount(tester, dock: true, bottomInset: 110, leftBottomInset: 8);
      await tester.pump(const Duration(milliseconds: 200));
      final entry = find.byType(MiniPhoneEntry);
      final initialTop = tester.getTopLeft(entry).dy;
      final gesture = await tester.startGesture(tester.getCenter(entry));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 102));
      await tester.pump();
      final draggingTop = tester.getTopLeft(entry).dy;
      expect(draggingTop, closeTo(initialTop + 102, .01));

      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();
      expect(tester.getCenter(entry).dx, lessThan(160));
      expect(tester.getTopLeft(entry).dy, closeTo(draggingTop, .01));
      await gesture.moveBy(const Offset(160, 0));
      await tester.pump();
      expect(tester.getCenter(entry).dx, greaterThan(160));
      expect(tester.getTopLeft(entry).dy, closeTo(draggingTop, .01));

      await gesture.up();
      await tester.pump();
      expect(tester.getTopLeft(entry).dy, closeTo(draggingTop, .01));
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getTopLeft(entry).dy, greaterThan(initialTop));
      expect(tester.getTopLeft(entry).dy, lessThan(draggingTop));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(entry).dx, closeTo(320 - 12 - 34, .01));
      expect(tester.getTopLeft(entry).dy, closeTo(initialTop, .01));
      expect(opens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dock waits for World detail before mounting icon and music controls',
    (tester) async {
      await music.toggle();
      unread.update(3);
      await mount(
        tester,
        style: null,
        dock: true,
        worldDetailReady: false,
        reducedMotion: true,
      );
      expect(find.byType(MiniPhoneEntry), findsNothing);
      expect(find.byType(MiniPhoneEntryArtwork), findsNothing);
      expect(find.byType(MiniPhoneEntryBubble), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MiniPhoneEntryArtwork), findsNothing);
      await mount(
        tester,
        style: null,
        dock: true,
        worldDetailReady: true,
        mapStyle: const WorldMapStyle(era: 'medieval_fantasy'),
        reducedMotion: true,
      );
      expect(art(tester).skin, same(MiniPhoneEntryStyle.arcaneGrimoire.skin));
      expect(find.byType(MiniPhoneEntryBubble), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loaded World with null map style shows Classic after waiting', (
    tester,
  ) async {
    await mount(tester, style: null, dock: true, worldDetailReady: false);
    expect(find.byType(MiniPhoneEntryArtwork), findsNothing);
    await mount(tester, style: null, dock: true, worldDetailReady: true);
    expect(art(tester).skin, same(MiniPhoneEntryStyle.classicHandset.skin));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'world scope era updates the dock without replacing the session',
    (tester) async {
      const expected = {
        'modern': MiniPhoneEntryStyle.classicHandset,
        'near_future': MiniPhoneEntryStyle.classicHandset,
        'cyberpunk': MiniPhoneEntryStyle.classicHandset,
        'space_scifi': MiniPhoneEntryStyle.classicHandset,
        'post_apocalyptic': MiniPhoneEntryStyle.classicHandset,
        'mythic_ancient': MiniPhoneEntryStyle.arcaneGrimoire,
        'historical_east': MiniPhoneEntryStyle.arcaneGrimoire,
        'medieval_fantasy': MiniPhoneEntryStyle.arcaneGrimoire,
        'victorian': MiniPhoneEntryStyle.arcaneGrimoire,
        'steampunk': MiniPhoneEntryStyle.arcaneGrimoire,
        'new_unknown_era': MiniPhoneEntryStyle.classicHandset,
        '': MiniPhoneEntryStyle.classicHandset,
      };
      unread.update(4);
      await mount(tester, style: null, reducedMotion: true, dock: true);
      final entryState = tester.state(find.byType(MiniPhoneEntry));
      expect(art(tester).skin, same(MiniPhoneEntryStyle.classicHandset.skin));
      for (final item in expected.entries) {
        await mount(
          tester,
          style: null,
          mapStyle: WorldMapStyle(era: item.key),
          reducedMotion: true,
          dock: true,
        );
        expect(art(tester).skin, same(item.value.skin), reason: item.key);
        expect(tester.state(find.byType(MiniPhoneEntry)), same(entryState));
        expect(find.text('4'), findsOneWidget);
      }
      await mount(
        tester,
        style: null,
        mapStyle: const WorldMapStyle(era: 'medieval_fantasy'),
        reducedMotion: true,
        dock: true,
      );
      await mount(tester, style: null, reducedMotion: true, dock: true);
      expect(art(tester).skin, same(MiniPhoneEntryStyle.classicHandset.skin));
      await mount(
        tester,
        style: MiniPhoneEntryStyle.classicHandset,
        mapStyle: const WorldMapStyle(era: 'medieval_fantasy'),
        reducedMotion: true,
        dock: true,
      );
      expect(art(tester).skin, same(MiniPhoneEntryStyle.classicHandset.skin));
      await tester.tap(find.byType(MiniPhoneEntry));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'classic remains default and style can change without losing unread',
    (tester) async {
      expect(MiniPhoneEntry(onPressed: () {}).style, isNull);
      expect(
        MiniPhoneEdgeDock(topInset: 0, bottomInset: 0, onPressed: (_) {}).style,
        isNull,
      );
      unread.update(3);
      await mount(tester, style: null, reducedMotion: true);
      expect(find.text('18:05'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(MiniPhoneEntryArtwork), findsOneWidget);
      await capture(tester, 'classic-unread');
      await mount(tester, reducedMotion: true);
      expect(art(tester).unread, isTrue);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('18:05'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
