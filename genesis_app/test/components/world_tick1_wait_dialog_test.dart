import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_tick1_wait_dialog.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/ui/components/genesis_edge_swipe_back.dart';

void main() {
  testWidgets('tick wait dialog error state only allows retry', (
    WidgetTester tester,
  ) async {
    final requests = <Completer<WorldDetail>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(
                  showWorldTick1WaitDialog(
                    context: context,
                    loadWorld: () {
                      final completer = Completer<WorldDetail>();
                      requests.add(completer);
                      return completer.future;
                    },
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    requests.single.completeError(Exception('pending'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('world-tick1-wait-cancel')), findsNothing);
    expect(
      find.byKey(const ValueKey('world-tick1-wait-retry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('world-tick1-wait-retry')));
    await tester.pump();
    requests.last.complete(_world(tickCount: 1));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('world-tick1-wait-dialog')), findsNothing);
  });

  testWidgets('tick wait dialog closes from iOS leading edge swipe', (
    WidgetTester tester,
  ) async {
    final completer = Completer<WorldDetail>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(
                  showWorldTick1WaitDialog(
                    context: context,
                    loadWorld: () => completer.future,
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
      findsOneWidget,
    );
    expect(tester.getRect(find.byType(GenesisEdgeSwipeBack)).left, 0);
    expect(
      tester.getSize(find.byType(GenesisEdgeSwipeBack)).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    final edgeSwipeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector && widget.onHorizontalDragUpdate != null,
    );
    expect(edgeSwipeFinder, findsOneWidget);

    await tester.drag(edgeSwipeFinder, const Offset(160, 0));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('world-tick1-wait-dialog')), findsNothing);
  });

  testWidgets('tick wait dialog invokes back callback from iOS edge swipe', (
    WidgetTester tester,
  ) async {
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: WorldTick1WaitDialog(onBackPressed: () => backCount += 1),
      ),
    );

    final edgeSwipeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector && widget.onHorizontalDragUpdate != null,
    );
    expect(edgeSwipeFinder, findsOneWidget);

    await tester.drag(edgeSwipeFinder, const Offset(160, 0));
    await tester.pump();

    expect(backCount, 1);
  });
}

WorldDetail _world({required int tickCount}) {
  return WorldDetail(
    id: 1,
    worldId: 'w_1',
    originId: 1,
    ownerUid: 'u_1',
    name: 'World',
    tickCount: tickCount,
    connectCount: 0,
    characterCount: 0,
    playerCount: 0,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: '',
    metric: const <String, dynamic>{},
    inviteToken: 'w_1',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'o_1',
      name: 'Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: const <Map<String, dynamic>>[],
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}
