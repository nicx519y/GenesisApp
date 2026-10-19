import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_controller.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_projection.dart';
import 'history_fixtures.dart';

void main() {
  testWidgets('eviction and newer reload preserve shared viewport anchor', (
    tester,
  ) async {
    final history = WorldHistoryController(
      worldId: 'w',
      maxMessages: 60,
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) async {
        final page = cursor == null ? 0 : int.parse(cursor);
        return historyPage(
          List.generate(20, (i) => '$page-$i'),
          cursor: '${page + 1}',
        );
      },
    );
    final coordinator = LocationChatScrollCoordinator();
    final projection = WorldHistoryProjection();
    final world = historyWorld();
    addTearDown(history.dispose);
    addTearDown(coordinator.dispose);
    history.setActive(true);
    await history.refresh();
    for (var page = 1; page < 5; page++) {
      await history.loadOlder();
      history.updateReading(messageId: '$page-0');
    }
    expect(history.firstResident, 2);
    Widget tree() => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 500,
          child: NotificationListener<ScrollNotification>(
            onNotification: coordinator.handleScrollNotification,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: projection.project(
                newestFirst: history.newestFirst,
                dataRevision: history.revision,
                world: world,
                uid: 'me',
                appVersion: 999,
              ),
              topTitle: '',
              replyActionsVisible: false,
              replyWaitingPositioningEnabled: false,
              restoreInitialCompletedContent: true,
              showDateDividers: false,
              style: kLocationChatStyle.copyWith(
                messageListPadding: EdgeInsets.zero,
              ),
              messageDecorator: (m, previous, child) => SizedBox(
                key: ValueKey('archive-test:${m.localId}'),
                height: 100,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    coordinator.beginHistoryNavigation();
    final visible = coordinator.messageLocalIdsIntersectingViewport.toList();
    expect(visible, isNotEmpty);
    final anchor = visible[visible.length ~/ 2];
    final raw = projection.byId[anchor]!.message.id;
    expect(raw, startsWith('2-'));
    final before = tester.getTopLeft(find.byKey(ValueKey('archive-test:$anchor'))).dy;
    await history.loadNewer();
    history.updateReading(
      messageId: raw,
      pinnedIds: visible.map((id) => projection.byId[id]!.message.id),
    );
    expect(history.residentCount, lessThanOrEqualTo(60));
    expect(history.firstResident, 1);
    await tester.pumpWidget(tree());
    expect(
      tester.getTopLeft(find.byKey(ValueKey('archive-test:$anchor'))).dy,
      closeTo(before, 1),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(ValueKey('archive-test:$anchor'))).dy,
      closeTo(before, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
