import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aapp.login_failure_notice%253Avisible/notice.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aapp.login_failure_notice%253Avisible/contract_fixture.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/components/common/genesis_center_toast.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/components/login_provider_button.dart';
import 'package:genesis_flutter_android/platform/auth/auth_cancelled_exception.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

Future<bool> read() async => await readLoginFailureNotice({}, false, true) as bool;
QaBridge session() => QaBridge(MemoryUserSessionStore(), token: 'test-token', buildId: 'test-build')..started = true;

void main() {
  setUpAll(() {
    registerQaHook('log.android:app.login_failure_notice:visible', observeLoginFailureLog);
  });
  for (final outcome in ['false', 'exception', 'cancel']) {
    testWidgets('real LoginSheet $outcome, repeat reads, expiry and restore', (tester) async {
      final bridge = session();
      QaBridge.current = bridge;
      installQaLogObservation();
      var calls = 0;
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: LoginSheet(onLogin: (_) async {
          calls++;
          if (outcome == 'cancel') { throw const AuthCancelledException(); }
          if (outcome == 'exception') { throw Exception('provider unavailable'); }
          return false;
        }))));
        expect(await read(), false);
        await tester.tap(find.byType(LoginProviderButton).first);
        await tester.pump();
        expect(calls, 1);
        expect(await read(), outcome != 'cancel');
        expect(await read(), outcome != 'cancel');
        if (outcome != 'cancel') {
          expect(find.text(outcome == 'false' ? 'Sign-in failed' : 'Exception: provider unavailable'), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 3));
        expect(await read(), false);
        if (outcome == 'exception') {
          // Even identical text later is a new ordinary toast, not historical failure.
          showGenesisToast(tester.element(find.byType(LoginSheet)), 'Exception: provider unavailable');
          await tester.pump();
          expect(await read(), false);
        }
      } finally {
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox.shrink());
        await bridge.close();
      }
      expect(renderedToastElements(), isEmpty);
      expect(QaBridge.current, isNull);
    });
  }
  testWidgets('ordinary, replacement, duration and touch passthrough', (tester) async {
    late BuildContext context;
    var taps = 0;
    try {
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return Scaffold(body: Center(child: TextButton(onPressed: () => taps++, child: const Text('underlying action'))));
      })));
      showGenesisToast(context, 'ordinary');
      await tester.pump();
      expect(find.text('ordinary'), findsOneWidget);
      expect(await read(), false);
      showGenesisToast(context, 'Sign-in failed', duration: const Duration(milliseconds: 800), brightness: Brightness.dark);
      await tester.pump();
      expect(await read(), true);
      await tester.tap(find.text('underlying action'));
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 799));
      expect(await read(), true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await read(), false);
      expect(find.text('Sign-in failed'), findsNothing);
      showGenesisToast(context, 'Sign-in failed');
      await tester.pump();
      showGenesisToast(context, 'ordinary');
      await tester.pump();
      expect(await read(), false);
    } finally {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(renderedToastElements(), isEmpty);
  });
  testWidgets('page text and offstage text do not prove toast visibility', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Column(children: [
      Text('Sign-in failed'),
      Offstage(child: Text('Sign-in failed', textAlign: TextAlign.center, style: TextStyle(inherit: false, fontSize: 14))),
    ])));
    expect(await read(), false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('actual log without new rendering and a new session cannot revive an old toast', (tester) async {
    final bridge = session();
    QaBridge.current = bridge;
    installQaLogObservation();
    late BuildContext context;
    try {
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) { context = c; return const Scaffold(); })));
      showGenesisToast(context, 'Exception: existing ordinary');
      await tester.pump();
      debugPrint('[Auth][MePage] login failed: Exception: existing ordinary');
      await tester.pump();
      expect(await read(), false);
      debugPrint('[Auth][MePage] login failed: Exception: new error');
      showGenesisToast(context, 'Exception: new error');
      await tester.pump();
      expect(await read(), true);
      final next = session();
      await bridge.close();
      QaBridge.current = next;
      expect(await read(), false);
      await next.close();
    } finally {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await bridge.close();
    }
  });
  testWidgets('mock contract owns and restores its real LoginSheet resource', (tester) async {
    final bridge = session();
    QaBridge.current = bridge;
    installQaLogObservation();
    Future<Map<String, dynamic>> stimulus(String kind) async {
      final pending = loginFailureContractFixture({'kind': kind}, true, true);
      await tester.pumpAndSettle();
      return await pending as Map<String, dynamic>;
    }
    try {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      for (final kind in ['failure', 'dynamic', 'cancel']) {
        final actual = await stimulus(kind);
        expect(actual['fixtureMounted'], true);
        expect(actual['providerCalls'], 1);
        expect(await read(), kind != 'cancel');
        await tester.pump(const Duration(seconds: 3));
        final restored = await stimulus('cleanup');
        expect(restored['fixtureMounted'], false);
        expect(restored['toastTexts'], isEmpty);
        expect(find.byType(LoginSheet), findsNothing);
        expect(await read(), false);
      }
    } finally {
      await tester.pump(const Duration(seconds: 3));
      await stimulus('cleanup');
      await tester.pumpWidget(const SizedBox.shrink());
      await bridge.close();
    }
    expect(renderedToastElements(), isEmpty);
    expect(QaBridge.current, isNull);
  }, skip: const String.fromEnvironment('GENESIS_API_ENV') != 'mock');
  test('rejects mutations and contract misuse before touching UI', () async {
    await expectLater(readLoginFailureNotice({'prepare': true}, false, true), throwsArgumentError);
    expect(await readLoginFailureNotice({}, false, false), false);
    await expectLater(loginFailureContractFixture({'kind': 'failure'}, false, true), throwsStateError);
    await expectLater(loginFailureContractFixture({'kind': 'failure'}, true, false), throwsStateError);
  });
}
