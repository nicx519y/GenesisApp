import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_details_shell.dart';

void main() {
  testWidgets('world details page scaffold owns shared floating layout', (
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
    expect(find.byType(WorldDetailsDragHandle), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-bar')), findsOneWidget);

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(
      sheet.maxChildSize,
      closeTo(
        (viewportSize.height - WorldDetailsPageScaffold.defaultPanelTopGap) /
            viewportSize.height,
        0.01,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding ==
                const EdgeInsets.fromLTRB(
                  WorldDetailsPageScaffold.contentHorizontalPadding,
                  0,
                  WorldDetailsPageScaffold.contentHorizontalPadding,
                  0,
                ),
      ),
      findsOneWidget,
    );
    final handleRect = tester.getRect(find.byType(WorldDetailsDragHandle));
    final titleRect = tester.getRect(
      find.byKey(const ValueKey('details-title')),
    );
    expect(handleRect.width, WorldDetailsShell.dragHandleWidth);
    expect(handleRect.height, WorldDetailsShell.dragHandleHeight);
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
    expect(
      tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .any(
            (widget) =>
                widget.height ==
                WorldDetailsPageScaffold.contentBottomPaddingWithBottomBar,
          ),
      isTrue,
    );
  });

  testWidgets('world details page scaffold uses explicit height settings', (
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
          map: ColoredBox(color: Colors.green),
          slivers: [SliverToBoxAdapter(child: Text('Details'))],
        ),
      ),
    );

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    final expectedDefaultSize =
        (WorldDetailsPanel.defaultExposedChildSize * viewportSize.height -
            panelCollapsedHeightOffset) /
        viewportSize.height;
    final expectedMaxSize =
        (viewportSize.height - panelTopGap) / viewportSize.height;

    expect(sheet.initialChildSize, closeTo(expectedDefaultSize, 0.01));
    expect(sheet.minChildSize, closeTo(expectedDefaultSize, 0.01));
    expect(sheet.maxChildSize, closeTo(expectedMaxSize, 0.01));
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
