import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map.dart';
import 'package:genesis_flutter_android/pages/world/world_header.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart'
    as hook;
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A8f81866f11bb4803f54c/contract_fixture.dart';

void main() {
  testWidgets(
    'map-only blocker fails even while the header back button remains reachable',
    (tester) async {
      final blocked = ValueNotifier(false);
      final scope = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              key: scope,
              children: [
                WorldMapBackButton(
                  onPressed: () {
                    taps++;
                  },
                ),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: blocked,
                    builder: (_, value, child) =>
                        AbsorbPointer(absorbing: value, child: child),
                    child: const WorldMap.world(
                      definitionVersion: 1,
                      worldId: 'world-A',
                      common: WorldMapCommonConfig(),
                      legacy: LegacyWorldMapConfig(points: []),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      try {
        await tester.pump(const Duration(milliseconds: 100));
        final root = scope.currentContext! as Element;
        final back = tester.element(find.byType(WorldMapBackButton));
        expect(hook.mapGestureTargets(root), hasLength(1));
        Future<Map<String, Object?>> observe() async {
          final pending = hook.observeMapOperation(root, 'world-A');
          await tester.pump();
          return pending;
        }

        expect((await observe())['responsive'], true);
        blocked.value = true;
        await tester.pump();
        expect(hook.targetHitTestable(back), true);
        final obstructed = await observe();
        expect(obstructed['mapVisible'], true);
        expect(obstructed['responsive'], false);
        expect(obstructed['controlHitTestable'], false);
        blocked.value = false;
        await tester.pump();
        expect((await observe())['responsive'], true);
        expect(taps, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        blocked.dispose();
      }
    },
  );

  test(
    'rejects mutation and undeclared inputs before looking up resources',
    () async {
      await expectLater(
        hook.invoke({'operation': 'interact'}, false, true),
        throwsArgumentError,
      );
      await expectLater(
        hook.invoke({'operation': 'read', 'tap': true}, false, true),
        throwsArgumentError,
      );
      await expectLater(
        hook.invoke({'operation': 'read'}, false, false),
        throwsArgumentError,
      );
      await expectLater(
        fixture({'operation': 'prepare'}, false, true),
        throwsStateError,
      );
    },
  );
  testWidgets(
    'actual input blocker affects hit testing and is fully restored without tapping',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WorldMapBackButton(
                onPressed: () {
                  taps++;
                },
              ),
            ),
          ),
        ),
      );
      final target = tester.element(find.byType(WorldMapBackButton));
      final owned = InputBlockerFixture(Overlay.of(target));
      try {
        expect(hook.targetHitTestable(target), true);
        final preparing = owned.prepare();
        await tester.pump();
        await preparing;
        expect(hook.targetHitTestable(target), false);
        final restoring = owned.restore('session-A');
        await tester.pump();
        expect(await restoring, {
          'restored': true,
          'matchesSnapshot': true,
          'resource': 'session-A',
        });
        expect(hook.targetHitTestable(target), true);
        expect(taps, 0);
        expect(owned.entry, isNull);
        expect((await owned.restore('session-A'))['matchesSnapshot'], true);
      } finally {
        if (owned.acquired && !owned.released) {
          final closing = owned.restore('session-A');
          await tester.pump();
          await closing;
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'absent world is a negative observation even with a responsive frame',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final pending = hook.observeMapOperation(null, 'world-A');
      await tester.pump();
      final result = await pending;
      expect(result['responsive'], false);
      expect(result['frameObserved'], true);
      expect(result['mapVisible'], false);
      expect(result['controlHitTestable'], false);
    },
  );
  testWidgets('unacquired resources cannot produce a cleanup receipt', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: SizedBox(key: key)));
    final owned = InputBlockerFixture(Overlay.of(key.currentContext!));
    await expectLater(owned.restore('session-A'), throwsStateError);
  });
}
