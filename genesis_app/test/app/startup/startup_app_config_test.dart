import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
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
  test(
    'restart restores Traditional Chinese from agreed server setting',
    () async {
      SharedPreferences.setMockInitialValues({});
      var serverLanguage = '';
      final first = AppLanguageController();
      await first.load();
      await first.select(
        const Locale('zh', 'TW'),
        saveLanguage: (language) async {
          expect(language, 'zh-TW');
          serverLanguage = 'zh-TW';
        },
      );
      final restarted = AppLanguageController();
      await restarted.load();
      expect(restarted.locale, const Locale('zh', 'TW'));
      final cachedDataRevision = restarted.dataRevision;
      final config = AppGlobalConfigStore(
        loadConfig: ({String? uid}) async => {'language': serverLanguage},
      );
      await loadStartupAppConfig(
        store: config,
        uidResolution: Future.value(
          const StartupUidResolution(uid: null, status: 'signed_out'),
        ),
        collectReady: Future.value(),
        languageController: restarted,
      );
      expect(restarted.locale, const Locale('zh', 'TW'));
      expect(restarted.settingLanguage, 'zh-TW');
      expect(restarted.dataRevision, cachedDataRevision);
      config.dispose();
    },
  );

  for (final result in ['', 'zh_TW', 'failure']) {
    test(
      'cached language survives empty invalid or failed config: $result',
      () async {
        SharedPreferences.setMockInitialValues({'app_language': 'zh-TW'});
        final languages = AppLanguageController();
        await languages.load();
        final dataRevision = languages.dataRevision;
        final config = AppGlobalConfigStore(
          loadConfig: ({String? uid}) async {
            if (result == 'failure') throw StateError('config unavailable');
            return {'language': result};
          },
        );
        await loadStartupAppConfig(
          store: config,
          uidResolution: Future.value(
            const StartupUidResolution(uid: null, status: 'signed_out'),
          ),
          collectReady: Future.value(),
          languageController: languages,
        );
        languages.applyUserLanguage('', requestRevision: languages.revision);
        expect(languages.settingLanguage, 'zh-TW');
        expect(languages.locale, const Locale('zh', 'TW'));
        expect(languages.dataRevision, dataRevision);
        config.dispose();
      },
    );
  }

  for (final language in ['zh-TW', 'zh_TW', '', 'failure']) {
    test('startup config language or system fallback: $language', () async {
      final languages = AppLanguageController();
      await languages.load();
      final config = AppGlobalConfigStore(
        loadConfig: ({String? uid}) async {
          if (language == 'failure') throw StateError('config unavailable');
          return {'language': language};
        },
      );
      await loadStartupAppConfig(
        store: config,
        uidResolution: Future.value(
          const StartupUidResolution(uid: null, status: 'signed_out'),
        ),
        collectReady: Future.value(),
        languageController: languages,
      );
      expect(languages.settingLanguage, language == 'zh-TW' ? 'zh-TW' : isNull);
      expect(
        languages.locale,
        language == 'zh-TW' ? const Locale('zh', 'TW') : isNull,
      );
      config.dispose();
    });
  }

  setUp(() {
    ApiRequestTraceSampling.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });
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
