import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_throttled_image_provider.dart';

void main() {
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
    expect(started, <int>[0, 1, 2, 3, 4]);
    expect(peakActiveLoads, originItemCoverMaxConcurrentLoads);

    gates[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 1, 2, 3, 4, 5]);
    expect(peakActiveLoads, originItemCoverMaxConcurrentLoads);

    for (final gate in gates.skip(2)) {
      gate.complete();
    }
    await Future.wait(loads);
    expect(activeLoads, 0);
  });
}
