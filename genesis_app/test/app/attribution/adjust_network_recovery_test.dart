import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_network_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'network stream can resubscribe after cancellation and native end',
    () async {
      const channel = MethodChannel('com.worldo.ai/network_availability');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final first = NetworkAvailabilityEvents.changes.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await first.cancel();
      await Future<void>.delayed(Duration.zero);
      final ended = Completer<void>();
      NetworkAvailabilityEvents.changes.listen((_) {}, onDone: ended.complete);
      await Future<void>.delayed(Duration.zero);
      ServicesBinding.instance.channelBuffers.push(channel.name, null, (_) {});
      await ended.future;
      await Future<void>.delayed(Duration.zero);
      final last = NetworkAvailabilityEvents.changes.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((call) => call == 'listen'), hasLength(3));
      await last.cancel();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('network subscribers share one native listen and cancel', () async {
    const channel = MethodChannel('com.worldo.ai/network_availability');
    final listened = Completer<void>();
    final cancelled = Completer<void>();
    var listens = 0;
    var cancels = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listen') {
        listens++;
        listened.complete();
      } else if (call.method == 'cancel') {
        cancels++;
        cancelled.complete();
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final first = NetworkAvailabilityEvents.changes.listen((_) {});
    final second = NetworkAvailabilityEvents.changes.listen((_) {});
    await listened.future;
    expect(listens, 1);
    await first.cancel();
    expect(cancels, 0);
    await second.cancel();
    await cancelled.future;
    expect(cancels, 1);
  });

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
