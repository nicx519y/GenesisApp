import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_throttled_image_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('limits Worldo cover loading to four concurrent operations', () async {
    final limiter = OriginItemCoverLoadLimiter(
      maxConcurrentLoads: originItemCoverMaxConcurrentLoads,
    );
    final gates = List<Completer<void>>.generate(6, (_) => Completer<void>());
    final started = <int>[];
    var activeLoads = 0;
    var peakActiveLoads = 0;

    final loads = <Future<void>>[
      for (var index = 0; index < gates.length; index += 1)
        limiter.schedule(() async {
          started.add(index);
          activeLoads += 1;
          if (activeLoads > peakActiveLoads) peakActiveLoads = activeLoads;
          try {
            await gates[index].future;
          } finally {
            activeLoads -= 1;
          }
        }),
    ];

    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 1, 2, 3]);
    expect(peakActiveLoads, originItemCoverMaxConcurrentLoads);

    gates[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 1, 2, 3, 5]);
    expect(peakActiveLoads, originItemCoverMaxConcurrentLoads);

    gates[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 1, 2, 3, 5, 4]);
    expect(peakActiveLoads, originItemCoverMaxConcurrentLoads);

    for (final gate in gates.skip(2)) {
      gate.complete();
    }
    await Future.wait(loads);
    expect(activeLoads, 0);
  });

  test('bounds the queue and cancels the oldest pending request', () async {
    final limiter = OriginItemCoverLoadLimiter(
      maxConcurrentLoads: 1,
      maxPendingLoads: 2,
    );
    final gates = List<Completer<void>>.generate(4, (_) => Completer<void>());
    final started = <int>[];

    Future<void> schedule(int index) {
      return limiter.schedule(() async {
        started.add(index);
        await gates[index].future;
      });
    }

    final active = schedule(0);
    final superseded = schedule(1);
    final supersededExpectation = expectLater(
      superseded,
      throwsA(isA<OriginItemCoverLoadCancelledException>()),
    );
    final older = schedule(2);
    final latest = schedule(3);
    await Future<void>.delayed(Duration.zero);

    expect(started, <int>[0]);
    expect(limiter.activeLoadCount, 1);
    expect(limiter.pendingLoadCount, 2);
    await supersededExpectation;

    gates[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 3]);

    gates[3].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 3, 2]);

    gates[2].complete();
    await Future.wait(<Future<void>>[active, older, latest]);
    expect(limiter.activeLoadCount, 0);
    expect(limiter.pendingLoadCount, 0);
  });

  test('removes a pending cover when its card leaves the tree', () async {
    final limiter = OriginItemCoverLoadLimiter(
      maxConcurrentLoads: 1,
      maxPendingLoads: 2,
    );
    final activeGate = Completer<void>();
    final active = limiter.schedule(() => activeGate.future);
    final cancellationToken = OriginItemCoverLoadCancellationToken();
    final pending = limiter.schedule(
      () async => 1,
      cancellationToken: cancellationToken,
    );
    final pendingExpectation = expectLater(
      pending,
      throwsA(isA<OriginItemCoverLoadCancelledException>()),
    );

    expect(limiter.pendingLoadCount, 1);
    cancellationToken.cancel();
    await pendingExpectation;
    expect(limiter.pendingLoadCount, 0);

    activeGate.complete();
    await active;
    expect(limiter.activeLoadCount, 0);
  });

  test('times out a cover that never produces its first frame', () async {
    final limiter = OriginItemCoverLoadLimiter(
      maxConcurrentLoads: 1,
      maxPendingLoads: 1,
    );
    final provider = OriginItemCoverThrottledImageProvider(
      sourceProvider: const _NeverCompletingImageProvider(),
      loadLimiter: limiter,
      loadTimeout: const Duration(milliseconds: 10),
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final error = Completer<Object>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {},
      onError: (Object caught, StackTrace? stackTrace) {
        if (!error.isCompleted) error.complete(caught);
      },
    );
    stream.addListener(listener);

    expect(await error.future, isA<TimeoutException>());
    stream.removeListener(listener);
    await Future<void>.delayed(Duration.zero);
    expect(limiter.activeLoadCount, 0);
  });

  test('cancels an active cover when its card leaves the tree', () async {
    final limiter = OriginItemCoverLoadLimiter(
      maxConcurrentLoads: 1,
      maxPendingLoads: 1,
    );
    final cancellationToken = OriginItemCoverLoadCancellationToken();
    final provider = OriginItemCoverThrottledImageProvider(
      sourceProvider: const _NeverCompletingImageProvider(),
      loadLimiter: limiter,
      cancellationToken: cancellationToken,
      loadTimeout: const Duration(seconds: 1),
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final error = Completer<Object>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {},
      onError: (Object caught, StackTrace? stackTrace) {
        if (!error.isCompleted) error.complete(caught);
      },
    );
    stream.addListener(listener);
    await Future<void>.delayed(Duration.zero);

    cancellationToken.cancel();
    expect(await error.future, isA<OriginItemCoverLoadCancelledException>());
    stream.removeListener(listener);
    await Future<void>.delayed(Duration.zero);
    expect(limiter.activeLoadCount, 0);
  });
}

@immutable
class _NeverCompletingImageProvider
    extends ImageProvider<_NeverCompletingImageProvider> {
  const _NeverCompletingImageProvider();

  @override
  Future<_NeverCompletingImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<_NeverCompletingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _NeverCompletingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}
