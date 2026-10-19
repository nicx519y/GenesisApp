import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/review/app_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real channel wiring persists attempt per owner and skips native UI on retry',
    () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GenesisMethodChannels.device, (call) async {
            calls.add(call.method);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(GenesisMethodChannels.device, null),
      );
      final service = AppReviewService(
        platform: TargetPlatform.android,
        packageName: () async => 'com.worldo.ai',
        open: (_) async {
          calls.add('listing');
          return true;
        },
      );
      await service.requestFor('u_native');
      await service.requestFor('u_native');
      expect(calls, ['requestAppReview', 'listing']);
      await service.requestFor('another_owner');
      expect(calls.last, 'requestAppReview');
    },
  );

  test(
    'first request is persisted before API; silent completion never opens store',
    () async {
      final calls = <String>[];
      final service = AppReviewService(
        platform: TargetPlatform.android,
        readAttempt: (_) async => false,
        writeAttempt: (_) async => calls.add('saved'),
        request: () async => calls.add('requested'),
        open: (url) async {
          calls.add(url);
          return true;
        },
      );
      await service.requestFor('u1');
      expect(calls, ['saved', 'requested']);
    },
  );

  test('explicit request error tries native listing then HTTPS', () async {
    final urls = <String>[];
    final service = AppReviewService(
      platform: TargetPlatform.android,
      packageName: () async => 'com.worldo.ai',
      readAttempt: (_) async => false,
      writeAttempt: (_) async {},
      request: () async => throw StateError('request failed'),
      open: (url) async {
        urls.add(url);
        return url.startsWith('https:');
      },
    );
    await service.requestFor('u1');
    expect(urls, [
      'market://details?id=com.worldo.ai',
      'https://play.google.com/store/apps/details?id=com.worldo.ai',
    ]);
  });

  test('iOS request completion defers reward to next interaction', () async {
    final service = AppReviewService(
      platform: TargetPlatform.iOS,
      readAttempt: (_) async => false,
      writeAttempt: (_) async {},
      request: () async {},
    );
    expect(await service.requestFor('u1'), AppReviewOutcome.deferred);
  });

  test('later attempt opens listing without requesting review', () async {
    var requests = 0;
    final urls = <String>[];
    final service = AppReviewService(
      platform: TargetPlatform.iOS,
      readAttempt: (_) async => true,
      request: () async {
        requests++;
      },
      open: (url) async {
        urls.add(url);
        return true;
      },
    );
    await service.requestFor('u1');
    expect(requests, 0);
    expect(urls.single, contains('id6781946729?action=write-review'));
  });

  test('concurrent requests hand off only once', () async {
    final pending = Completer<void>();
    var requests = 0;
    final service = AppReviewService(
      readAttempt: (_) async => false,
      writeAttempt: (_) async {},
      request: () {
        requests++;
        return pending.future;
      },
    );
    final first = service.requestFor('u1');
    await Future<void>.delayed(Duration.zero);
    await service.requestFor('u1');
    expect(requests, 1);
    pending.complete();
    await first;
  });

  test('identity changed while saving prevents handoff', () async {
    var active = true;
    var requests = 0;
    final service = AppReviewService(
      readAttempt: (_) async => false,
      writeAttempt: (_) async {
        active = false;
      },
      request: () async {
        requests++;
      },
    );
    await service.requestFor('u1', isCurrent: () => active);
    expect(requests, 0);
  });

  test(
    'failed attempt persistence does not silently request or open store',
    () async {
      final service = AppReviewService(
        readAttempt: (_) async => false,
        writeAttempt: (_) async => throw StateError('disk full'),
        request: () async => fail('must not request'),
        open: (_) async {
          fail('must not open');
        },
      );
      await expectLater(service.requestFor('u1'), throwsStateError);
    },
  );
}
