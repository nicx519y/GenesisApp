import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/entry/mini_phone_entry_artwork.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_service.dart';
import 'package:genesis_flutter_android/pages/mini_phone/preview/mini_phone_demo_store.dart';

class _Unread extends MiniPhoneDemoStore {
  int count = 0;
  @override
  int get totalUnread => count;
  void arrive() {
    count++;
    notifyListeners();
  }
}

class _Music extends MiniPhoneMusicService {
  @override
  bool get playing => activated;
  @override
  bool get playRequested => activated;
  void play() {
    activated = true;
    notifyListeners();
  }
}

void main() {
  late MiniPhoneSession session;
  late MiniPhoneDockController controller;
  late MiniPhoneDockPosition position;
  late _Unread unread;
  late _Music music;
  final opened = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    unread = _Unread();
    music = _Music();
    session = MiniPhoneSession(store: unread, music: music);
    controller = MiniPhoneDockController();
    position = MiniPhoneDockPosition('persistent-dock-test');
    await position.load();
    await position.save(false, .65);
    opened.clear();
  });
  tearDown(() {
    controller.dispose();
    position.dispose();
    session.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? scene = 'map',
    bool visible = true,
    bool ready = true,
    double keyboard = 0,
    Offset transition = Offset.zero,
    bool includeOldScene = true,
    bool targetReady = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiniPhoneSessionScope(
          session: session,
          worldDetailReady: ready,
          child: MiniPhoneDockHost(
            controller: controller,
            selectedScene: scene,
            visible: visible,
            positionStore: position,
            child: Stack(
              children: [
                if (includeOldScene)
                  Positioned.fill(
                    child: MiniPhoneDockScene(
                      sceneId: 'map',
                      active: scene == 'map',
                      topInset: 40,
                      bottomInset: 130,
                      leftBottomInset: 80,
                      onPressed: (_) => opened.add('map'),
                    ),
                  ),
                if (targetReady && scene != null && scene != 'map')
                  Positioned.fill(
                    child: Transform.translate(
                      offset: transition,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 60,
                          bottom: 70 + keyboard,
                        ),
                        child: MiniPhoneDockScene(
                          key: ValueKey(scene),
                          sceneId: scene,
                          topInset: 4,
                          bottomInset: 8,
                          onPressed: (_) => opened.add(scene),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  testWidgets(
    'session replacement resets only the dock, preserving World content',
    (tester) async {
      await mount(tester);
      final host = tester.state(find.byType(MiniPhoneDockHost));
      final content = tester.state(find.byType(MiniPhoneDockScene));
      final dock = tester.state(find.byType(MiniPhoneEdgeDock));
      final entry = tester.state(find.byType(MiniPhoneEntry));
      final previous = session;
      session = MiniPhoneSession(store: _Unread(), music: _Music());
      previous.dispose();
      await mount(tester);
      expect(tester.state(find.byType(MiniPhoneDockHost)), same(host));
      expect(tester.state(find.byType(MiniPhoneDockScene)), same(content));
      expect(tester.state(find.byType(MiniPhoneEdgeDock)), isNot(same(dock)));
      expect(tester.state(find.byType(MiniPhoneEntry)), isNot(same(entry)));
      expect(
        tester.widget<MiniPhoneEntry>(find.byType(MiniPhoneEntry)).session,
        same(session),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one entry survives map, locations and hidden scenes', (
    tester,
  ) async {
    await mount(tester);
    final entry = tester.state(find.byType(MiniPhoneEntry));
    final dock = tester.state(find.byType(MiniPhoneEdgeDock));
    final origin = tester.getTopLeft(find.byType(MiniPhoneEntry));
    for (final scene in ['a', 'map', 'b']) {
      await mount(tester, scene: scene);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.state(find.byType(MiniPhoneEntry)), same(entry));
      expect(tester.state(find.byType(MiniPhoneEdgeDock)), same(dock));
      expect(tester.getTopLeft(find.byType(MiniPhoneEntry)), origin);
      await tester.tap(find.byType(MiniPhoneEntry));
      expect(opened.last, scene);
    }
    await mount(tester, scene: null);
    expect(find.byType(MiniPhoneEntry), findsNothing);
    expect(
      tester.state(find.byType(MiniPhoneEntry, skipOffstage: false)),
      same(entry),
    );
    await mount(tester, scene: 'b', visible: false);
    expect(find.byType(MiniPhoneEntry), findsNothing);
    await mount(tester, scene: 'b');
    expect(tester.state(find.byType(MiniPhoneEntry)), same(entry));
  });

  testWidgets(
    'transition keeps position and ignores clicks, then uses target callback',
    (tester) async {
      await mount(tester);
      final origin = tester.getTopLeft(find.byType(MiniPhoneEntry));
      controller.setTransitioning(true);
      await mount(tester, scene: 'a', transition: const Offset(200, 120));
      expect(tester.getTopLeft(find.byType(MiniPhoneEntry)), origin);
      await tester.tapAt(tester.getCenter(find.byType(MiniPhoneEntry)));
      expect(opened, isEmpty);
      controller.setTransitioning(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(find.byType(MiniPhoneEntry)), origin);
      await tester.tap(find.byType(MiniPhoneEntry));
      expect(opened, ['a']);
    },
  );

  testWidgets('keyboard avoidance preserves saved position and entry state', (
    tester,
  ) async {
    await mount(tester, scene: 'a');
    final entry = tester.state(find.byType(MiniPhoneEntry));
    final origin = tester.getTopLeft(find.byType(MiniPhoneEntry));
    await mount(tester, scene: 'a', keyboard: 220);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getBottomLeft(find.byType(MiniPhoneEntry)).dy,
      lessThanOrEqualTo(600 - 70 - 220 - 8),
    );
    expect(position.screenY, .65);
    await mount(tester, scene: 'a');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.byType(MiniPhoneEntry)), origin);
    expect(tester.state(find.byType(MiniPhoneEntry)), same(entry));
  });

  testWidgets('old scene disposal cannot unregister the current scene', (
    tester,
  ) async {
    await mount(tester);
    await mount(tester, scene: 'a');
    await mount(tester, scene: 'a', includeOldScene: false);
    await tester.tap(find.byType(MiniPhoneEntry));
    expect(opened, ['a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing target geometry keeps the icon but disables the old callback',
    (tester) async {
      await mount(tester);
      final state = tester.state(find.byType(MiniPhoneEntry));
      final offset = tester.getTopLeft(find.byType(MiniPhoneEntry));
      await mount(tester, scene: 'a', targetReady: false);
      expect(tester.state(find.byType(MiniPhoneEntry)), same(state));
      expect(tester.getTopLeft(find.byType(MiniPhoneEntry)), offset);
      await tester.tapAt(tester.getCenter(find.byType(MiniPhoneEntry)));
      expect(opened, isEmpty);
      await mount(tester, scene: 'a');
      await tester.tap(find.byType(MiniPhoneEntry));
      expect(opened, ['a']);
    },
  );

  testWidgets('a replacement World session releases the old entry', (
    tester,
  ) async {
    await mount(tester);
    final state = tester.state(find.byType(MiniPhoneEntry));
    final previousSession = session;
    final previousController = controller;
    session = MiniPhoneSession();
    controller = MiniPhoneDockController();
    await mount(tester);
    expect(state.mounted, isFalse);
    expect(tester.state(find.byType(MiniPhoneEntry)), isNot(same(state)));
    previousController.dispose();
    previousSession.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unread and music animation phases survive navigation and overlay hiding',
    (tester) async {
      await mount(tester);
      final entryState = tester.state(find.byType(MiniPhoneEntry));
      MiniPhoneEntryArtwork art() =>
          tester.widget(find.byType(MiniPhoneEntryArtwork));
      unread.arrive();
      music.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final arrival = art().arrivalProgress;
      final pulse = art().musicProgress;
      expect(arrival, greaterThan(0));
      expect(find.byTooltip('Pause music'), findsOneWidget);
      await mount(tester, scene: 'a');
      expect(art().arrivalProgress, closeTo(arrival, .001));
      expect(art().musicProgress, closeTo(pulse, .001));
      await mount(tester, scene: 'a', visible: false);
      expect(find.byTooltip('Pause music'), findsNothing);
      await mount(tester, scene: 'a');
      expect(tester.state(find.byType(MiniPhoneEntry)), same(entryState));
      expect(find.byTooltip('Pause music'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'drag persists across scenes and screen resize keeps one instance',
    (tester) async {
      await mount(tester);
      final entry = tester.state(find.byType(MiniPhoneEntry));
      await tester.drag(find.byType(MiniPhoneEntry), const Offset(600, -120));
      await tester.pumpAndSettle();
      final saved = position.screenY;
      expect(position.right, isTrue);
      await mount(tester, scene: 'a');
      await tester.pumpAndSettle();
      expect(position.screenY, saved);
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MiniPhoneEntry)), same(entry));
      expect(position.screenY, saved);
      expect(
        tester.getTopRight(find.byType(MiniPhoneEntry)).dx,
        closeTo(588, .1),
      );
    },
  );

  testWidgets('rapid reversal uses only the final scene and disposal is safe', (
    tester,
  ) async {
    await mount(tester);
    final entry = tester.state(find.byType(MiniPhoneEntry));
    controller.setTransitioning(true);
    await mount(tester, scene: 'a');
    await mount(tester, scene: 'b');
    await mount(tester, scene: 'map');
    controller.setTransitioning(false);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPhoneEntry));
    expect(opened, ['map']);
    expect(tester.state(find.byType(MiniPhoneEntry)), same(entry));
    controller.setTransitioning(true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial direct chat waits for detail and standalone scene keeps a dock',
    (tester) async {
      await mount(tester, scene: 'a', ready: false);
      expect(find.byType(MiniPhoneEntry), findsNothing);
      await mount(tester, scene: 'a');
      expect(find.byType(MiniPhoneEntry), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: MiniPhoneSessionScope(
            session: session,
            worldDetailReady: true,
            child: MiniPhoneDockScene(
              sceneId: 'standalone',
              topInset: 4,
              bottomInset: 8,
              onPressed: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MiniPhoneEdgeDock), findsOneWidget);
      expect(find.byType(MiniPhoneEntry), findsOneWidget);
    },
  );
}
