import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/privacy/privacy_choices_store.dart';
import 'package:genesis_flutter_android/app/privacy/privacy_consent_controller.dart';
import 'package:genesis_flutter_android/app/config/app_global_config.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_attribution_runtime.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';
import 'package:genesis_flutter_android/app/telemetry/app_event_reporting.dart';

const accepted = PrivacyChoices(
  adStorage: true,
  adUserData: true,
  adPersonalization: false,
  analyticsStorage: true,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    privacyConsent.resetForTesting();
    AdjustAttributionRuntime.resetForTesting();
  });
  tearDown(() {
    privacyConsent.resetForTesting();
    AdjustAttributionRuntime.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.adjust.sdk/api'),
          null,
        );
  });
  test('settings denial sends Adjust zeros after restart', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.adjust.sdk/api'), (
          call,
        ) async {
          calls.add(call);
          return null;
        });
    await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
    await privacyConsent.save(accepted);
    await privacyConsent.save(PrivacyChoices.denied, fromSettings: true);
    for (var attempt = 0; attempt < 2; attempt++) {
      calls.clear();
      AdjustAttributionRuntime.applyPrivacyConsent();
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.single.arguments['granularOptions'],
        'google_dma__ADJ__eea__ADJ__1__ADJ__google_dma__ADJ__ad_user_data__ADJ__0__ADJ__google_dma__ADJ__ad_personalization__ADJ__0',
      );
      expect(
        jsonDecode(privacyConsent.registrationJson!),
        PrivacyChoices.denied.toJson(),
      );
      privacyConsent.resetForTesting();
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
    }
  });

  for (var mask = 0; mask < 4; mask++) {
    test('Adjust sends only granted advertising options: $mask', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.adjust.sdk/api'), (
            call,
          ) async {
            calls.add(call);
            return null;
          });
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      await privacyConsent.save(
        PrivacyChoices(
          adStorage: true,
          analyticsStorage: true,
          adUserData: mask & 1 != 0,
          adPersonalization: mask & 2 != 0,
        ),
      );
      AdjustAttributionRuntime.applyPrivacyConsent();
      await Future<void>.delayed(Duration.zero);
      if (mask == 0) {
        expect(calls, isEmpty);
      } else {
        expect(calls.single.method, 'trackThirdPartySharing');
        expect(
          calls.single.arguments['granularOptions'],
          [
            'google_dma__ADJ__eea__ADJ__1',
            if (mask & 1 != 0) 'google_dma__ADJ__ad_user_data__ADJ__1',
            if (mask & 2 != 0) 'google_dma__ADJ__ad_personalization__ADJ__1',
          ].join('__ADJ__'),
        );
      }
    });
  }
  test(
    'registration proceeds before privacy resolution and merges a late ADID',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      final reading = Completer<void>();
      final release = Completer<void>();
      final sent = <String>[];
      var reads = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async {
          reads++;
          return '';
        },
        readGoogleAdId: () async => '',
        readAppInstanceId: () async {
          if (!reading.isCompleted) {
            reading.complete();
            await release.future;
          }
          return null;
        },
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              sent.add(adid);
            },
      );
      final request = registration.register();
      await reading.future;
      final callback = registration.registerKnownAdid('late-adid');
      release.complete();
      await Future.wait([request, callback]);
      expect(sent, ['late-adid']);
      expect(reads, 1);
      registration.dispose();
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('saved rejection does not gate identifiers on $platform', () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      await privacyConsent.save(PrivacyChoices.denied);
      final sent = <Map<String, Object?>>[];
      final registration = AdjustDeviceRegistration(
        platform: platform,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adjust-id',
        readGoogleAdId: () async => 'google-id',
        readIdfa: () async => 'apple-ad-id',
        readIdfv: () async => 'vendor-id',
        readAppInstanceId: () async => 'analytics-id',
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              sent.add({
                'adid': adid,
                'gps_adid': gpsAdid,
                'idfa': idfa,
                'idfv': idfv,
                'app_instance_id': appInstanceId,
              });
            },
      );
      await registration.register();
      expect(sent.single['adid'], 'adjust-id');
      expect(sent.single['app_instance_id'], 'analytics-id');
      if (platform == TargetPlatform.android) {
        expect(sent.single['gps_adid'], 'google-id');
      } else {
        expect(sent.single['idfa'], 'apple-ad-id');
        expect(sent.single['idfv'], 'vendor-id');
      }
      registration.dispose();
    });
  }

  test(
    'region separates EEA parameter from presentation and handles unknown',
    () {
      for (final code in PrivacyRegion.eeaCountries) {
        expect(PrivacyRegion(code).eea, '1');
        expect(PrivacyRegion(code).needsPrompt, isTrue);
      }
      for (final code in ['GB', 'CH']) {
        expect(PrivacyRegion(code).eea, '0');
        expect(PrivacyRegion(code).needsPrompt, isTrue);
      }
      expect(const PrivacyRegion('US').needsPrompt, isFalse);
      expect(const PrivacyRegion(null).needsPrompt, isTrue);
      expect(const PrivacyRegion(null).eea, isNull);
    },
  );
  test(
    'only true enables config; pending/failure/disabled hide both entries',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      for (final value in [null, false, 1, 'true']) {
        final config = AppGlobalConfigStore(
          loadConfig: ({uid}) async => {'privacy_consent_enabled': value},
        );
        await config.refresh();
        expect(privacyConsent.shouldPrompt(config), isFalse);
        expect(privacyConsent.showSettings(config), isFalse);
        config.dispose();
      }
      final pending = Completer<Map<String, dynamic>>();
      final config = AppGlobalConfigStore(
        loadConfig: ({uid}) => pending.future,
      );
      final request = config.refresh();
      expect(privacyConsent.shouldPrompt(config), isFalse);
      pending.complete({'privacy_consent_enabled': true});
      await request;
      expect(privacyConsent.shouldPrompt(config), isTrue);
      expect(privacyConsent.showSettings(config), isTrue);
      config.dispose();
      final failure = AppGlobalConfigStore(
        loadConfig: ({uid}) async => throw StateError('offline'),
      );
      await expectLater(failure.refresh(), throwsStateError);
      expect(privacyConsent.shouldPrompt(failure), isFalse);
      expect(privacyConsent.showSettings(failure), isFalse);
      failure.dispose();
    },
  );
  test(
    'saved rejection survives restart, region changes, and disabled config',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      await privacyConsent.save(PrivacyChoices.denied);
      privacyConsent.resetForTesting();
      await privacyConsent.initialize(systemLocale: const Locale('en', 'US'));
      var enabled = true;
      final config = AppGlobalConfigStore(
        loadConfig: ({uid}) async => {'privacy_consent_enabled': enabled},
      );
      await config.refresh();
      expect(privacyConsent.shouldPrompt(config), isFalse);
      expect(privacyConsent.showSettings(config), isTrue);
      enabled = false;
      await config.refresh();
      expect(privacyConsent.showSettings(config), isFalse);
      privacyConsent.resolveStartup(config: config);
      expect(privacyConsent.choices!.toJson(), PrivacyChoices.denied.toJson());
      expect(
        jsonDecode(privacyConsent.registrationJson!),
        PrivacyChoices.denied.toJson(),
      );
      config.dispose();
    },
  );
  test(
    'resolving startup without a choice keeps unknown omitted and does not persist',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('en'));
      expect(privacyConsent.registrationJson, isNull);
      privacyConsent.resolveStartup();
      expect(await PrivacyChoicesStore.read(), isNull);
      privacyConsent.resetForTesting();
      await privacyConsent.initialize(systemLocale: const Locale('en'));
      expect(privacyConsent.startupResolved, isFalse);
    },
  );
  test(
    'Adjust waits for privacy and applies the choice before initialization',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.adjust.sdk/api'), (
            call,
          ) async {
            calls.add(call);
            return null;
          });
      await privacyConsent.initialize(systemLocale: const Locale('en', 'GB'));
      AdjustAttributionRuntime.initialize(debugMode: false);
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      await privacyConsent.save(accepted);
      privacyConsent.resolveStartup();
      AdjustAttributionRuntime.initialize(debugMode: false);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((c) => c.method), [
        'trackThirdPartySharing',
        'initSdk',
        'endFirstSessionDelay',
      ]);
      expect(
        calls.first.arguments['granularOptions'],
        'google_dma__ADJ__eea__ADJ__0__ADJ__google_dma__ADJ__ad_user_data__ADJ__1',
      );
      await privacyConsent.save(PrivacyChoices.denied);
      final previousCallCount = calls.length;
      AdjustAttributionRuntime.applyPrivacyConsent();
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(previousCallCount));
    },
  );
  for (final savedChoice in [accepted, PrivacyChoices.denied]) {
    test(
      'cached choice is queued before init and delay releases once: ${savedChoice.adUserData}',
      () async {
        await PrivacyChoicesStore.save(savedChoice);
        await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
        privacyConsent.resolveStartup();
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.adjust.sdk/api'),
              (call) async {
                calls.add(call);
                return null;
              },
            );
        AdjustAttributionRuntime.initialize(debugMode: false);
        await Future<void>.delayed(Duration.zero);
        expect(calls.map((call) => call.method), [
          if (savedChoice.adUserData) 'trackThirdPartySharing',
          'initSdk',
          'endFirstSessionDelay',
        ]);
        expect(
          calls
              .firstWhere((c) => c.method == 'initSdk')
              .arguments['isFirstSessionDelayEnabled'],
          'true',
        );
        if (savedChoice.adUserData) {
          expect(
            calls.first.arguments['granularOptions'],
            contains('ad_user_data__ADJ__1'),
          );
        }
        AdjustAttributionRuntime.applyPrivacyConsent();
        AdjustAttributionRuntime.initialize(debugMode: false);
        await Future<void>.delayed(Duration.zero);
        expect(
          calls.where((call) => call.method == 'endFirstSessionDelay'),
          hasLength(1),
        );
        expect(AdjustAttributionRuntime.isAwaitingFirstSessionPrivacy, isFalse);
      },
    );
  }

  for (final scenario in [
    'disabled',
    'outside region',
    'config failure',
    'not loaded yet',
  ]) {
    test('delay release handles no-choice startup: $scenario', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.adjust.sdk/api'), (
            call,
          ) async {
            calls.add(call);
            return null;
          });
      final loading = privacyConsent.initialize(
        systemLocale: Locale('en', scenario == 'outside region' ? 'US' : 'DE'),
      );
      if (scenario != 'not loaded yet') await loading;
      AdjustAttributionRuntime.initialize(debugMode: false);
      await loading;
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      expect(AdjustAttributionRuntime.hasAttemptedInitialization, isFalse);
      final config = AppGlobalConfigStore(
        loadConfig: ({uid}) async {
          if (scenario == 'config failure') throw StateError('offline');
          return {'privacy_consent_enabled': scenario == 'outside region'};
        },
      );
      addTearDown(config.dispose);
      if (scenario == 'config failure') {
        await expectLater(config.refresh(), throwsStateError);
      } else {
        await config.refresh();
      }
      privacyConsent.resolveStartup(config: config);
      AdjustAttributionRuntime.initialize(debugMode: false);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), [
        'initSdk',
        'endFirstSessionDelay',
      ]);
      expect(privacyConsent.registrationJson, isNull);
      expect(await PrivacyChoicesStore.read(), isNull);
    });
  }

  test(
    'deferred SDK initialization releases after a previously resolved skip',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('en', 'US'));
      privacyConsent.resolveStartup();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.adjust.sdk/api'), (
            call,
          ) async {
            calls.add(call);
            return null;
          });
      AdjustAttributionRuntime.applyPrivacyConsent();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      AdjustAttributionRuntime.initialize(debugMode: false);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), [
        'initSdk',
        'endFirstSessionDelay',
      ]);
    },
  );

  test(
    'registration drains changed choices after in-flight request and dedupes full snapshot',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      privacyConsent.resolveStartup();
      await privacyConsent.save(accepted);
      final first = Completer<void>();
      final sent = <String?>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'same-adid',
        readGoogleAdId: () async => '',
        readAppInstanceId: () async => null,
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              sent.add(privacyConsent);
              if (sent.length == 1) await first.future;
            },
      );
      final request = registration.register();
      while (sent.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await privacyConsent.save(PrivacyChoices.denied);
      final next = registration.register(force: true);
      first.complete();
      await Future.wait([request, next]);
      expect(sent.map((s) => jsonDecode(s!)), [
        accepted.toJson(),
        PrivacyChoices.denied.toJson(),
      ]);
      await registration.register();
      expect(sent, hasLength(2));
      registration.dispose();
    },
  );
  test(
    'changed choices refresh consent without blocking advertising IDs',
    () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      privacyConsent.resolveStartup();
      await privacyConsent.save(accepted);
      final reading = Completer<void>();
      final resumeRead = Completer<void>();
      final sent = <Map<String, Object?>>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => 'old-gaid',
        readAppInstanceId: () async {
          if (!reading.isCompleted) {
            reading.complete();
            await resumeRead.future;
          }
          return null;
        },
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              sent.add({
                'gps_adid': gpsAdid,
                'privacy_consent': privacyConsent,
              });
            },
      );
      final request = registration.register();
      await reading.future;
      await privacyConsent.save(PrivacyChoices.denied);
      resumeRead.complete();
      await request;
      expect(sent, hasLength(1));
      expect(sent.single['gps_adid'], 'old-gaid');
      expect(
        jsonDecode(sent.single['privacy_consent']! as String),
        PrivacyChoices.denied.toJson(),
      );
      registration.dispose();
    },
  );

  test(
    'Firebase server forwarding keeps original rules regardless of privacy choices',
    () async {
      const event = AppEventReport(
        event: 'purchase',
        environment: 'sandbox',
        occurredAtSeconds: 1,
        params: {},
        reportKey: 'purchase-1',
      );
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      expect(event.reportFirebase, isTrue);
      await privacyConsent.save(accepted);
      expect(event.reportFirebase, isTrue);
      await privacyConsent.save(PrivacyChoices.denied);
      expect(event.reportFirebase, isTrue);
    },
  );
}
