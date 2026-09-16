import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_global_config.dart';
import 'package:genesis_flutter_android/app/onboarding/personalization_store.dart';
import 'package:genesis_flutter_android/app/startup/startup_app_config.dart';
import 'package:genesis_flutter_android/app/startup/startup_uid_resolution.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_gate.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/network/api_request_trace_sampling.dart';

import '../../support/personalization_fixtures.dart';

void main() {
  setUp(ApiRequestTraceSampling.resetForTesting);
  tearDown(ApiRequestTraceSampling.resetForTesting);

  for (final result in [
    'enabled',
    'enabled_while_inactive',
    'disabled',
    'failure',
  ]) {
    testWidgets('first frame does not wait for background config: $result', (
      tester,
    ) async {
      final collectReady = Completer<void>();
      final uid = Completer<StartupUidResolution>();
      final response = Completer<Map<String, dynamic>>();
      final formEnabled = result.startsWith('enabled');
      var configCalls = 0;
      String? requestedUid;
      final config = AppGlobalConfigStore(
        loadConfig: ({String? uid}) {
          configCalls++;
          requestedUid = uid;
          return response.future;
        },
      );
      var profileCalls = 0;
      final personalization = PersonalizationStore(
        readLoginUid: () async => 'startup-user',
        load: () async {
          profileCalls++;
          return personalizationData();
        },
        save: (profile) async => profile,
      );
      final loading = loadStartupAppConfig(
        store: config,
        uidResolution: uid.future,
        collectReady: collectReady.future,
      );
      final navigator = GlobalKey<NavigatorState>();
      var firstFrame = false;
      tester.binding.addPostFrameCallback((_) => firstFrame = true);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            store: personalization,
            appConfig: config,
            navigatorKey: navigator,
            child: child!,
          ),
          home: const Scaffold(body: Text('Cached home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(firstFrame, isTrue);
      expect(find.text('Cached home'), findsOneWidget);
      expect(config.requestState.value.isLoading, isTrue);
      expect(configCalls, 0);
      expect(profileCalls, 0);

      collectReady.complete();
      await tester.pump();
      expect(configCalls, 0);
      uid.complete(
        const StartupUidResolution(uid: 'startup-user', status: 'signed_in'),
      );
      await tester.pump();
      expect(configCalls, 1);
      expect(requestedUid, 'startup-user');
      // A slow response must still apply flags and sampling after first frame.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Cached home'), findsOneWidget);
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(profileCalls, 0);
      if (result == 'enabled_while_inactive') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      if (result == 'failure') {
        response.completeError(StateError('network unavailable'));
      } else {
        response.complete({
          'show_personalization_form': formEnabled,
          'api_trace_sampling_rate': 1,
        });
      }
      await tester.pumpAndSettle();
      await loading;
      if (result == 'enabled_while_inactive') {
        expect(find.byType(PersonalizationSheet), findsNothing);
        expect(profileCalls, 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }
      expect(config.requestState.value.isLoading, isFalse);
      expect(configCalls, 1);
      expect(profileCalls, formEnabled ? 1 : 0);
      expect(
        find.byType(PersonalizationSheet),
        formEnabled ? findsOneWidget : findsNothing,
      );
      expect(ApiRequestTraceSampling.enabledForLaunch, result != 'failure');
      expect(config.requestState.value.error != null, result == 'failure');
      await tester.pumpWidget(const SizedBox.shrink());
      personalization.dispose();
      config.dispose();
    });
  }
}
