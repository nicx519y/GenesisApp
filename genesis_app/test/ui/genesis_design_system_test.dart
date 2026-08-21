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
    expect(
      GenesisTheme.worldoLight().extension<GenesisSkinTheme>()?.skin,
      GenesisSkin.worldoRedesign,
    );
    expect(
      GenesisTheme.forSkin(
        GenesisSkin.worldoRedesign,
        brightness: Brightness.light,
      ).brightness,
      Brightness.light,
    );
  });

  testWidgets('GenesisButton reports semantic interactions through UI scope', (
    tester,
  ) async {
    final interactions = <GenesisButtonInteraction>[];
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
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
        theme: GenesisTheme.worldoDark(),
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
        theme: GenesisTheme.worldoDark(),
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
        theme: GenesisTheme.worldoDark(),
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
        theme: GenesisTheme.worldoDark(),
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

  testWidgets('shared controls keep 44 point tap targets', (tester) async {
    var backPressed = false;
    var closePressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Row(
            children: [
              GenesisBackButton(onPressed: () => backPressed = true),
              const SizedBox(width: 60),
              GenesisBottomSheetCloseButton(
                onPressed: () => closePressed = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(GenesisBackButton)),
      const Size.square(GenesisControlMetrics.backButtonVisualSize),
    );
    expect(
      tester.getSize(find.byType(GenesisBottomSheetCloseButton)),
      const Size.square(GenesisControlMetrics.closeButtonVisualSize),
    );
    expect(
      tester
          .widget<GenesisBackButton>(find.byType(GenesisBackButton))
          .dimension,
      GenesisControlMetrics.backButtonVisualSize,
    );

    await tester.tapAt(
      tester.getCenter(find.byType(GenesisBackButton)) + const Offset(20, 0),
    );
    await tester.tapAt(
      tester.getCenter(find.byType(GenesisBottomSheetCloseButton)) +
          const Offset(18, 0),
    );
    expect(backPressed, isTrue);
    expect(closePressed, isTrue);
  });

  testWidgets('page scaffold selects standard root and editor chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: const GenesisPageScaffold.editor(
          title: 'Basics',
          body: Text('Form'),
        ),
      ),
    );

    final editorBar = tester.widget<GenesisAppBar>(find.byType(GenesisAppBar));
    expect(editorBar.variant, GenesisAppBarVariant.leadingTitle);
    expect(find.text('Basics'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: const GenesisPageScaffold.root(
          title: 'Messages',
          body: Text('List'),
        ),
      ),
    );
    expect(find.byType(GenesisPageHeader), findsOneWidget);
    expect(find.byType(GenesisAppBar), findsNothing);
  });

  testWidgets('shared form fields expose errors, counts and selection', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'World');
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Column(
            children: [
              GenesisTextField(
                controller: controller,
                label: 'Name',
                errorText: 'Required',
                maxLength: 30,
              ),
              GenesisSelectField(
                label: 'Role',
                valueText: 'Creator',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Required'), findsOneWidget);
    expect(find.text('5/30'), findsOneWidget);
    expect(find.text('Creator'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('dialog and bottom sheet named layouts expose stable variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Column(
            children: [
              GenesisDialog(
                title: 'Dialog',
                content: const Text('Content'),
                actions: [GenesisDialogAction(label: 'Done', onPressed: () {})],
              ),
              const GenesisBottomSheetPanel.content(
                title: 'Sheet',
                child: Text('Sheet content'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Dialog'), findsOneWidget);
    expect(find.text('Sheet'), findsOneWidget);
    expect(
      tester
          .widget<GenesisBottomSheetPanel>(find.byType(GenesisBottomSheetPanel))
          .layout,
      GenesisBottomSheetLayout.content,
    );
  });
}
