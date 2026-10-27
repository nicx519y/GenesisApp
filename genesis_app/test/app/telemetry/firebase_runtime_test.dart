import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/privacy/privacy_consent_controller.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FirebaseRuntime.resetForTesting();
    privacyConsent.resetForTesting();
  });
  tearDown(() {
    FirebaseRuntime.resetForTesting();
    privacyConsent.resetForTesting();
  });

  test('Core initializes while privacy is unresolved', () async {
    SharedPreferences.setMockInitialValues({});
    await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
    var calls = 0;
    FirebaseRuntime.setInitializerForTesting(() async {
      calls++;
    });
    await FirebaseRuntime.ensureInitialized();
    expect(calls, 1);
    expect(privacyConsent.startupResolved, isFalse);
  });

  test(
    'shares one Firebase initialization across concurrent callers',
    () async {
      final initialization = Completer<void>();
      var calls = 0;
      FirebaseRuntime.setInitializerForTesting(() {
        calls += 1;
        return initialization.future;
      });

      final first = FirebaseRuntime.ensureInitialized();
      final second = FirebaseRuntime.ensureInitialized();

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      initialization.complete();
      await Future.wait(<Future<void>>[first, second]);
    },
  );

  test('allows a retry after Firebase initialization fails', () async {
    var calls = 0;
    FirebaseRuntime.setInitializerForTesting(() async {
      calls += 1;
      if (calls == 1) throw StateError('not ready');
    });

    await expectLater(
      FirebaseRuntime.ensureInitialized(),
      throwsA(isA<StateError>()),
    );
    await FirebaseRuntime.ensureInitialized();

    expect(calls, 2);
  });
}
