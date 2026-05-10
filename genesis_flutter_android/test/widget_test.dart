import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:genesis_flutter_android/main.dart';
import 'package:genesis_flutter_android/pages/create/create_characters_page.dart';
import 'package:genesis_flutter_android/pages/create/create_locations_page.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_page.dart';
import 'package:genesis_flutter_android/pages/create/create_story_events_page.dart';
import 'package:genesis_flutter_android/pages/me/settings_page.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Origin is default tab', (WidgetTester tester) async {
    await tester.pumpWidget(const GenesisApp());

    expect(find.text('Origin'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('tap header search bar opens search page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GenesisApp());

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(
      find.text(
        'No search history yet.\nType at least 2 characters to search.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('search page shows tabs and no result state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GenesisApp());

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('search debounce cancels previous query display', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GenesisApp());

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'st');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('#Steam Kingdom'), findsNothing);
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('tap Messages does not show login sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GenesisApp());

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('登录后可使用该功能'), findsNothing);
    expect(find.text('Sign In With Google'), findsNothing);
  });

  testWidgets('tap Home switches to Home page', (WidgetTester tester) async {
    await tester.pumpWidget(const GenesisApp());

    expect(find.text('Origin'), findsNWidgets(2));

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
  });

  testWidgets('tap Me shows login sheet when not logged in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GenesisApp());

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('登录后可使用该功能'), findsOneWidget);
    expect(find.text('Sign In With Google'), findsOneWidget);
  });

  testWidgets('tap Create opens create origin page directly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GenesisApp());
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Origin'), findsOneWidget);
    expect(find.text('Upload context file'), findsOneWidget);
  });

  testWidgets('create route opens create origin page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.create,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Origin'), findsOneWidget);
    expect(find.text('Upload context file'), findsOneWidget);
  });

  testWidgets('create origin entries navigate to detail pages', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.create,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Basics'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Characters'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Locations (Optional)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Locations'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Story Events (Optional)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Story Events'), findsWidgets);
  });

  testWidgets('characters add button appends empty form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateCharactersPage()));
    await tester.pumpAndSettle();

    expect(find.text('Character 1'), findsOneWidget);
    expect(find.text('Character 2'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+ Add Character'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+ Add Character'));
    await tester.pumpAndSettle();

    expect(find.text('Character 2'), findsOneWidget);
  });

  testWidgets('locations add button appends empty form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateLocationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Location 1'), findsOneWidget);
    expect(find.text('Location 2'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+ Add Location'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+ Add Location'));
    await tester.pumpAndSettle();

    expect(find.text('Location 2'), findsOneWidget);
  });

  testWidgets('story events add button appends empty form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateStoryEventsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Event 1'), findsOneWidget);
    expect(find.text('Event 2'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+ Add Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+ Add Event'));
    await tester.pumpAndSettle();

    expect(find.text('Event 2'), findsOneWidget);
  });

  testWidgets('create button disabled before all sections saved', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateOriginPage()));
    await tester.pumpAndSettle();

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('settings opens about us page', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About us'));
    await tester.pumpAndSettle();

    expect(find.text('About us'), findsWidgets);
    expect(
      find.text(
        'Thanks for using Genesis Beta. More about us will appear here.',
      ),
      findsOneWidget,
    );
  });
}
