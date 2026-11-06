import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_global_config.dart';
import 'package:genesis_flutter_android/app/startup/startup_prompt_sequence.dart';
import 'package:genesis_flutter_android/components/auth/startup_login_gate.dart';
import 'package:genesis_flutter_android/components/login_provider_button.dart';
import 'package:genesis_flutter_android/components/me/signed_out_me_view.dart';
import 'package:genesis_flutter_android/pages/me/force_login_page.dart';
import 'package:genesis_flutter_android/platform/auth/auth_cancelled_exception.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  late AppGlobalConfigStore config;
  late MemoryUserSessionStore session;
  late ValueNotifier<int> revision;
  var pageBuilds = 0;
  setUp(() {
    config = AppGlobalConfigStore(loadConfig: ({String? uid}) async => {});
    session = MemoryUserSessionStore();
    revision = ValueNotifier(0);
    pageBuilds = 0;
  });
  tearDown(() {
    config.dispose();
    revision.dispose();
    startupPromptSequence.resetForTesting();
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<bool> Function(IdentityProvider)? login,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: StartupLoginGate(
          config: config,
          sessionStore: session,
          sessionRevision: revision,
          onLogin: login,
          builder: (_) {
            pageBuilds++;
            return const Scaffold(body: Text('existing landing page'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> clickGoogle(WidgetTester tester) async {
    final button = find.byWidgetPredicate(
      (w) => w is LoginProviderButton && w.provider == IdentityProvider.google,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('false keeps the existing landing page', (tester) async {
    await pump(tester);
    expect(find.text('existing landing page'), findsOneWidget);
    expect(find.byType(ForceLoginPage), findsNothing);
    expect(startupPromptSequence.loginBlocked, isFalse);
  });

  testWidgets('true shows shared Me login full screen and blocks back', (
    tester,
  ) async {
    config.value = const AppGlobalConfig(forceLogin: true);
    await pump(tester);
    expect(find.byType(SignedOutMeView), findsOneWidget);
    expect(find.text('existing landing page'), findsNothing);
    expect(pageBuilds, greaterThan(0));
    expect(startupPromptSequence.blocksOtherPrompts, isTrue);
    expect(
      tester.getSize(find.byKey(const ValueKey('force-login-page'))),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    final pageContext = tester.element(find.byType(ForceLoginPage));
    expect(
      ModalRoute.of(pageContext)!.popDisposition,
      RoutePopDisposition.doNotPop,
    );
    await Navigator.of(pageContext).maybePop();
    await tester.pump();
    expect(find.byType(ForceLoginPage), findsOneWidget);
  });

  testWidgets('already signed in bypasses required login, even without token', (
    tester,
  ) async {
    config.value = const AppGlobalConfig(forceLogin: true);
    await session.saveUid('signed-in');
    await pump(tester);
    expect(find.text('existing landing page'), findsOneWidget);
    expect(find.byType(ForceLoginPage), findsNothing);
  });

  testWidgets(
    'pending config displays the original page without loading or prompt blocking',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      config.dispose();
      config = AppGlobalConfigStore(
        loadConfig: ({String? uid}) => response.future,
      );
      final loading = config.refresh();
      await pump(tester);
      expect(pageBuilds, greaterThan(0));
      expect(find.byType(ForceLoginPage), findsNothing);
      expect(startupPromptSequence.loginBlocked, isFalse);
      expect(find.text('existing landing page'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      response.complete({'force_login': true});
      await loading;
      await tester.pumpAndSettle();
      expect(find.byType(ForceLoginPage), findsOneWidget);
      expect(pageBuilds, greaterThan(0));
    },
  );

  testWidgets('config failure uses the existing disabled default', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    config.dispose();
    config = AppGlobalConfigStore(
      loadConfig: ({String? uid}) => response.future,
    );
    final loading = expectLater(config.refresh(), throwsStateError);
    await pump(tester);
    response.completeError(StateError('offline'));
    await loading;
    await tester.pumpAndSettle();
    expect(find.text('existing landing page'), findsOneWidget);
    expect(startupPromptSequence.loginBlocked, isFalse);
  });

  testWidgets('success resumes the original builder without changing route', (
    tester,
  ) async {
    config.value = const AppGlobalConfig(forceLogin: true);
    var clicks = 0;
    final result = Completer<bool>();
    await pump(
      tester,
      login: (_) {
        clicks++;
        return result.future;
      },
    );
    final route = ModalRoute.of(
      tester.element(find.text('existing landing page', skipOffstage: false)),
    );
    final landing = tester.element(
      find.text('existing landing page', skipOffstage: false),
    );
    await clickGoogle(tester);
    await clickGoogle(tester);
    expect(clicks, 1);
    expect(pageBuilds, greaterThan(0));
    await session.saveUid('new-user');
    result.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('existing landing page'), findsOneWidget);
    expect(tester.element(find.text('existing landing page')), same(landing));
    expect(
      ModalRoute.of(tester.element(find.text('existing landing page'))),
      same(route),
    );
    expect(startupPromptSequence.loginBlocked, isFalse);
    // Existing post-login navigation/session handling owns subsequent logout.
    await session.clearUid();
    revision.value++;
    await tester.pumpAndSettle();
    expect(find.byType(ForceLoginPage), findsNothing);
  });

  for (final canceled in [true, false]) {
    testWidgets(
      'login ${canceled ? 'cancel' : 'failure'} stays and permits retry',
      (tester) async {
        config.value = const AppGlobalConfig(forceLogin: true);
        var clicks = 0;
        await pump(
          tester,
          login: (_) async {
            clicks++;
            if (canceled) throw const AuthCancelledException();
            return false;
          },
        );
        await clickGoogle(tester);
        await tester.pumpAndSettle();
        expect(find.byType(ForceLoginPage), findsOneWidget);
        expect(pageBuilds, greaterThan(0));
        await clickGoogle(tester);
        await tester.pumpAndSettle();
        expect(clicks, 2);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  }
}
