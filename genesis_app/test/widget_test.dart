import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/main.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/pages/create/create_characters_page.dart';
import 'package:genesis_flutter_android/pages/create/create_locations_page.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_page.dart';
import 'package:genesis_flutter_android/pages/create/create_story_events_page.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/components/search_bar.dart';
import 'package:genesis_flutter_android/pages/me/settings_page.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/backend_auth_coordinator.dart';
import 'package:genesis_flutter_android/platform/auth/identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

Future<AppServices> _testServices({bool backendAuthenticated = false}) async {
  const config = AppConfig(useMock: true);
  final platformConfig = DefaultPlatformConfig(appConfig: config);
  const deviceId = _FakeDeviceIdService();
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('u_mock');
  const identityAuth = _FakeIdentityAuthService();
  final api = GenesisApi(
    useMock: config.useMock,
    platformConfig: platformConfig,
    deviceIdService: deviceId,
    sessionStore: sessionStore,
    identityAuthService: identityAuth,
  );
  final backendAuth = _FakeBackendAuthCoordinator(
    authenticated: backendAuthenticated,
    sessionStore: sessionStore,
  );
  return AppServices(
    config: config,
    platformConfig: platformConfig,
    deviceId: deviceId,
    sessionStore: sessionStore,
    identityAuth: identityAuth,
    backendAuth: backendAuth,
    api: api,
    chatroom: ChatroomClient(
      wsBaseUrl: config.chatroomWsBaseUrl,
      sessionStore: sessionStore,
    ),
  );
}

Future<void> _pumpGenesisApp(WidgetTester tester) async {
  await tester.pumpWidget(GenesisApp(services: await _testServices()));
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  const _FakeIdentityAuthService();

  @override
  IdentityProfile? currentProfile() => null;

  @override
  bool hasLocalIdentitySession() => false;

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn() {
    throw UnimplementedError(
      'Widget tests should not launch identity sign-in.',
    );
  }

  @override
  Future<void> signOutIdentity() async {}
}

class _FakeBackendAuthCoordinator implements BackendAuthCoordinator {
  const _FakeBackendAuthCoordinator({
    required bool authenticated,
    required MemoryUserSessionStore sessionStore,
  }) : _authenticated = authenticated,
       _sessionStore = sessionStore;

  final bool _authenticated;
  final MemoryUserSessionStore _sessionStore;

  @override
  Future<bool> hasAuthenticatedBackendSession({
    bool tryAutoRefresh = true,
  }) async {
    return _authenticated;
  }

  @override
  Future<Never> loginWithIdentity(AuthSession session) {
    throw UnimplementedError('Widget tests should not perform backend login.');
  }

  @override
  Future<void> signOut() async {
    await _sessionStore.clearUid();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Origin is default tab', (WidgetTester tester) async {
    await _pumpGenesisApp(tester);

    expect(find.text('Origin'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('tap header search bar opens search page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

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

  testWidgets('search bar placeholder stays single line with ellipsis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: SearchBarPlaceholder(
              hintText: 'Search origins, worlds, users...',
            ),
          ),
        ),
      ),
    );

    final placeholder = tester.widget<Text>(
      find.text('Search origins, worlds, users...'),
    );
    expect(placeholder.maxLines, 1);
    expect(placeholder.overflow, TextOverflow.ellipsis);
    expect(placeholder.softWrap, isFalse);
  });

  testWidgets('search page shows tabs and no result state', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

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
    await _pumpGenesisApp(tester);

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
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('登录后可使用该功能'), findsNothing);
    expect(find.text('Sign In With Google'), findsNothing);
  });

  testWidgets('messages tab shows action buttons and section title', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New followers'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Direct messages'), findsOneWidget);
  });

  testWidgets('messages action button navigates to list page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifications').first);
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(
      find.text('Your world "Steam Kingdom" has new activity.'),
      findsOneWidget,
    );
  });

  testWidgets('tap Home switches to Home page', (WidgetTester tester) async {
    await _pumpGenesisApp(tester);

    expect(find.text('Origin'), findsNWidgets(2));

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
  });

  testWidgets('tap Me shows login sheet when not logged in', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Sign In With Google'), findsOneWidget);
  });

  testWidgets('tap Create opens create origin page directly', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);
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

    expect(find.text('WebSocket test'), findsOneWidget);

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

  testWidgets('settings opens websocket test page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WebSocket test'));
    await tester.pumpAndSettle();

    expect(find.text('WebSocket test'), findsWidgets);
    expect(find.text('Status: Disconnected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Send message'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Send message'), findsOneWidget);
  });
}
