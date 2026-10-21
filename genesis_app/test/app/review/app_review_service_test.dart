import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/review/app_review_service.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every attempt uses native in-app review and ignores legacy attempt flag',
    () async {
      SharedPreferences.setMockInitialValues({
        'rating_store_attempt_v1:u_native': true,
      });
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
      final service = AppReviewService(platform: TargetPlatform.android);
      expect(await service.requestFor('u_native'), AppReviewOutcome.completed);
      expect(await service.requestFor('u_native'), AppReviewOutcome.completed);
      await service.requestFor('another_owner');
      expect(calls, [
        'requestAppReview',
        'requestAppReview',
        'requestAppReview',
      ]);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform native failure never launches external URL and allows retry',
      () async {
        final calls = <String>[];
        var failRequest = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(GenesisMethodChannels.device, (
              call,
            ) async {
              calls.add(call.method);
              if (failRequest) {
                throw PlatformException(code: 'review_unavailable');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(GenesisMethodChannels.device, null),
        );
        final service = AppReviewService(platform: platform);
        await expectLater(
          service.requestFor('u1'),
          throwsA(isA<PlatformException>()),
        );
        failRequest = false;
        expect(
          await service.requestFor('u1'),
          platform == TargetPlatform.iOS
              ? AppReviewOutcome.deferred
              : AppReviewOutcome.completed,
        );
        expect(calls, ['requestAppReview', 'requestAppReview']);
      },
    );
  }

  test('iOS always requests in-app review and defers reward', () async {
    var requests = 0;
    final service = AppReviewService(
      platform: TargetPlatform.iOS,
      request: () async {
        requests++;
      },
    );
    expect(await service.requestFor('u1'), AppReviewOutcome.deferred);
    expect(await service.requestFor('u1'), AppReviewOutcome.deferred);
    expect(requests, 2);
  });

  test('concurrent requests hand off only once', () async {
    final pending = Completer<void>();
    var requests = 0;
    final service = AppReviewService(
      request: () {
        requests++;
        return pending.future;
      },
    );
    final first = service.requestFor('u1');
    await service.requestFor('u1');
    expect(requests, 1);
    pending.complete();
    await first;
  });

  test('inactive session prevents native request', () async {
    final service = AppReviewService(
      request: () async {
        fail('must not request');
      },
    );
    expect(await service.requestFor('u1', isCurrent: () => false), isNull);
  });
}
