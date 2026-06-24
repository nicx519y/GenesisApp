import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_tick1_wait_dialog.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';

void main() {
  testWidgets('tick wait dialog blocks route pop while waiting', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final completer = Completer<WorldDetail>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
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
    await tester.pump();

    expect(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
      findsOneWidget,
    );

    await navigatorKey.currentState!.maybePop();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
      findsOneWidget,
    );

    completer.complete(_world(tickCount: 1));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('world-tick1-wait-dialog')), findsNothing);
  });

  testWidgets('tick wait dialog error state only allows retry', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final requests = <Completer<WorldDetail>>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
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

    await navigatorKey.currentState!.maybePop();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('world-tick1-wait-retry')));
    await tester.pump();
    requests.last.complete(_world(tickCount: 1));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('world-tick1-wait-dialog')), findsNothing);
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
