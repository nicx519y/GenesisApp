import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/components/search_bar.dart';
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
    expect(find.text('Explore'), findsOneWidget);
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
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(action.style?.fontSize, 15);
    expect(action.style?.fontWeight, FontWeight.w700);
    expect(cancel.style?.fontSize, 15);
    expect(cancel.style?.fontWeight, FontWeight.w400);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
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
    expect(firstAction.style?.fontWeight, FontWeight.w700);
    expect(secondAction.style?.fontSize, 15);
    expect(secondAction.style?.fontWeight, FontWeight.w400);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'save');
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
}
