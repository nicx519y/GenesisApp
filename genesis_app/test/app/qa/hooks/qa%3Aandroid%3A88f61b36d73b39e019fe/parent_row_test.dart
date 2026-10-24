import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_location_list.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A88f61b36d73b39e019fe/view.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart'
    show dispatchSingleTap;

void main() {
  const parent = WorldPoint(
    id: 'p',
    name: 'Parent',
    type: WorldPointType.castle,
    position: Offset.zero,
    users: [],
    isLeafLocation: false,
  );
  const child = WorldPoint(
    id: 'c',
    name: 'Child',
    type: WorldPointType.shop,
    position: Offset.zero,
    users: [],
  );
  Future<void> mount(
    WidgetTester tester,
    ValueChanged<WorldPoint>? action, {
    bool blocked = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbsorbPointer(
            absorbing: blocked,
            child: WorldLocationList(
              points: const [],
              lazyBuildRows: true,
              enableOuterScrollHandoff: false,
              locationNodes: const [
                WorldMapLocationNode(
                  id: 'p',
                  point: parent,
                  children: [WorldMapLocationNode(id: 'c', point: child)],
                ),
              ],
              onNodeHeaderTap: action,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Element target(WidgetTester tester) => parentRowTarget(
    tester.element(find.byType(WorldLocationList)),
    'Parent',
  )!;
  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(WorldLocationList), findsNothing);
  }

  testWidgets('decorated parent header receives exactly one real touch', (
    tester,
  ) async {
    final selected = <String>[];
    try {
      await mount(tester, (point) => selected.add(point.id));
      expect(find.text('- Parent'), findsOneWidget);
      requireParentRowAction(target(tester));
      dispatchSingleTap(target(tester));
      await tester.pump();
      expect(selected, ['p']);
      expect(
        parentRowTarget(
          tester.element(find.byType(WorldLocationList)),
          'Child',
        ),
        isNull,
      );
    } finally {
      await clean(tester);
    }
  });
  testWidgets(
    'missing parent callback is an unavailable action, not a missing row',
    (tester) async {
      try {
        // Matches WorldSingleSectionBottomSheet: only leaf onPointTap is wired.
        await mount(tester, null);
        expect(find.text('- Parent'), findsOneWidget);
        expect(
          () => requireParentRowAction(target(tester)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'cause',
              'Parent row has no enabled tap action',
            ),
          ),
        );
      } finally {
        await clean(tester);
      }
    },
  );
  testWidgets('visible enabled parent cannot bypass an absorbing overlay', (
    tester,
  ) async {
    final selected = <String>[];
    try {
      await mount(tester, (point) => selected.add(point.id), blocked: true);
      expect(find.text('- Parent'), findsOneWidget);
      requireParentRowAction(target(tester));
      expect(
        () => dispatchSingleTap(target(tester)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'cause',
            contains('touch intercepted'),
          ),
        ),
      );
      expect(selected, isEmpty);
    } finally {
      await clean(tester);
    }
  });
}
