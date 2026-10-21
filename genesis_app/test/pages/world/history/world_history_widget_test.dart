import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/components/common/page_presentation_scope.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_controller.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import '../../../support/mini_phone_music_services.dart';
import 'history_fixtures.dart';

class Backend implements HttpTransport {
  final requests = <TransportRequest>[];
  List<Map<String, dynamic>> rows = [historyJson('1')];
  bool fail = false, more = false;
  Completer<void>? pending;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final snapshot = rows, failed = fail, hasMore = more;
    await pending?.future;
    return TransportResponse(
      statusCode: 200,
      headers: const {},
      body: jsonEncode({
        'err_no': failed ? 4011 : 0,
        'err_msg': 'History permission denied',
        'data': {
          'world_id': request.uri.queryParameters['world_id'],
          'messages': snapshot,
          'has_more': hasMore,
          'cursor': hasMore ? 'opaque+/=cursor' : '',
        },
      }),
    );
  }
}

class Harness {
  Harness(this.backend) {
    final client = ApiClient(
      baseUrl: 'https://history.invalid/',
      transport: backend,
    );
    services = musicTestServices(
      GenesisApi(useMock: false, apiClient: client, chatroomHttpClient: client),
    );
  }
  final Backend backend;
  late final AppServices services;
  var scroll = ScrollController();
  final cache = WorldHistoryViewCache();
  final presentation = PagePresentationController();
  final navigator = GlobalKey<NavigatorState>();
  Widget build(
    WorldDetail world, {
    bool active = true,
    String uid = 'me',
    bool shown = true,
  }) => AppServicesScope(
    services: services,
    child: MaterialApp(
      navigatorKey: navigator,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PagePresentationScope(
          controller: presentation,
          child: !shown
              ? const SizedBox.expand()
              : WorldChatHistorySection(
                  cache: cache,
                  world: world,
                  currentUid: uid,
                  active: active,
                  scrollController: scroll,
                  onBackgroundChanged: (_) {},
                  onLocationTap: (_) {},
                ),
        ),
      ),
    ),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    scroll.dispose();
    cache.dispose();
    presentation.dispose();
  }
}

Future<void> frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('History uses the LocationChat Enter bubble inside its fold', (
    tester,
  ) async {
    final backend = Backend()
      ..rows = [
        historyJson('enter', type: 'user', content: 'Role entered Place A'),
        historyJson('speech', type: 'user', content: 'An ordinary message'),
      ];
    final h = Harness(backend);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    expect(find.byType(ChatUserEnterLocationMessageBubble), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-user-enter-location-icon')),
      findsOneWidget,
    );
    expect(
      find.text('Role came to Place A', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(ChatOtherMessageBubble), findsOneWidget);
    await tester.tap(find.text('Collapse').first);
    await frames(tester);
    expect(find.byType(ChatUserEnterLocationMessageBubble), findsNothing);
    await tester.tap(find.text('Expand').first);
    await frames(tester);
    expect(find.byType(ChatUserEnterLocationMessageBubble), findsOneWidget);
    expect(backend.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets(
    'fold grouping and offscreen geometry leave Tick bodies deferred',
    (tester) async {
      final backend = Backend()
        ..rows = [
          historyJson('user', type: 'user'),
          for (var i = 0; i < 100; i++)
            historyJson(
              'tick-$i',
              type: 'tick',
              content: 'Long historical Tick $i',
            ),
        ];
      final h = Harness(backend);
      await tester.pumpWidget(h.build(historyWorld()));
      await tester.pumpAndSettle();
      final parsed = h.cache.projection.parsedTickCount;
      expect(parsed, greaterThan(0));
      expect(parsed, lessThan(100));
      final builds = h.cache.controller!.residentIndexBuilds;
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();
      expect(h.cache.controller!.residentIndexBuilds, builds);
      expect(backend.requests.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await h.close(tester);
    },
  );

  testWidgets(
    'changed cursor restores a nearby row without walking the new chain',
    (tester) async {
      final h = Harness(Backend());
      h.cache.bind(h.services, 'w', 'me');
      h.cache.appVersion = 999;
      var mutated = false;
      final calls = <String?>[];
      final c = WorldHistoryController(
        worldId: 'w',
        maxMessages: 6,
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              calls.add(cursor);
              if (mutated) {
                return WorldHistoryPage(
                  worldId: 'w',
                  messages: [
                    historyMessage(
                      'replacement',
                      content: 'Nearby replacement',
                    ),
                  ],
                  cursor: 'new-chain',
                  hasMore: true,
                );
              }
              final i = int.parse(cursor ?? '0');
              return historyPage(['$i-a', '$i-b'], cursor: '${i + 1}');
            },
      );
      c.setActive(true);
      await c.refresh();
      for (var i = 1; i <= 8; i++) {
        await c.loadOlder();
        c.updateReading(messageId: '$i-a');
      }
      h.cache.controller = c;
      h.cache.started = true;
      h.cache.snapshot = c.snapshot;
      await tester.pumpWidget(h.build(historyWorld()));
      await tester.pumpAndSettle();
      expect(h.cache.readingId, isNotNull);
      final before = calls.length;
      mutated = true;
      await c.loadNewer();
      await tester.pumpAndSettle();
      await frames(tester);
      expect(c.failed, isFalse);
      expect(find.text('Nearby replacement'), findsWidgets);
      expect(h.cache.readingId, contains('replacement'));
      expect(c.awaitingUserContinuation, isTrue);
      expect(calls.length, before + 1);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 120),
      );
      expect(c.awaitingUserContinuation, isFalse);
      await h.close(tester);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GenesisMethodChannels.device,
          (call) async => call.method == GenesisMethodChannels.getAppVersion
              ? {'versionName': '9.9.9', 'versionCode': 999}
              : null,
        );
  });
  for (final rowCount in [1, 35]) {
    testWidgets(
      'History reveals the complete tail at a stable position ($rowCount rows)',
      (tester) async {
        tester.view.physicalSize =
            const Size(390, 700) * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
        final b = Backend()
          ..pending = Completer<void>()
          ..rows = List.generate(
            rowCount,
            (i) => historyJson(
              '$i',
              content: i == 0
                  ? 'Newest archive message. ' * (rowCount == 1 ? 1 : 45)
                  : 'Older message $i. ' * (i % 5 + 1),
            ),
          );
        final h = Harness(b);
        await tester.pumpWidget(h.build(historyWorld()));
        await frames(tester, 3);
        b.pending!.complete();
        b.pending = null;
        final skeleton = find.byKey(
          const ValueKey('world-history-loading-skeleton'),
        );
        final footer = find.byKey(const ValueKey('world-history-continue-A'));
        bool preparedWithList = false;
        int visibleFrames = 0;
        Rect? firstFooter;
        double? firstPixels;
        for (var frame = 0; frame < 50 && visibleFrames < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (find.byType(LocationChatAnchoredMessageList).evaluate().isEmpty) {
            continue;
          }
          if (skeleton.evaluate().isNotEmpty) {
            preparedWithList = true;
            expect(visibleFrames, 0);
            continue;
          }
          expect(footer, findsOneWidget);
          final bounds = tester.getRect(footer);
          expect(bounds.bottom, lessThanOrEqualTo(700));
          expect(bounds.bottom, greaterThan(0));
          expect(
            h.scroll.offset,
            closeTo(h.scroll.position.maxScrollExtent, 1),
          );
          firstFooter ??= bounds;
          firstPixels ??= h.scroll.offset;
          expect(bounds.top, closeTo(firstFooter.top, 0.5));
          expect(h.scroll.offset, closeTo(firstPixels, 0.5));
          visibleFrames++;
        }
        expect(preparedWithList, isTrue);
        expect(visibleFrames, 12);
        expect(b.requests, hasLength(1));
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }
  testWidgets(
    'shared Ticks render and collapse with their participating location',
    (tester) async {
      final b = Backend()
        ..rows = [
          historyJson('user', type: 'user'),
          historyJson(
            'tick-1',
            type: 'tick',
            tick: 2,
            locations: ['B', 'A'],
            content: tickContent(),
          ),
          historyJson(
            'tick-2',
            type: 'tick',
            tick: 3,
            locations: ['B', 'A'],
            content: tickContent(),
          ),
          historyJson('reply'),
        ];
      final h = Harness(b);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      LocationChatAnchoredMessageList list() =>
          tester.widget<LocationChatAnchoredMessageList>(
            find.byType(LocationChatAnchoredMessageList),
          );
      expect(list().messages.where((m) => m.isTick), hasLength(2));
      expect(list().expandedHistoryHeaders.values.toSet(), hasLength(1));
      expect(find.text('Tick 3', findRichText: true), findsWidgets);
      await tester.tap(find.text('Collapse').first);
      await frames(tester);
      expect(list().hiddenMessageIds, hasLength(3));
      expect(find.text('Tick 3', findRichText: true), findsNothing);
      await tester.tap(find.text('Expand').first);
      await frames(tester);
      expect(list().hiddenMessageIds, isEmpty);
      expect(find.text('Tick 3', findRichText: true), findsWidgets);
      expect(b.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await h.close(tester);
    },
  );

  testWidgets('Tick-only separator does not merge independent fold sections', (
    tester,
  ) async {
    final b = Backend()
      ..rows = [
        historyJson('later-character'),
        historyJson('later-tick', type: 'tick'),
        historyJson('separator', type: 'tick', locations: ['B']),
        historyJson('earlier-tick', type: 'tick'),
        historyJson('user', type: 'user'),
      ];
    final h = Harness(b);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    expect(list.messages.where((m) => m.isTick), hasLength(1));
    expect(list.expandedHistoryHeaders.values.toSet(), hasLength(2));
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  for (final hidden in [false, true]) {
    testWidgets('History renders server main, sub and zero Tick labels', (
      tester,
    ) async {
      final b = Backend()
        ..rows = [
          historyJson(
            'sub',
            type: 'tick',
            tick: 7,
            subTick: 3,
            content: tickContent(),
          ),
          historyJson('main', type: 'tick', tick: 7, content: tickContent()),
          historyJson('zero', type: 'tick', content: 'Legacy Tick body'),
          historyJson('user', type: 'user', content: 'User participates'),
        ];
      final h = Harness(b);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      expect(find.text('Tick 7-3', findRichText: true), findsWidgets);
      expect(find.text('Tick 7', findRichText: true), findsWidgets);
      expect(find.textContaining('Tick 0', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });

    testWidgets(
      'bottom button restores cached first page with no HTTP (hidden: $hidden)',
      (tester) async {
        final h = Harness(Backend());
        final world = historyWorld();
        h.cache.bind(h.services, 'w', 'me');
        var calls = 0;
        final c = WorldHistoryController(
          worldId: 'w',
          maxMessages: 2,
          appVersion: 999,
          fetch:
              ({
                required worldId,
                cursor,
                limit = 20,
                cancellationToken,
              }) async {
                calls++;
                final page = cursor == null ? 0 : int.parse(cursor);
                return WorldHistoryPage(
                  worldId: 'w',
                  hasMore: true,
                  cursor: '${page + 1}',
                  messages: [
                    historyMessage(
                      'page-$page',
                      type: hidden && page > 0 ? 'tick' : 'user',
                      locations: [page == 0 ? 'A' : 'B'],
                    ),
                  ],
                );
              },
        );
        h.cache.controller = c;
        h.cache.started = true;
        c.setActive(true);
        await c.refresh();
        for (var page = 1; page <= 5; page++) {
          await c.loadOlder();
          c.updateReading(messageId: 'page-$page');
        }
        expect(c.pages.first.messages, isNull);
        await tester.pumpWidget(h.build(world));
        await frames(tester);
        if (hidden) expect(h.cache.projection.rows, isEmpty);
        final before = calls;
        final button = find.byKey(
          const ValueKey('world-history-return-to-bottom'),
        );
        expect(button, findsOneWidget);
        await tester.tap(button);
        await frames(tester);
        expect(calls, before);
        expect(c.newestFirst.single.id, 'page-0');
        expect(c.hasNewer, isFalse);
        expect(button, findsNothing);
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }

  testWidgets(
    'first load uses a static skeleton, then cached reading resumes across sheets',
    (tester) async {
      final b = Backend()
        ..pending = Completer<void>()
        ..rows = List.generate(
          50,
          (i) => historyJson('$i', content: 'Archive row $i', version: 1),
        );
      final h = Harness(b);
      final world = historyWorld();
      await tester.pumpWidget(h.build(world));
      await frames(tester, 3);
      expect(
        find.byKey(const ValueKey('world-history-loading-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      b.pending!.complete();
      b.pending = null;
      await frames(tester);
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      list.coordinator.beginHistoryNavigation();
      h.scroll.jumpTo(h.scroll.position.maxScrollExtent / 2);
      await frames(tester);
      final anchor = h.cache.viewport.anchor!;
      final before = h.scroll.offset;
      final projection = h.cache.projection;
      final sheetScroll = h.scroll;
      h.scroll = ScrollController();
      final previewScroll = h.scroll;
      await tester.pumpWidget(h.build(world, active: false));
      await frames(tester);
      h.scroll = sheetScroll;
      await tester.pumpWidget(h.build(world));
      expect(h.scroll.offset, closeTo(before, 1));
      await frames(tester);
      previewScroll.dispose();
      expect(h.scroll.offset, closeTo(before, 1));
      expect(b.requests.length, 1);
      // Closing the modal removes the whole view and its controller.
      await tester.pumpWidget(h.build(world, shown: false));
      await frames(tester);
      h.scroll.dispose();
      h.scroll = ScrollController();
      await tester.pumpWidget(h.build(world));
      // Restoration happens underneath the placeholder. Every exposed frame
      // must retain the saved reading coordinate, not just the settled result.
      expect(h.scroll.offset, closeTo(before, 1));
      var restoredVisibleFrames = 0;
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find
            .byKey(const ValueKey('world-history-loading-skeleton'))
            .evaluate()
            .isEmpty) {
          restoredVisibleFrames++;
          expect(h.scroll.offset, closeTo(before, 1));
        }
      }
      expect(restoredVisibleFrames, greaterThan(5));
      expect(b.requests.length, 1);
      expect(identical(h.cache.projection, projection), isTrue);
      expect(h.cache.viewport.anchor!.localId, anchor.localId);
      expect(
        h.cache.viewport.anchor!.viewportOffset,
        closeTo(anchor.viewportOffset, 1),
      );
      expect(h.scroll.offset, closeTo(before, 1));
      expect(tester.takeException(), isNull);
      // Exiting World releases the owner; a later visit starts a fresh archive.
      await h.close(tester);
      expect(h.cache.controller, isNull);
      expect(h.cache.viewport.anchor, isNull);
      final next = Harness(b);
      await tester.pumpWidget(next.build(world));
      await frames(tester);
      expect(b.requests.length, 2);
      await next.close(tester);
    },
  );

  testWidgets('reopening near the tail into a taller viewport clamps safely', (
    tester,
  ) async {
    final b = Backend()..rows = List.generate(40, (i) => historyJson('$i'));
    final h = Harness(b);
    final world = historyWorld();
    await tester.pumpWidget(h.build(world));
    await frames(tester);
    expect(h.cache.viewport.anchor, isNotNull);
    await tester.pumpWidget(h.build(world, shown: false));
    await frames(tester);
    tester.view.physicalSize =
        const Size(800, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    h.scroll.dispose();
    h.scroll = ScrollController();
    await tester.pumpWidget(h.build(world));
    await frames(tester);
    expect(h.scroll.offset, closeTo(h.scroll.position.maxScrollExtent, 1));
    expect(b.requests.length, 1);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets(
    'fold choices survive sheet disposal; account changes clear hidden cache',
    (tester) async {
      final b = Backend()..rows = List.generate(8, (i) => historyJson('$i'));
      final h = Harness(b);
      final world = historyWorld();
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      await tester.tap(find.text('Collapse').hitTestable().first);
      await frames(tester);
      final collapsed = Set.of(h.cache.collapsedMessages);
      expect(collapsed, isNotEmpty);
      await tester.pumpWidget(h.build(world, shown: false));
      await frames(tester);
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      expect(h.cache.collapsedMessages, collapsed);
      expect(list.hiddenMessageIds, isNotEmpty);
      expect(b.requests.length, 1);
      await tester.pumpWidget(h.build(world, shown: false));
      await frames(tester);
      h.services.sessionRevision.value++;
      expect(h.cache.controller!.ready, isFalse);
      expect(h.cache.collapsedMessages, isEmpty);
      expect(h.cache.viewport.anchor, isNull);
      b.rows = [historyJson('new-account')];
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(b.requests.length, 2);
      expect(h.cache.controller!.newestFirst.single.id, 'new-account');
      await h.close(tester);
    },
  );

  testWidgets(
    'failed first load is retained without automatic retry on reopening',
    (tester) async {
      final b = Backend()..fail = true;
      final h = Harness(b);
      final world = historyWorld();
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pumpWidget(h.build(world, shown: false));
      await frames(tester);
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(b.requests.length, 1);
      b.fail = false;
      await tester.tap(find.text('Retry'));
      await frames(tester);
      expect(b.requests.length, 2);
      expect(find.byType(LocationChatAnchoredMessageList), findsOneWidget);
      await h.close(tester);
    },
  );

  testWidgets(
    '12+ locations: single world request, metadata and clock do not fetch',
    (tester) async {
      final b = Backend();
      final h = Harness(b);
      var world = historyWorld(locations: 13);
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(b.requests.length, 1);
      expect(b.requests.single.uri.path, '/aitown-chat/api/v1/world/history');
      expect(find.byType(LocationChatAnchoredMessageList), findsOneWidget);
      world = world.copyWith(currentTime: 'new clock');
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      await tester.pumpWidget(h.build(historyWorld(locations: 14)));
      await frames(tester);
      expect(b.requests.length, 1);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    },
  );
  testWidgets(
    'unknown and unassociated rows survive; empty version page loads only manually',
    (tester) async {
      final b = Backend()
        ..rows = [historyJson('future', version: 99999999)]
        ..more = true;
      final h = Harness(b);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      expect(b.requests.length, 1);
      expect(find.text('Load earlier messages'), findsOneWidget);
      b.rows = [
        historyJson('unknown', locations: ['Z']),
        historyJson('world', locations: []),
      ];
      b.more = false;
      await tester.tap(find.text('Load earlier messages'));
      await frames(tester);
      expect(b.requests.length, 2);
      expect(b.requests.last.uri.queryParameters['cursor'], 'opaque+/=cursor');
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      expect(list.messages.length, 2);
      expect(
        find.byKey(const ValueKey('world-history-continue-Z')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await h.close(tester);
    },
  );
  testWidgets(
    'foreground rechecks latest while failed background sync retains the snapshot',
    (tester) async {
      final b = Backend();
      final h = Harness(b);
      final world = historyWorld();
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      final uncover = h.presentation.cover();
      await frames(tester);
      uncover();
      await frames(tester);
      expect(b.requests.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await frames(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(b.requests.length, 2);
      await tester.pumpWidget(h.build(world, active: false));
      await frames(tester);
      b.fail = true;
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(b.requests.length, 3);
      expect(find.text('History permission denied'), findsNothing);
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      expect(list.messages.length, 1);
      await tester.pump(const Duration(seconds: 60));
      expect(b.requests.length, 3);
      await h.close(tester);
    },
  );
  testWidgets(
    'covered first request completes in World cache without a second request',
    (tester) async {
      final b = Backend()..pending = Completer<void>();
      final h = Harness(b);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester, 3);
      expect(b.requests.length, 1);
      final uncover = h.presentation.cover();
      await frames(tester, 3);
      expect(b.requests.first.cancellationToken!.isCancelled, isFalse);
      b.pending!.complete();
      b.pending = null;
      await frames(tester, 3);
      expect(find.byType(LocationChatAnchoredMessageList), findsNothing);
      uncover();
      await frames(tester);
      expect(b.requests.length, 1);
      expect(find.byType(LocationChatAnchoredMessageList), findsOneWidget);
      await h.close(tester);
    },
  );
  testWidgets(
    'route coverage and tab reentry never refresh completed history',
    (tester) async {
      final b = Backend();
      final h = Harness(b);
      final world = historyWorld();
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      unawaited(
        h.navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      expect(b.requests.length, 1);
      h.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(b.requests.length, 1);
      await tester.pumpWidget(h.build(world, active: false));
      await frames(tester);
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(b.requests.length, 1);
      await h.close(tester);
    },
  );
  testWidgets('session and World switch discard old late responses', (
    tester,
  ) async {
    final b = Backend()
      ..rows = [historyJson('old')]
      ..pending = Completer<void>();
    final h = Harness(b);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester, 3);
    final old = b.pending!;
    b.pending = null;
    b.rows = [historyJson('new')];
    h.services.sessionRevision.value++;
    await frames(tester);
    old.complete();
    await frames(tester);
    var list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    expect(list.messages.single.localId, contains('new'));
    expect(b.requests.length, 2);
    b.pending = Completer<void>();
    h.services.sessionRevision.value++;
    await tester.pumpWidget(h.build(historyWorld(), active: false));
    await frames(tester);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester, 3);
    final oldWorld = b.pending!;
    b.pending = null;
    b.rows = [historyJson('other-world')];
    await tester.pumpWidget(h.build(historyWorld().copyWith(worldId: 'w2')));
    await frames(tester);
    oldWorld.complete();
    await frames(tester);
    list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    expect(list.messages.single.localId, contains('other-world'));
    expect(b.requests.last.uri.queryParameters['world_id'], 'w2');
    await h.close(tester);
  });
}
