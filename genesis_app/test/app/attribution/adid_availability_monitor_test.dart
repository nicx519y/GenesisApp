import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/app/attribution/adid_availability_monitor.dart';

void observe(AdidAvailabilityMonitor monitor, bool available) =>
    monitor.observe(
      available: available,
      adjustId: available ? 'adjust' : '',
      nativeId: available ? 'native' : '',
      appInstanceId: 'instance',
    );

void main() {
  test('default reporter queues the paired event fields', () async {
    final store = MemoryCollectEventStore();
    GenesisTelemetry.setCollectUploaderForTesting(
      CollectTelemetryUploader(store: store)..configure(enabled: true),
    );
    addTearDown(GenesisTelemetry.resetForTesting);
    final monitor = AdidAvailabilityMonitor();
    observe(monitor, false);
    observe(monitor, true);
    await monitor.whenIdle;
    expect(
      store.eventsForTesting.map(
        (event) => (
          event.actionType,
          event.action,
          event.object1,
          event.object2,
          event.object3,
        ),
      ),
      [
        ('monitor', 'get_adid_failed', '', '', 'instance'),
        ('monitor', 'get_adid_success', 'adjust', 'native', 'instance'),
      ],
    );
  });

  test(
    'healthy launch has no event; one pair only even after another failure',
    () async {
      final events = <String>[];
      final monitor = AdidAvailabilityMonitor(
        report: (action, a, n, f) async {
          events.add(action);
          return true;
        },
      );
      observe(monitor, true);
      await monitor.whenIdle;
      expect(events, isEmpty);
      observe(monitor, false);
      observe(monitor, false);
      observe(monitor, true);
      observe(monitor, false);
      observe(monitor, true);
      await monitor.whenIdle;
      expect(events, ['get_adid_failed', 'get_adid_success']);
      expect(monitor.shouldCaptureNative, isFalse);
    },
  );

  test(
    'recovery waits for failure enqueue and carries the raw identifiers',
    () async {
      final accepted = Completer<bool>();
      final events = <List<String>>[];
      final monitor = AdidAvailabilityMonitor(
        report: (action, a, n, f) async {
          events.add([action, a, n, f]);
          return action == 'get_adid_failed' ? accepted.future : true;
        },
      );
      observe(monitor, false);
      expect(monitor.shouldCaptureNative, isTrue);
      observe(monitor, true);
      await Future<void>.delayed(Duration.zero);
      expect(events, [
        ['get_adid_failed', '', '', 'instance'],
      ]);
      accepted.complete(true);
      await monitor.whenIdle;
      expect(events.last, ['get_adid_success', 'adjust', 'native', 'instance']);
    },
  );

  test(
    'failed enqueue cannot produce an orphan success; next failure can retry',
    () async {
      final events = <String>[];
      var accepted = false;
      final monitor = AdidAvailabilityMonitor(
        report: (action, a, n, f) async {
          events.add(action);
          return accepted;
        },
      );
      observe(monitor, false);
      await monitor.whenIdle;
      observe(monitor, true);
      await monitor.whenIdle;
      expect(events, ['get_adid_failed']);
      accepted = true;
      observe(monitor, false);
      observe(monitor, true);
      await monitor.whenIdle;
      expect(events, [
        'get_adid_failed',
        'get_adid_failed',
        'get_adid_success',
      ]);
    },
  );

  test(
    'success enqueue failure is retried but failure is not duplicated',
    () async {
      var acceptRecovery = false;
      final events = <String>[];
      final monitor = AdidAvailabilityMonitor(
        report: (action, a, n, f) async {
          events.add(action);
          return action == 'get_adid_failed' || acceptRecovery;
        },
      );
      observe(monitor, false);
      observe(monitor, true);
      await monitor.whenIdle;
      expect(monitor.shouldCaptureNative, isTrue);
      acceptRecovery = true;
      observe(monitor, false);
      observe(monitor, true);
      await monitor.whenIdle;
      expect(events, [
        'get_adid_failed',
        'get_adid_success',
        'get_adid_success',
      ]);
    },
  );

  test('fresh launch does not inherit an earlier failure', () async {
    final events = <String>[];
    Future<bool> report(String action, String a, String n, String f) async {
      events.add(action);
      return true;
    }

    final previous = AdidAvailabilityMonitor(report: report);
    observe(previous, false);
    await previous.whenIdle;
    final nextLaunch = AdidAvailabilityMonitor(report: report);
    observe(nextLaunch, true);
    await nextLaunch.whenIdle;
    expect(events, ['get_adid_failed']);
  });
}
