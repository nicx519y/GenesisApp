import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_stage.dart';
import 'package:genesis_flutter_android/components/world_top_overlay_bar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_search_field.dart';

void main() {
  testWidgets('world map stage positions overlay tabs from top setting', (
    tester,
  ) async {
    const overlayTop = 44.0;
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: overlayTop,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byType(WorldTopOverlayBar)).dy, overlayTop);
  });

  testWidgets('world map stage does not zoom overlay controls', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: 44,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(WorldTopOverlayBar), findsOneWidget);
  });

  testWidgets('world map stage can hide internal overlay tabs', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: 44,
              showTopOverlay: false,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(WorldTopOverlayBar), findsNothing);
  });

  testWidgets('world map stage keeps overlay tab text colors unchanged', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: 44,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelColor, const Color(0xFF111111));
    expect(tabBar.unselectedLabelColor, const Color(0xFF111111));
  });

  testWidgets('world map stage uses sixteen pixel overlay tab text', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: 44,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelStyle?.fontSize, 16);
    expect(tabBar.unselectedLabelStyle?.fontSize, 16);
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.center);
  });

  testWidgets(
    'world map stage keeps centered overlay tabs with fixed spacing',
    (tester) async {
      final controller = TabController(length: 2, vsync: tester);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 300,
              child: WorldMapStage(
                controller: controller,
                pointsCount: 3,
                top: 44,
                mapBuilder: (context, pointMode) =>
                    const ColoredBox(color: Colors.green),
              ),
            ),
          ),
        ),
      );

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final padding = tabBar.labelPadding as EdgeInsets;
      final mapRect = tester.getRect(find.text('Map'));
      final locationRect = tester.getRect(find.text('Location (3)'));

      expect(padding.left, 12);
      expect(padding.right, 12);
      expect(locationRect.left - mapRect.right, greaterThan(20));
    },
  );

  testWidgets('world map stage uses fixed overlay and back button heights', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: 44,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    final tabBarRect = tester.getRect(find.byType(TabBar));
    final backButtonRect = tester.getRect(find.byType(IconButton));

    expect(tabBarRect.height, genesisSearchFieldHeight);
    expect(backButtonRect.width, genesisSearchFieldHeight);
    expect(backButtonRect.height, genesisSearchFieldHeight);
  });

  testWidgets('world map stage uses transparent overlay backgrounds', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: WorldMapStage(
              controller: controller,
              pointsCount: 3,
              top: 44,
              mapBuilder: (context, pointMode) =>
                  const ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );

    final decoratedContainers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(WorldTopOverlayBar),
            matching: find.byType(Container),
          ),
        )
        .where((container) => container.decoration is BoxDecoration)
        .toList();
    final colors = decoratedContainers
        .map((container) => (container.decoration! as BoxDecoration).color)
        .whereType<Color>()
        .toList();

    expect(colors.where((color) => color == Colors.transparent), hasLength(2));
  });
}
