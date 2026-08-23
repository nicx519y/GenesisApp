import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_stage.dart';
import 'package:genesis_flutter_android/components/world_top_overlay_bar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_control_icons.dart';
import 'package:genesis_flutter_android/ui/components/genesis_search_field.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_control_metrics.dart';

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
    final colors = GenesisSemanticColors.worldoLight();
    expect(tabBar.labelColor, colors.textPrimary);
    expect(tabBar.unselectedLabelColor, colors.textPrimary);
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
    // 9m: the world name in the top bar is 17/800.
    expect(tabBar.labelStyle?.fontSize, 17);
    expect(tabBar.unselectedLabelStyle?.fontSize, 17);
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

  testWidgets('origin map and info tabs use wider centered spacing', (
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
            child: WorldTopOverlayBar(
              pointsCount: 3,
              controller: controller,
              secondaryTabIsIntro: true,
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final padding = tabBar.labelPadding as EdgeInsets;
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.center);
    expect(padding.left, 20);
    expect(padding.right, 20);
  });

  testWidgets('Worldo title mode matches the redesigned title hierarchy', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);
    var infoTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: WorldTopOverlayBar(
              pointsCount: 3,
              controller: controller,
              title: 'Old Money',
              subtitle: 'Not started',
              secondaryTabIsIntro: true,
              onInfoTap: () => infoTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Old Money'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
    final colors = GenesisSemanticColors.worldoLight();
    expect(
      tester.widget<Text>(find.text('Old Money')).style?.color,
      colors.immersiveForeground,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('worldo-title-back-button')),
      ),
      const Size(34, 34),
    );
    final backButton = find.byKey(
      const ValueKey<String>('worldo-title-back-button'),
    );
    final infoButton = find.byKey(
      const ValueKey<String>('worldo-title-info-button'),
    );
    final backMaterial = tester.widget<Material>(
      find.descendant(of: backButton, matching: find.byType(Material)),
    );
    final infoMaterial = tester.widget<Material>(
      find.descendant(of: infoButton, matching: find.byType(Material)),
    );
    expect(infoMaterial.color, colors.controlMuted);
    expect(infoMaterial.color, backMaterial.color);

    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(infoTapped, isTrue);
    expect(controller.index, 0);
    expect(find.text('Info'), findsOneWidget);
  });

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
    final backButtonRect = tester.getRect(find.byType(GenesisBackButton));

    expect(tabBarRect.height, genesisSearchFieldHeight);
    expect(backButtonRect.width, GenesisControlMetrics.backButtonVisualSize);
    expect(backButtonRect.height, GenesisControlMetrics.backButtonVisualSize);
  });

  testWidgets('world map stage uses themed overlay backgrounds', (
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

    final semanticColors = GenesisSemanticColors.worldoLight();
    expect(
      colors.where(
        (color) => color == semanticColors.surface.withValues(alpha: 0.9),
      ),
      hasLength(1),
    );
    final backMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(GenesisBackButton),
        matching: find.byType(Material),
      ),
    );
    expect(backMaterial.color, semanticColors.controlMuted);
  });
}
