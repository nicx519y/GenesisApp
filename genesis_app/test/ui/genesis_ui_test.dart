import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/components/page_header.dart';
import 'package:genesis_flutter_android/components/search_bar.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets('GenesisTheme provides shared app styles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.light(),
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Text('body', style: theme.textTheme.bodyMedium);
          },
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, GenesisColors.surface);
    expect(
      materialApp.theme?.textTheme.bodyMedium?.fontSize,
      GenesisTypography.body.fontSize,
    );
  });

  testWidgets('Genesis UI components read styles from GenesisUiTheme', (
    tester,
  ) async {
    const searchColor = Color(0xFF123456);
    const titleColor = Color(0xFF654321);
    final uiTheme = GenesisUiTheme.light().copyWith(
      searchBackgroundColor: searchColor,
      pageTitleStyle: GenesisTypography.pageTitle.copyWith(color: titleColor),
      bottomNavigationProminentColor: Colors.orange,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.light().copyWith(
          extensions: <ThemeExtension<dynamic>>[uiTheme],
        ),
        home: Scaffold(
          body: const Column(
            children: [
              GenesisPageTitle(text: 'Styled title'),
              GenesisSearchField(hintText: 'Styled search'),
            ],
          ),
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              GenesisBottomNavigationItem(
                label: 'Create',
                icon: Icons.add_circle_outline,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Styled title'));
    expect(title.style?.color, titleColor);

    final searchContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(GenesisSearchField),
        matching: find.byType(Container),
      ),
    );
    final searchDecoration = searchContainer.decoration as BoxDecoration;
    expect(searchDecoration.color, searchColor);

    final icon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(icon.color, Colors.orange);
  });

  testWidgets('GenesisSearchField keeps placeholder on one line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 180, child: GenesisSearchField())),
      ),
    );

    final placeholder = tester.widget<Text>(find.text('Explore'));
    expect(placeholder.maxLines, 1);
    expect(placeholder.overflow, TextOverflow.ellipsis);
    expect(placeholder.softWrap, isFalse);
  });

  testWidgets('GenesisPageHeader composes title and search field', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenesisPageHeader(
            title: 'Origin',
            onSearchTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    expect(tapped, isTrue);
  });

  testWidgets('SearchBarPlaceholder remains compatible with UI kit field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SearchBarPlaceholder(hintText: 'Explore')),
      ),
    );

    expect(
      tester.widget<SearchBarPlaceholder>(find.byType(SearchBarPlaceholder)),
      isA<GenesisSearchField>(),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, searchIconAsset);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('PageHeader reuses SearchBarPlaceholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PageHeader(pageName: 'Origin')),
      ),
    );

    expect(find.text('Origin'), findsOneWidget);
    expect(find.byType(SearchBarPlaceholder), findsOneWidget);
  });

  testWidgets('GenesisPrimaryButton uses the shared filled-button surface', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.light(),
        home: Scaffold(
          body: GenesisPrimaryButton(
            label: 'Continue',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    expect(
      theme?.filledButtonTheme.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      ),
      const Color(0xFF338960),
    );
  });

  testWidgets('GenesisPrimaryButton owns default disabled styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisPrimaryButton(label: 'Continue', onPressed: null),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFFBFD8CD),
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      Colors.white,
    );
  });

  testWidgets('GenesisActionBox attaches cancel for a single action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<bool>(
                    context: context,
                    title: 'Log out of your account?',
                    actions: const [
                      GenesisActionBoxAction<bool>(
                        label: 'Log out',
                        value: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      ),
      const Size(700, 184),
    );
    expect(find.text('Log out of your account?'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Log out of your account?'));
    final action = tester.widget<Text>(find.text('Log out'));
    final cancel = tester.widget<Text>(find.text('Cancel'));
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(action.style?.fontSize, 15);
    expect(action.style?.fontWeight, FontWeight.w600);
    expect(action.style?.color, const Color(0xFFFF2344));
    expect(cancel.style?.fontSize, 15);
    expect(cancel.style?.fontWeight, FontWeight.w400);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('GenesisActionBox uses 70 percent width on compact screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showGenesisActionBox<bool>(
                    context: context,
                    title: 'Log out of your account?',
                    actions: const [
                      GenesisActionBoxAction<bool>(
                        label: 'Log out',
                        value: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
          )
          .width,
      224,
    );
  });

  testWidgets('GenesisActionBox detaches cancel for multiple actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<String>(
                    context: context,
                    title: 'Save the draft before leaving?',
                    actions: const [
                      GenesisActionBoxAction<String>(
                        label: 'Save',
                        value: 'save',
                      ),
                      GenesisActionBoxAction<String>(
                        label: 'Discard',
                        value: 'discard',
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-action-box-detached-cancel')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('genesis-action-box-detached-cancel')),
          )
          .width,
      800,
    );
    expect(find.text('Save the draft before leaving?'), findsOneWidget);
    final firstAction = tester.widget<Text>(find.text('Save'));
    final secondAction = tester.widget<Text>(find.text('Discard'));
    expect(firstAction.style?.fontSize, 15);
    expect(firstAction.style?.fontWeight, FontWeight.w600);
    expect(secondAction.style?.fontSize, 15);
    expect(secondAction.style?.fontWeight, FontWeight.w600);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'save');
  });

  testWidgets('GenesisActionBox renders optional content below title', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<String>(
                    context: context,
                    title: 'Join request',
                    content: const Text(
                      'Requester U_001',
                      key: ValueKey('action-box-custom-content'),
                    ),
                    actions: const [
                      GenesisActionBoxAction<String>(
                        label: 'Approve',
                        value: 'approve',
                      ),
                      GenesisActionBoxAction<String>(
                        label: 'Reject',
                        value: 'reject',
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('action-box-custom-content')),
      findsOneWidget,
    );

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(result, 'approve');
  });

  testWidgets('GenesisPrimaryButton supports action-specific styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisPrimaryButton(
            label: 'Log out',
            onPressed: null,
            backgroundColor: Color(0xFFE1E1E3),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Color(0xFFE3E3E3),
            disabledForegroundColor: Color(0xFF6F6F6F),
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log out'),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFFE3E3E3),
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFF6F6F6F),
    );
    final shape =
        button.style?.shape?.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(8));
    final textStyle = button.style?.textStyle?.resolve(<WidgetState>{});
    expect(textStyle?.fontSize, 16);
    expect(textStyle?.fontWeight, FontWeight.w600);
  });

  testWidgets('GenesisBottomNavigation delegates selection to onTap', (
    tester,
  ) async {
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 0,
            onTap: (index) => selectedIndex = index,
            items: const [
              GenesisBottomNavigationItem(
                label: 'Home',
                icon: Icons.home_outlined,
              ),
              GenesisBottomNavigationItem(
                label: 'Create',
                icon: Icons.add_circle_outline,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Create'));
    expect(selectedIndex, 1);
  });

  testWidgets('GenesisBottomNavigation switches asset icon by selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 1,
            onTap: (_) {},
            items: const [
              GenesisBottomNavigationItem(
                label: 'Home',
                iconAsset: bottomNavHomeIconAsset,
                selectedIconAsset: bottomNavHomePressIconAsset,
              ),
              GenesisBottomNavigationItem(
                label: 'Messages',
                iconAsset: bottomNavMessagesIconAsset,
                selectedIconAsset: bottomNavMessagesPressIconAsset,
                badgeCount: 4,
              ),
              GenesisBottomNavigationItem(
                label: 'Create',
                iconAsset: bottomNavCreateIconAsset,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );

    final icons = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(icons, hasLength(3));
    expect(icons[0].width, 24);
    expect(icons[0].height, 24);
    expect(
      (icons[0].bytesLoader as SvgAssetLoader).assetName,
      bottomNavHomeIconAsset,
    );
    expect(
      (icons[1].bytesLoader as SvgAssetLoader).assetName,
      bottomNavMessagesPressIconAsset,
    );
    expect(icons[2].width, 28);
    expect(icons[2].height, 28);
    expect(
      (icons[2].bytesLoader as SvgAssetLoader).assetName,
      bottomNavCreateIconAsset,
    );

    final spacingBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(GenesisBottomNavigation),
            matching: find.byType(SizedBox),
          ),
        )
        .where((box) => box.width == null)
        .map((box) => box.height)
        .toList();
    expect(spacingBoxes.where((height) => height == 2), hasLength(2));
    expect(spacingBoxes.where((height) => height == 1), hasLength(1));

    final navSizedBoxes = tester.widgetList<SizedBox>(
      find.descendant(
        of: find.byType(GenesisBottomNavigation),
        matching: find.byType(SizedBox),
      ),
    );
    expect(navSizedBoxes.any((box) => box.height == 49), isTrue);

    final decoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GenesisBottomNavigation),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .singleWhere((decoration) => decoration.boxShadow != null);
    expect(decoration.color, Colors.white);
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.single.offset.dy, lessThan(0));

    final badgePosition = tester.widget<Positioned>(
      find.ancestor(
        of: find.byKey(const ValueKey('bottom-nav-Messages-unread-badge')),
        matching: find.byType(Positioned),
      ),
    );
    expect(badgePosition.top, -1);
    expect(badgePosition.left, 19);
  });

  testWidgets('GenesisBottomNavigation keeps minimum bottom padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.zero),
          child: Scaffold(
            bottomNavigationBar: GenesisBottomNavigation(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                GenesisBottomNavigationItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(GenesisBottomNavigation),
        matching: find.byType(Padding),
      ),
    );
    expect(
      padding.padding,
      const EdgeInsets.only(bottom: GenesisBottomNavigation.minBottomPadding),
    );
  });

  testWidgets('GenesisTabBar renders labels inside a DefaultTabController', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(body: GenesisTabBar(labels: ['Latest', 'Popular'])),
        ),
      ),
    );

    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.unselectedLabelColor, const Color(0xFF666666));
  });

  testWidgets('SecendTabs supports an explicit controller', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SecendTabs(
                controller: controller,
                labels: const ['Origin', 'World'],
              ),
              Expanded(
                child: TabBarView(
                  controller: controller,
                  children: const [Text('Origin list'), Text('World list')],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
  });

  testWidgets('SecendTabs can center scrollable tabs as a group', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: SecendTabs(
              labels: ['My Worlds', 'Popular'],
              tabAlignment: TabAlignment.center,
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.center);
  });

  testWidgets('SecendTabs can remove vertical padding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(
              children: [
                SecendTabs(labels: ['Origin', 'World'], verticalPadding: 0),
              ],
            ),
          ),
        ),
      ),
    );

    final element = tester.element(find.byType(SecendTabs));
    late Widget child;
    element.visitChildren((childElement) {
      child = childElement.widget;
    });

    final padding = child as Padding;
    expect(padding.padding, EdgeInsets.zero);
  });
}
