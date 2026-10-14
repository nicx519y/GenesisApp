import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_demo_store.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/ui/animations/app_launch_transition/app_launch_transition.dart';
import '../../support/mini_phone_music_services.dart';
import '../../support/mini_phone_audio_player.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_music_service.dart';

class _TransitionTransport implements HttpTransport {
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    if (request.uri.path.endsWith('/music/like_status')) {
      return TransportResponse(
        statusCode: 200,
        headers: const {},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'file': request.uri.queryParameters['file'],
            'is_liked': false,
          },
        }),
      );
    }
    return LocalMockGenesisTransport.instance.send(request);
  }
}

void main() {
  late MiniPhoneSession phone;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    phone = MiniPhoneSession(
      music: MiniPhoneMusicService(playerFactory: TestMusicPlayer.new),
    );
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    phone.dispose();
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  Finder source(Object id) => find.byWidgetPredicate(
    (widget) => widget is AppLaunchSource && widget.id == id,
  );
  AppLaunchTransitionController controller(WidgetTester tester) => tester
      .widget<AppLaunchTransitionHost>(find.byType(AppLaunchTransitionHost))
      .controller;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
  }

  Future<void> mount(
    WidgetTester tester, {
    bool music = false,
    bool nested = false,
  }) async {
    phone.dispose();
    phone = MiniPhoneSession(
      music: MiniPhoneMusicService(playerFactory: TestMusicPlayer.new),
    );
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (music) {
      await phone.music.loadCatalog(
        () async => const MusicCatalog(
          preUrl: 'https://cdn.example/',
          tracks: [
            MusicTrack(
              file: 'launch-test.mp3',
              audioUrl: 'https://cdn.example/launch-test.mp3',
              sourceWorldoId: 'test',
              sourceWorldoName: 'Test',
              artist: 'Artist',
              title: 'Launch test',
              coverUrl: 'assets/mini_phone/loc_1_1_1.jpg',
            ),
          ],
        ),
      );
      phone.music.activated = true;
    }
    final api = GenesisApi(
      useMock: false,
      apiClient: ApiClient(
        baseUrl: 'https://api.example/api/',
        transport: _TransitionTransport(),
        defaultHeaders: {'Authorization': 'Bearer launch-test'},
      ),
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: musicTestServices(api),
        child: MaterialApp(
          home: nested
              ? Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MiniPhonePage(session: phone),
                      ),
                    ),
                    child: const Text('Open phone'),
                  ),
                )
              : MiniPhonePage(session: phone),
        ),
      ),
    );
    if (nested) {
      await tester.tap(find.text('Open phone'));
    }
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Home position 1'));
    await settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets(
    'all dock apps expand from their icon and retain the home instance',
    (tester) async {
      await mount(tester);
      final homeElement = tester.element(find.byType(PageView));
      for (final app in [
        MiniPhoneScreen.messages,
        MiniPhoneScreen.posts,
        MiniPhoneScreen.photos,
        MiniPhoneScreen.settings,
      ]) {
        final before = tester.getRect(source(app));
        await tester.tap(source(app));
        await tester.pump();
        final flight = tester.getRect(
          find.byKey(const ValueKey('app-launch-surface')),
        );
        expect(flight, before);
        expect(controller(tester).status, AppLaunchTransitionStatus.opening);
        await settle(tester);
        expect(controller(tester).status, AppLaunchTransitionStatus.open);
        await back(tester);
        expect(controller(tester).status, AppLaunchTransitionStatus.home);
        expect(tester.element(find.byType(PageView)), same(homeElement));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'music icon preserves second page and music card keeps controls separate',
    (tester) async {
      await mount(tester, music: true);
      final slider = find.descendant(
        of: source('home-music-card'),
        matching: find.byType(Slider),
      );
      await tester.tap(slider);
      await tester.pump();
      expect(controller(tester).status, AppLaunchTransitionStatus.home);
      await tester.tap(find.bySemanticsLabel(RegExp('Open Music:')));
      await settle(tester);
      expect(controller(tester).status, AppLaunchTransitionStatus.open);
      await back(tester);
      expect(source('home-music-card'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Home position 2'));
      await settle(tester);
      expect(source(MiniPhoneScreen.music).hitTestable(), findsOneWidget);
      await tester.tap(source(MiniPhoneScreen.music));
      await settle(tester);
      await back(tester);
      expect(source(MiniPhoneScreen.music).hitTestable(), findsOneWidget);
      final pager = tester.widget<PageView>(find.byType(PageView));
      expect(pager.controller!.page, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'notification read happens once, back keeps hierarchy and falls back to dock',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Show all').first);
      await settle(tester);
      final person = miniDemoPeople.first;
      final notification = source(('message', person.id, 0));
      await tester.ensureVisible(notification);
      await settle(tester);
      var readNotifications = 0;
      void changed() => readNotifications++;
      phone.store.addListener(changed);
      addTearDown(() => phone.store.removeListener(changed));
      await tester.tap(notification);
      await tester.pump();
      expect(controller(tester).status, AppLaunchTransitionStatus.opening);
      expect(phone.store.unread(person), 0);
      expect(readNotifications, 1);
      await settle(tester);
      await back(tester);
      expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
      expect(controller(tester).status, AppLaunchTransitionStatus.open);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(microseconds: 279900));
      final flight = tester.getRect(
        find.byKey(const ValueKey('app-launch-surface')),
      );
      final homeIcon = find.byWidgetPredicate(
        (w) => w is AppLaunchSource && w.id == MiniPhoneScreen.messages,
        skipOffstage: false,
      );
      expect(
        (flight.center - tester.getCenter(homeIcon)).distance,
        lessThan(4),
      );
      await settle(tester);
      expect(controller(tester).status, AppLaunchTransitionStatus.home);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('back during opening reverses', (tester) async {
    await mount(tester);
    await tester.tap(source(MiniPhoneScreen.photos));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await back(tester);
    expect(controller(tester).status, AppLaunchTransitionStatus.home);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'post notification expands to comments and returns through Posts',
    (tester) async {
      await mount(tester);
      final post = phone.store.unreadPosts.first;
      await tester.tap(find.text('Show all').first);
      await settle(tester);
      final notification = source(('post', post.id));
      await tester.ensureVisible(notification);
      await settle(tester);
      final origin = tester.getRect(notification);
      await tester.tap(notification);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('app-launch-surface'))),
        origin,
      );
      expect(phone.store.readPosts, contains(post.id));
      await settle(tester);
      await back(tester);
      expect(find.widgetWithText(TextButton, 'Posts'), findsOneWidget);
      expect(controller(tester).status, AppLaunchTransitionStatus.open);
      await back(tester);
      expect(controller(tester).status, AppLaunchTransitionStatus.home);
      expect(phone.store.unreadPosts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('fixed close button exits the outer route during a transition', (
    tester,
  ) async {
    await mount(tester, nested: true);
    await tester.tap(source(MiniPhoneScreen.photos));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
