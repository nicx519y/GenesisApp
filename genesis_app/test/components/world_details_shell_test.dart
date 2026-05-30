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
          slivers: [SliverToBoxAdapter(child: Text('Details'))],
          bottomBar: SizedBox(
            key: ValueKey('bottom-bar'),
            height: 56,
            child: Text('Launch'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('map')), findsOneWidget);
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
                const EdgeInsets.only(
                  top: WorldDetailsPanel.contentTopPadding,
                  left: WorldDetailsPageScaffold.contentHorizontalPadding,
                  right: WorldDetailsPageScaffold.contentHorizontalPadding,
                ),
      ),
      findsOneWidget,
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
    const expectedPadding = EdgeInsets.only(
      top: WorldDetailsPanel.contentTopPadding,
      left: 12,
      right: 12,
    );

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
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 24))],
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
        (widget) => widget is Container && widget.padding == expectedPadding,
      ),
      findsOneWidget,
    );
  });
}
