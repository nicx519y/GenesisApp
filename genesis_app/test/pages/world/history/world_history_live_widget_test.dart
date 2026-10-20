import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_controller.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';

import 'history_fixtures.dart';
import 'world_history_widget_test.dart' show Backend, Harness, frames;

class HistorySource extends WorldChatroomService {
  HistorySource(Harness h)
    : super(
        api: h.services.api,
        client: h.services.chatroom,
        messageStorage: h.services.chatroomMessages,
      );
  final hints = StreamController<String>.broadcast();
  @override
  Stream<String> get historyChanges => hints.stream;
  @override
  Future<void> dispose() async {
    await hints.close();
    await super.dispose();
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
  testWidgets('latest hints and unchanged sync do not rebuild the archive', (
    tester,
  ) async {
    final h = Harness(Backend());
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    final original = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    expect(
      find.byKey(const ValueKey('world-history-return-to-bottom')),
      findsNothing,
    );
    h.cache.controller!.markLatestDirty();
    await frames(tester);
    expect(
      find.byKey(const ValueKey('world-history-return-to-bottom')),
      findsOneWidget,
    );
    expect(h.backend.requests.length, 2);
    expect(
      identical(
        tester.widget<LocationChatAnchoredMessageList>(
          find.byType(LocationChatAnchoredMessageList),
        ),
        original,
      ),
      isTrue,
      reason: 'Latest status only changes the notice, not the reading list.',
    );
    await h.close(tester);
  });

  testWidgets('an empty archive still shows a pending latest notice', (
    tester,
  ) async {
    final h = Harness(Backend()..rows = []);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    expect(find.byType(LocationChatAnchoredMessageList), findsNothing);
    expect(
      find.byKey(const ValueKey('world-history-return-to-bottom')),
      findsNothing,
    );
    h.cache.controller!.markLatestDirty();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('world-history-return-to-bottom')),
      findsOneWidget,
    );
    await h.close(tester);
  });

  testWidgets('scrolling to old tail adopts the cached latest page', (
    tester,
  ) async {
    final b = Backend()..rows = List.generate(40, (i) => historyJson('$i'));
    final h = Harness(b);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    list.coordinator.beginHistoryNavigation();
    h.scroll.jumpTo(h.scroll.position.maxScrollExtent / 2);
    await frames(tester);
    b.rows = [historyJson('latest')];
    h.cache.controller!.markLatestDirty();
    await frames(tester);
    expect(h.cache.controller!.hasPendingLatest, isTrue);
    h.scroll.jumpTo(h.scroll.position.maxScrollExtent);
    await frames(tester);
    expect(h.cache.controller!.newestFirst.single.id, 'latest');
    await h.close(tester);
  });

  testWidgets(
    'background, session change and source removal reject late sync',
    (tester) async {
      final b = Backend();
      final h = Harness(b);
      final source = HistorySource(h);
      h.cache.attach(source);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      await tester.pumpWidget(h.build(historyWorld(), shown: false));
      b.rows = [historyJson('fresh')];
      b.pending = Completer<void>();
      source.hints.add('w');
      await frames(tester);
      expect(b.requests.length, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(b.requests.last.cancellationToken!.isCancelled, isTrue);
      b.pending!.complete();
      b.pending = null;
      await frames(tester);
      expect(h.cache.controller!.hasPendingLatest, isFalse);
      source.hints.add('w');
      await frames(tester);
      expect(b.requests.length, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(b.requests.length, 3);
      expect(h.cache.controller!.hasPendingLatest, isTrue);
      b.pending = Completer<void>();
      source.hints.add('w');
      await frames(tester);
      h.services.sessionRevision.value++;
      expect(b.requests.last.cancellationToken!.isCancelled, isTrue);
      b.pending!.complete();
      b.pending = null;
      await frames(tester);
      expect(h.cache.controller!.ready, isFalse);
      expect(h.cache.controller!.hasPendingLatest, isFalse);
      final count = b.requests.length;
      source.hints.add('w');
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      expect(b.requests.length, count);
      await h.close(tester);
      await source.dispose();
    },
  );
  testWidgets('latest bottom follows completed HTTP content automatically', (
    tester,
  ) async {
    final b = Backend()..rows = [historyJson('old')];
    final h = Harness(b);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    b.rows = List.generate(20, (i) => historyJson('new-$i', content: 'New $i'));
    h.cache.controller!.markLatestDirty();
    await frames(tester);
    expect(h.cache.controller!.newestFirst.first.id, 'new-19');
    expect(h.cache.controller!.hasPendingLatest, isFalse);
    expect(h.scroll.offset, closeTo(h.scroll.position.maxScrollExtent, 1));
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('reading anchor and folds survive sync, arrow adopts latest', (
    tester,
  ) async {
    final b = Backend()
      ..rows = List.generate(
        40,
        (i) => historyJson('$i', content: 'Archive $i'),
      );
    final h = Harness(b);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    list.coordinator.beginHistoryNavigation();
    h.scroll.jumpTo(h.scroll.position.maxScrollExtent / 2);
    await frames(tester);
    final anchor = h.cache.viewport.anchor!;
    final offset = h.scroll.offset;
    final readingList = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    h.cache.collapsedMessages.add('retained-fold-choice');
    b.rows = [historyJson('latest', content: 'The latest message')];
    h.cache.controller!.markLatestDirty();
    await frames(tester);
    expect(h.cache.controller!.hasPendingLatest, isTrue);
    expect(
      identical(
        tester.widget<LocationChatAnchoredMessageList>(
          find.byType(LocationChatAnchoredMessageList),
        ),
        readingList,
      ),
      isTrue,
    );
    expect(h.cache.viewport.anchor!.localId, anchor.localId);
    expect(
      h.cache.viewport.anchor!.viewportOffset,
      closeTo(anchor.viewportOffset, 1),
    );
    expect(h.scroll.offset, closeTo(offset, 1));
    await tester.tap(
      find.byKey(const ValueKey('world-history-return-to-bottom')),
    );
    await frames(tester);
    expect(h.cache.controller!.newestFirst.single.id, 'latest');
    expect(h.cache.collapsedMessages, contains('retained-fold-choice'));
    expect(b.requests.length, 2);
    await h.close(tester);
  });

  for (final reading in [false, true]) {
    testWidgets('World keeps syncing with sheet removed; reading=$reading', (
      tester,
    ) async {
      final b = Backend()..rows = List.generate(40, (i) => historyJson('$i'));
      final h = Harness(b);
      final source = HistorySource(h);
      h.cache.attach(source);
      source.hints.add('w');
      await tester.pumpWidget(h.build(historyWorld(), shown: false));
      await frames(tester);
      expect(b.requests, isEmpty);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      if (reading) {
        final list = tester.widget<LocationChatAnchoredMessageList>(
          find.byType(LocationChatAnchoredMessageList),
        );
        list.coordinator.beginHistoryNavigation();
        h.scroll.jumpTo(h.scroll.position.maxScrollExtent / 2);
        await frames(tester);
      }
      final anchor = h.cache.viewport.anchor;
      await tester.pumpWidget(h.build(historyWorld(), shown: false));
      h.scroll.dispose();
      h.scroll = ScrollController();
      b.rows = [historyJson('hidden-latest')];
      final parsed = h.cache.projection.parsedMessageCount;
      source.hints.add('w');
      await frames(tester);
      expect(b.requests.length, 2);
      expect(h.cache.controller!.hasPendingLatest, isTrue);
      expect(h.cache.projection.parsedMessageCount, parsed);
      await tester.pumpWidget(h.build(historyWorld()));
      await frames(tester);
      if (reading) {
        expect(h.cache.controller!.hasPendingLatest, isTrue);
        expect(h.cache.viewport.anchor!.localId, anchor!.localId);
        expect(
          h.cache.viewport.anchor!.viewportOffset,
          closeTo(anchor.viewportOffset, 1),
        );
      } else {
        expect(h.cache.controller!.hasPendingLatest, isFalse);
        expect(h.cache.controller!.newestFirst.single.id, 'hidden-latest');
      }
      await h.close(tester);
      await source.dispose();
    });
  }

  testWidgets('drag started before response prevents automatic adoption', (
    tester,
  ) async {
    final b = Backend()..rows = List.generate(40, (i) => historyJson('$i'));
    final h = Harness(b);
    await tester.pumpWidget(h.build(historyWorld()));
    await frames(tester);
    b.rows = [historyJson('latest')];
    b.pending = Completer<void>();
    h.cache.controller!.markLatestDirty();
    await frames(tester, 11);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView).first),
    );
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    b.pending!.complete();
    b.pending = null;
    await frames(tester);
    expect(h.cache.controller!.hasPendingLatest, isTrue);
    await gesture.up();
    await frames(tester);
    expect(h.cache.controller!.hasPendingLatest, isTrue);
    await h.close(tester);
  });
}
