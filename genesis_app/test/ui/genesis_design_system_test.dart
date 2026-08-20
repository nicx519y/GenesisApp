import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  test('GenesisTheme exposes an explicit production skin identity', () {
    final theme = GenesisTheme.forSkin(GenesisSkin.worldoRedesign);

    expect(
      theme.extension<GenesisSkinTheme>()?.skin,
      GenesisSkin.worldoRedesign,
    );
    expect(theme.brightness, Brightness.dark);
    expect(GenesisTheme.light().extension<GenesisSkinTheme>()?.skin, isNull);
  });

  testWidgets('GenesisButton reports semantic interactions through UI scope', (
    tester,
  ) async {
    final interactions = <GenesisButtonInteraction>[];
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: GenesisUiInteractionScope(
          onButtonInteraction: interactions.add,
          child: Scaffold(
            body: GenesisButton(
              label: 'Continue',
              onPressed: () => pressed = true,
              fullWidth: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));

    expect(pressed, isTrue);
    expect(interactions, hasLength(1));
    expect(interactions.single.actionId, 'button.primary.continue');
    expect(interactions.single.component, 'GenesisButton');
    expect(interactions.single.enabled, isTrue);
  });

  testWidgets('named search constructors preserve launcher and edit modes', (
    tester,
  ) async {
    final controller = TextEditingController();
    var launcherTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: Scaffold(
          body: Column(
            children: [
              GenesisSearchField.launcher(
                hintText: 'Launch search',
                onTap: () => launcherTapped = true,
              ),
              GenesisSearchField.editable(
                hintText: 'Type search',
                controller: controller,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch search'));
    await tester.enterText(find.byType(TextField), 'world');

    expect(launcherTapped, isTrue);
    expect(controller.text, 'world');
    controller.dispose();
  });

  testWidgets('shared state and navigation components expose stable slots', (
    tester,
  ) async {
    var retried = false;
    var navigated = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: Scaffold(
          body: Column(
            children: [
              GenesisStateView.error(
                message: 'Load failed',
                onAction: () => retried = true,
              ),
              GenesisNavigationRow(
                label: 'Account',
                onTap: () => navigated = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Account'));

    expect(retried, isTrue);
    expect(navigated, isTrue);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
  });

  testWidgets('GenesisAppBar variants keep their declared metrics', (
    tester,
  ) async {
    const appBar = GenesisAppBar(
      title: 'Records',
      variant: GenesisAppBarVariant.leadingTitle,
      height: 46,
    );
    expect(appBar.preferredSize.height, 46);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: const Scaffold(appBar: appBar),
      ),
    );

    expect(find.text('Records'), findsOneWidget);
    expect(find.byType(GenesisBackButton), findsOneWidget);
  });

  testWidgets('GenesisTabBar named variants expose stable layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(
              children: [
                GenesisTabBar.scrollable(labels: const ['One', 'Two']),
                GenesisTabBar.expanded(labels: const ['One', 'Two']),
                GenesisTabBar.compact(labels: const ['One', 'Two']),
              ],
            ),
          ),
        ),
      ),
    );

    final bars = tester.widgetList<TabBar>(find.byType(TabBar)).toList();
    expect(bars[0].isScrollable, isTrue);
    expect(bars[1].isScrollable, isFalse);
    expect(bars[2].isScrollable, isTrue);
  });
}
