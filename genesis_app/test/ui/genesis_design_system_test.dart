import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/me/developer_design_system_gallery.dart';
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

  testWidgets('search launcher and clear action keep 44 point hit targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: 'world');
    addTearDown(controller.dispose);
    var launched = false;
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: GenesisSearchField.launcher(
                variant: GenesisSearchFieldVariant.compact,
                hintText: 'Search worlds',
                onTap: () => launched = true,
              ),
            ),
          ),
        ),
      ),
    );

    final launcher = find.byType(GenesisSearchField);
    final launcherRect = tester.getRect(launcher);
    expect(
      launcherRect.height,
      greaterThanOrEqualTo(GenesisControlMetrics.minimumTapTarget),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('genesis-search-field-visual')))
          .height,
      genesisCompactSearchFieldHeight,
    );
    expect(find.semantics.byLabel('Search worlds'), findsOneWidget);
    await tester.tapAt(launcherRect.bottomCenter - const Offset(0, 2));
    expect(launched, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: GenesisSearchField.editable(
                variant: GenesisSearchFieldVariant.compact,
                hintText: 'Search worlds',
                controller: controller,
                onClear: () => cleared = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.semantics.byLabel('Clear search'), findsOneWidget);
    final clearAction = find.byKey(
      const ValueKey('genesis-search-field-clear-action'),
    );
    final clearRect = tester.getRect(clearAction);
    expect(
      clearRect.height,
      greaterThanOrEqualTo(GenesisControlMetrics.minimumTapTarget),
    );
    await tester.tapAt(clearRect.bottomCenter - const Offset(0, 2));
    expect(cleared, isTrue);
    semantics.dispose();
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

  testWidgets('leading title app bar follows the Worldo header metrics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var actionPressed = false;
    final appBar = GenesisAppBar(
      title: 'Buy Gems',
      variant: GenesisAppBarVariant.leadingTitle,
      actions: [
        Padding(
          padding: const EdgeInsets.only(
            right: GenesisControlMetrics.appBarHorizontalPadding,
          ),
          child: GenesisAppBarActionLink(
            label: 'Records',
            onPressed: () => actionPressed = true,
          ),
        ),
      ],
    );
    expect(appBar.preferredSize.height, 64);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(appBar: appBar),
      ),
    );

    final title = tester.widget<Text>(find.text('Buy Gems'));
    expect(title.style?.fontSize, 17);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(title.style?.height, 1);
    expect(tester.getRect(find.text('Buy Gems')).left, closeTo(66, 0.1));
    expect(find.byType(GenesisBackButton), findsOneWidget);
    expect(
      tester.getRect(find.text('Buy Gems')).left -
          tester.getRect(find.byType(GenesisBackButton)).right,
      closeTo(12, 0.1),
    );

    final actionLabel = tester.widget<Text>(find.text('Records'));
    expect(actionLabel.style?.fontSize, 12);
    expect(actionLabel.style?.fontWeight, FontWeight.w600);
    expect(actionLabel.style?.height, 1);
    expect(
      tester.getSize(find.byType(GenesisChevronRightIcon)),
      const Size.square(9),
    );
    expect(
      tester.getRect(find.byType(GenesisChevronRightIcon)).right,
      closeTo(370, 0.1),
    );

    await tester.tap(find.byType(GenesisAppBarActionLink));
    expect(actionPressed, isTrue);
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

  testWidgets('compact tab bar keeps a 44 point vertical hit target', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Center(
              child: GenesisTabBar.compact(
                labels: const ['One', 'Two'],
                onTap: (index) => selected = index,
              ),
            ),
          ),
        ),
      ),
    );

    final barRect = tester.getRect(find.byType(GenesisTabBar));
    expect(
      barRect.height,
      greaterThanOrEqualTo(GenesisControlMetrics.minimumTapTarget),
    );
    final firstLabelCenter = tester.getCenter(find.text('One'));
    await tester.tapAt(Offset(firstLabelCenter.dx, barRect.bottom - 2));
    expect(selected, 0);
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

  testWidgets('page scroll body supplies the standard scroll defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: const GenesisPageScaffold.secondary(
          title: 'About',
          body: GenesisPageScrollBody(children: [Text('Page content')]),
        ),
      ),
    );

    final scrollBody = tester.widget<ListView>(find.byType(ListView));
    expect(scrollBody.padding, GenesisSpacing.pagePadding);
    expect(
      scrollBody.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(find.text('Page content'), findsOneWidget);
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

  testWidgets(
    'control button keeps a 34 point visual and 44 point tap target',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.worldoLight(),
          home: Scaffold(
            body: GenesisControlButton(
              tooltip: 'More actions',
              onPressed: () => presses += 1,
              child: const Icon(Icons.more_horiz, size: 14),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(GenesisControlButton)),
        const Size.square(GenesisControlMetrics.backButtonVisualSize),
      );
      await tester.tapAt(
        tester.getCenter(find.byType(GenesisControlButton)) +
            const Offset(20, 0),
      );
      expect(presses, 1);
      expect(find.byTooltip('More actions'), findsOneWidget);
    },
  );

  testWidgets('filter chip selection inverts the active surface', (
    tester,
  ) async {
    var selected = false;
    final colors = GenesisSemanticColors.worldoLight();
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Scaffold(
          body: GenesisFilterChip(
            label: 'Active',
            selected: true,
            onPressed: () => selected = true,
          ),
        ),
      ),
    );

    final chip = find.byType(GenesisFilterChip);
    final material = tester.widget<Material>(
      find.descendant(of: chip, matching: find.byType(Material)).last,
    );
    final label = tester.widget<Text>(find.text('Active'));
    expect(tester.getSize(chip).height, GenesisControlMetrics.minimumTapTarget);
    expect(material.color, colors.foregroundStrong);
    expect(label.style?.color, colors.background);

    await tester.tap(chip);
    expect(selected, isTrue);
  });

  testWidgets('section panel, tags, and unread badge expose shared patterns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: const Scaffold(
          body: GenesisSectionPanel(
            title: 'Metadata',
            child: Row(
              children: [
                GenesisTag(label: 'world'),
                GenesisUnreadBadge(count: 120),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Metadata'), findsOneWidget);
    expect(find.text('world'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.byType(GenesisSurface), findsOneWidget);
  });

  testWidgets('developer gallery exposes the shared lightweight controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Scaffold(
          body: ListView(
            padding: GenesisSpacing.formPagePadding.copyWith(
              top: 20,
              bottom: 32,
            ),
            children: const [DeveloperDesignSystemGalleryContent()],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Typography'), findsOneWidget);
    expect(find.text('Page / display title'), findsOneWidget);
    expect(find.text('Size 24 · Extra bold'), findsOneWidget);
    expect(find.text('Body text'), findsOneWidget);
    expect(find.text('Size 14 · Regular / semibold emphasis'), findsOneWidget);
    expect(find.text('Form label'), findsNothing);

    final galleryScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Page navigation'),
      400,
      scrollable: galleryScroll,
    );
    expect(
      find.byKey(const ValueKey<String>('design-system-leading-title-header')),
      findsOneWidget,
    );
    expect(find.byType(GenesisAppBarActionLink), findsOneWidget);
    expect(find.text('Leading editor header with action'), findsNothing);
    expect(find.byType(GenesisDisplayTitle), findsNothing);
    expect(find.byType(GenesisMetricValueText), findsNothing);
    expect(find.byType(GenesisSectionPanel), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Buttons'),
      400,
      scrollable: galleryScroll,
    );
    expect(find.byType(GenesisControlButton), findsNWidgets(2));
    expect(find.byType(GenesisCardActionButton), findsNWidgets(2));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('design-system-select-button')),
          )
          .height,
      GenesisButton.regularHeight,
    );
    expect(
      find.text('Card action · 34px · for actions inside image cards'),
      findsNothing,
    );
    expect(find.text('Icon buttons'), findsOneWidget);
    expect(find.text('Back button · 34 visual / 44 tap target'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('design-system-back-button')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Search, tabs and list navigation'),
      400,
      scrollable: galleryScroll,
    );
    expect(find.byType(GenesisTabBar), findsOneWidget);
    expect(find.byType(GenesisFilterChip), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Tags and badges'),
      400,
      scrollable: galleryScroll,
    );
    expect(find.byType(GenesisTag), findsNWidgets(2));
    expect(find.byType(GenesisAvatar), findsNWidgets(2));
    expect(find.text('99+'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Page States'),
      400,
      scrollable: galleryScroll,
    );
    expect(find.text('Page States'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Overlays'),
      400,
      scrollable: galleryScroll,
    );
    expect(find.text('Overlays'), findsOneWidget);
    expect(find.text('Content dialog'), findsNothing);
  });
}
