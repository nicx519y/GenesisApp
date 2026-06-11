import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_details_shell.dart';

void main() {
  testWidgets('world details page scaffold owns one continuous scroll layout', (
    tester,
  ) async {
    const viewportSize = Size(400, 800);

    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WorldDetailsPageScaffold(
          map: ColoredBox(key: ValueKey('map'), color: Colors.green),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                key: ValueKey('details-title'),
                height: 18,
                child: Text('Details'),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 300)),
          ],
          bottomBar: SizedBox(
            key: ValueKey('bottom-bar'),
            height: 56,
            child: Text('Launch'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('map')), findsOneWidget);
    expect(find.byType(WorldDetailsDragHandle), findsNothing);
    expect(find.text('Details'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-bar')), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    final mapRect = tester.getRect(find.byKey(const ValueKey('map')));
    final titleRect = tester.getRect(
      find.byKey(const ValueKey('details-title')),
    );
    final expectedMapHeight =
        viewportSize.height * (1 - WorldDetailsPanel.defaultExposedChildSize) +
        WorldDetailsPageScaffold.defaultPanelCollapsedHeightOffset;

    expect(mapRect.top, 0);
    expect(mapRect.height, closeTo(expectedMapHeight, 0.01));
    expect(
      titleRect.top - mapRect.bottom,
      WorldDetailsPageScaffold.inlineContentTopPadding,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey('map'))).top, lessThan(0));
  });

  testWidgets('world details page scaffold uses explicit map height settings', (
    tester,
  ) async {
    const viewportSize = Size(400, 800);
    const panelTopGap = 44.0;
    const panelCollapsedHeightOffset = 72.0;

    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WorldDetailsPageScaffold(
          panelTopGap: panelTopGap,
          panelCollapsedHeightOffset: panelCollapsedHeightOffset,
          map: ColoredBox(key: ValueKey('explicit-map'), color: Colors.green),
          slivers: [SliverToBoxAdapter(child: Text('Details'))],
        ),
      ),
    );

    final mapRect = tester.getRect(find.byKey(const ValueKey('explicit-map')));
    final expectedMapHeight =
        (viewportSize.height * (1 - WorldDetailsPanel.defaultExposedChildSize) +
                panelCollapsedHeightOffset)
            .clamp(0.0, viewportSize.height - panelTopGap)
            .toDouble();

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(mapRect.height, closeTo(expectedMapHeight, 0.01));
  });

  testWidgets('world details panel owns title offset and horizontal padding', (
    tester,
  ) async {
    const viewportSize = Size(400, 800);

    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: WorldDetailsPanel(
              topGap: 30,
              horizontalPadding: 12,
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(key: ValueKey('panel-title'), height: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.maxChildSize, closeTo((viewportSize.height - 30) / 800, 0.01));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding == const EdgeInsets.fromLTRB(12, 0, 12, 0),
      ),
      findsOneWidget,
    );
    final handleRect = tester.getRect(find.byType(WorldDetailsDragHandle));
    final titleRect = tester.getRect(find.byKey(const ValueKey('panel-title')));
    expect(
      titleRect.top - handleRect.bottom,
      closeTo(
        (WorldDetailsPanel.contentTopPadding -
                    WorldDetailsShell.dragHandleHeight) /
                2 +
            WorldDetailsShell.dragHandleTitleGap,
        0.01,
      ),
    );
  });
}
