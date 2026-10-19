import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/components/common/page_presentation_scope.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
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
  final scroll = ScrollController();
  final presentation = PagePresentationController();
  final navigator = GlobalKey<NavigatorState>();
  Widget build(WorldDetail world, {bool active = true, String uid = 'me'}) =>
      AppServicesScope(
        services: services,
        child: MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PagePresentationScope(
              controller: presentation,
              child: WorldChatHistorySection(
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
    presentation.dispose();
  }
}

Future<void> frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
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
    'failure stops retries; foreground/cover resume do not refresh completed page',
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
      expect(b.requests.length, 1);
      await tester.pumpWidget(h.build(world, active: false));
      await frames(tester);
      b.fail = true;
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      expect(b.requests.length, 2);
      expect(find.text('History permission denied'), findsOneWidget);
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      expect(list.messages.length, 1);
      await tester.pump(const Duration(seconds: 60));
      expect(b.requests.length, 2);
      await h.close(tester);
    },
  );
  testWidgets(
    'covered in-flight request canceled, necessary read resumes once',
    (tester) async {
      final b = Backend()..pending = Completer<void>();
      final h = Harness(b);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester, 3);
      expect(b.requests.length, 1);
      final uncover = h.presentation.cover();
      await frames(tester, 3);
      expect(b.requests.first.cancellationToken!.isCancelled, isTrue);
      b.pending!.complete();
      b.pending = null;
      await frames(tester, 3);
      expect(find.byType(LocationChatAnchoredMessageList), findsNothing);
      uncover();
      await frames(tester);
      expect(b.requests.length, 2);
      expect(find.byType(LocationChatAnchoredMessageList), findsOneWidget);
      await h.close(tester);
    },
  );
  testWidgets(
    'route coverage pauses requests; reentry refreshes exactly once',
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
      expect(b.requests.length, 2);
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
