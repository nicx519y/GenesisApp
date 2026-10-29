import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/components/login_provider_button.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/platform/auth/auth_cancelled_exception.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/login_submission_controller.dart';
import 'package:genesis_flutter_android/ui/components/genesis_dark_close_button.dart';
import 'package:genesis_flutter_android/pages/me/developer_forced_login_preview.dart';

void main() {
  testWidgets('developer login preview is isolated from app login results', (
    tester,
  ) async {
    final services = _Services();
    services.loginSubmission.markSucceeded();
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDeveloperForcedLoginPreview(context),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginSheet), findsOneWidget);
    services.loginSubmission.resetSessionResult();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.byType(LoginSheet), findsNothing);
    expect(services.loginSubmission.succeeded, isFalse);
    expect(services.loginSubmission.value, isNull);
  });

  testWidgets('personalization advances after another entry commits login', (
    tester,
  ) async {
    final services = _Services();
    final pending = Completer<void>();
    Widget tree(bool signedIn) => AppServicesScope(
      services: services,
      child: MaterialApp(
        home: Scaffold(
          body: PersonalizationSheet(
            initialStep: PersonalizationStep.signIn,
            initiallySignedIn: signedIn,
            form: const [],
            onSignIn: (_) async => null,
            onSubmit: (_) async => PersonalizationNextStep.close,
            subscriptionBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(false));
    final login = services.loginSubmission.submit(
      IdentityProvider.google,
      () => pending.future,
    );
    await tester.pumpWidget(tree(true));
    expect(find.byType(LoginProviderButtons), findsOneWidget);
    pending.complete();
    await login;
    await tester.pump();
    expect(find.byType(LoginProviderButtons), findsNothing);
    expect(
      find.byKey(const ValueKey('personalization-form-scroll')),
      findsOneWidget,
    );
  });

  for (final outcome in ['canceled', 'failed', 'origin disposed']) {
    testWidgets('login surfaces share submission state: $outcome', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = _Services();
      final pending = Completer<bool>();
      var signInCalls = 0;
      var otherCalls = 0;
      Widget tree({int index = 0, bool showOrigin = true}) => AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: IndexedStack(
              index: index,
              children: [
                if (showOrigin)
                  LoginSheet(
                    onLogin: (_) {
                      signInCalls++;
                      return pending.future;
                    },
                  )
                else
                  const SizedBox.shrink(),
                LoginSheet(
                  isDismissible: false,
                  onLogin: (_) async {
                    otherCalls++;
                    throw const AuthCancelledException();
                  },
                ),
                PersonalizationSheet(
                  initialStep: PersonalizationStep.signIn,
                  form: const [],
                  onSubmit: (_) async => PersonalizationNextStep.close,
                  onSignIn: (_) async {
                    otherCalls++;
                    return null;
                  },
                  subscriptionBuilder: (_) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
      Iterable<LoginProviderButtons> groups() => tester.widgetList(
        find.byType(LoginProviderButtons, skipOffstage: false),
      );
      void expectShared(IdentityProvider? provider) {
        for (final group in groups()) {
          expect(group.loggingInProvider, provider);
        }
        for (final button in tester.widgetList<LoginProviderButton>(
          find.byType(LoginProviderButton, skipOffstage: false),
        )) {
          expect(button.isLoading, provider == button.provider);
          expect(button.onPressed == null, provider != null);
        }
      }

      await tester.pumpWidget(tree());
      // Keep a second entry's old callback to exercise the shared guard even
      // before that entry has rebuilt its disabled buttons.
      final staleCallback = groups().last.onLogin;
      final attempt = Future<void>.sync(
        () => groups().first.onLogin(IdentityProvider.google),
      );
      await Future<void>.sync(() => staleCallback(IdentityProvider.apple));
      await tester.pump();
      expectShared(IdentityProvider.google);
      expect(signInCalls, 1);
      expect(otherCalls, 0);
      expect(
        tester
            .widget<GenesisDarkCloseButton>(
              find.byType(GenesisDarkCloseButton, skipOffstage: false).first,
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(
        tree(index: 2, showOrigin: outcome != 'origin disposed'),
      );
      expectShared(IdentityProvider.google);
      if (outcome == 'failed') {
        pending.complete(false);
      } else {
        pending.completeError(const AuthCancelledException());
      }
      await attempt;
      await tester.pump();
      expectShared(null);
      await Future<void>.sync(
        () => groups().last.onLogin(IdentityProvider.apple),
      );
      await tester.pump();
      expect(otherCalls, 1);
      expectShared(null);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}

class _Services implements AppServices {
  @override
  final loginSubmission = LoginSubmissionController();

  @override
  void dispose() => loginSubmission.dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
