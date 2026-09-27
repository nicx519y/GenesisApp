import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_network_recovery.dart';

void main() {
  test(
    'network recovery runs once for each offline-to-online transition',
    () async {
      final network = StreamController<bool>.broadcast(sync: true);
      var attempts = 0;
      final trigger = AdjustNetworkRecoveryTrigger(
        availability: network.stream,
        recover: () async {
          attempts++;
        },
        debounce: const Duration(milliseconds: 1),
      );

      network.add(true);
      network.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(attempts, 1);

      network.add(false);
      network.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(attempts, 2);

      trigger.setForeground(false);
      network.add(false);
      network.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(attempts, 2);

      await trigger.dispose();
      await network.close();
    },
  );

  test(
    'a recovery transition during an active attempt is drained once',
    () async {
      final network = StreamController<bool>.broadcast(sync: true);
      final firstAttempt = Completer<void>();
      var attempts = 0;
      final trigger = AdjustNetworkRecoveryTrigger(
        availability: network.stream,
        recover: () async {
          attempts++;
          if (attempts == 1) await firstAttempt.future;
        },
        debounce: const Duration(milliseconds: 1),
      );

      network.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      network.add(false);
      network.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(attempts, 1);

      firstAttempt.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(attempts, 2);

      await trigger.dispose();
      await network.close();
    },
  );
}
