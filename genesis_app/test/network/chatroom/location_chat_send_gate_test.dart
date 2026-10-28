import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/location_chat_send_gate.dart';

void main() {
  LocationChatSendGate gate(
    FakeAsync clock,
    List<Map<String, Object?>> events,
  ) => LocationChatSendGate(
    now: () => DateTime(2026).add(clock.elapsed),
    report: events.add,
  );
  ChatSendOperation start(
    LocationChatSendGate gate, {
    String id = 'a',
    String scene = 'send',
    bool tick = false,
  }) => gate.begin(
    worldId: 'w',
    locationId: 'l',
    operationId: id,
    scene: scene,
    tick: tick,
  );
  Map<String, dynamic> details(Map<String, Object?> event) =>
      jsonDecode(event['ext_data']! as String) as Map<String, dynamic>;

  test(
    'scene configuration drives scheduling, reporting and release independently',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = LocationChatSendGate(
          now: () => DateTime(2026).add(clock.elapsed),
          report: events.add,
          sceneConfigs: const {
            'custom': ChatSendTimeoutConfig(
              warningAfter: Duration(seconds: 2),
              waitAfter: Duration(seconds: 3),
            ),
          },
        );
        final normal = start(manager);
        final custom = start(manager, id: 'custom', scene: 'custom');
        clock.elapse(const Duration(seconds: 2));
        expect(events.single['object3'], 'custom');
        expect(details(events.single)['report_after_ms'], 2000);
        expect(details(events.single)['release_after_ms'], 3000);
        expect(custom.blocks, isTrue);
        clock.elapse(const Duration(seconds: 1));
        expect(custom.released, isTrue);
        expect(normal.blocks, isTrue);
        clock.elapse(const Duration(seconds: 17));
        expect(normal.released, isTrue);
        manager.dispose();
      });
    },
  );

  test(
    'explicit terminal release cleans up once without timeout telemetry',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final op = start(manager);
        var cleaned = 0;
        var notified = 0;
        op.onRelease(() => cleaned++);
        manager.addListener(() => notified++);
        op.releaseLocalWait();
        op.releaseLocalWait();
        op.stream('late', 1);
        clock.elapse(const Duration(minutes: 1));
        expect(manager.blocks('w', 'l'), isFalse);
        expect(cleaned, 1);
        expect(notified, 1);
        expect(events, isEmpty);
        manager.dispose();
      });
    },
  );

  test(
    'waiting warns once at 15s and releases at 20s without another report',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final op = start(manager);
        clock.elapse(const Duration(seconds: 14));
        expect(events, isEmpty);
        clock.elapse(const Duration(seconds: 1));
        expect(events.single['action_type'], 'chat_timeout');
        expect(events.single['object4'], '15000');
        expect(details(events.single)['reason'], 'wait_stalled');
        expect(op.blocks, isTrue);
        clock.elapse(const Duration(seconds: 5));
        expect(op.released, isTrue);
        expect(events, hasLength(1));
        manager.dispose();
      });
    },
  );

  test(
    'only distinct progress refreshes waiting, unrelated operations do not',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final first = start(manager);
        final second = start(manager, id: 'b');
        clock.elapse(const Duration(seconds: 10));
        second.progress('ack');
        clock.elapse(const Duration(seconds: 5));
        second.progress('ack'); // Duplicate ACK cannot extend the deadline.
        clock.elapse(const Duration(seconds: 5));
        expect(first.released, isTrue);
        expect(second.blocks, isTrue);
        clock.elapse(const Duration(seconds: 10));
        expect(second.released, isTrue);
        manager.dispose();
      });
    },
  );

  test('stream start without chunks releases at 5s, not 20s', () {
    fakeAsync((clock) {
      final events = <Map<String, Object?>>[];
      final manager = gate(clock, events);
      final op = start(manager, scene: 'regenerate');
      op.stream('character', 'start');
      clock.elapse(const Duration(seconds: 4));
      expect(op.blocks, isTrue);
      clock.elapse(const Duration(seconds: 1));
      expect(op.released, isTrue);
      expect(details(events.single)['reason'], 'stream_stalled');
      expect(events.single['object3'], 'regenerate');
      manager.dispose();
    });
  });

  test('a warning and subsequent stalled stream are each reported once', () {
    fakeAsync((clock) {
      final events = <Map<String, Object?>>[];
      final manager = gate(clock, events);
      final op = start(manager, scene: 'go_on');
      clock.elapse(const Duration(seconds: 16));
      op.stream('m', 1); // A chunk without a start frame also starts streaming.
      clock.elapse(const Duration(seconds: 5));
      expect(events.map((e) => details(e)['reason']), [
        'wait_stalled',
        'stream_stalled',
      ]);
      op.stream('m', 2); // Late frames cannot revive the old lock.
      manager.reconcile();
      expect(op.released, isTrue);
      expect(events, hasLength(2));
      manager.dispose();
    });
  });

  test(
    'duplicate frames and nonstream progress cannot postpone stream expiry',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final op = start(manager);
        op.stream('m', 1);
        clock.elapse(const Duration(seconds: 4));
        op.stream('m', 1);
        op.progress('heartbeat');
        clock.elapse(const Duration(seconds: 1));
        expect(op.released, isTrue);
        manager.dispose();
      });
    },
  );

  test(
    'parallel character streams share activity; all ends return to ordinary waiting',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final op = start(manager);
        op.stream('a', 'start');
        op.stream('b', 'start');
        clock.elapse(const Duration(seconds: 4));
        op.stream('b', 0);
        op.stream('a', 'end', end: true);
        expect(op.streaming, isTrue);
        clock.elapse(const Duration(seconds: 4));
        op.stream('b', 1);
        op.stream('b', 'end', end: true);
        expect(op.streaming, isFalse);
        clock.elapse(const Duration(seconds: 14));
        expect(events, isEmpty);
        clock.elapse(const Duration(seconds: 6));
        expect(op.released, isTrue);
        expect(details(events.single)['reason'], 'wait_stalled');
        manager.dispose();
      });
    },
  );

  test('tick uses elapsed time and remains independent of stream expiry', () {
    fakeAsync((clock) {
      final events = <Map<String, Object?>>[];
      final manager = gate(clock, events);
      final tick = start(manager, id: 'tick', scene: 'tick', tick: true);
      final reply = start(manager);
      reply.stream('m', 1);
      clock.elapse(const Duration(seconds: 5));
      expect(reply.released, isTrue);
      expect(manager.blocks('w', 'another_location'), isTrue);
      clock.elapse(const Duration(seconds: 54));
      tick.progress('poll');
      expect(tick.blocks, isTrue);
      clock.elapse(const Duration(seconds: 1));
      expect(tick.released, isTrue);
      expect(events.last['object2'], '');
      expect(details(events.last)['reason'], 'tick_timeout');
      manager.dispose();
    });
  });

  test('rebinding same identity retains deadline and released tombstone', () {
    fakeAsync((clock) {
      final events = <Map<String, Object?>>[];
      final manager = gate(clock, events);
      final op = start(manager);
      clock.elapse(const Duration(seconds: 15));
      expect(identical(start(manager), op), isTrue);
      clock.elapse(const Duration(seconds: 5));
      expect(start(manager).released, isTrue);
      final next = start(manager, id: 'new');
      op.finish();
      expect(next.blocks, isTrue);
      manager.dispose();
    });
  });

  test(
    'normal completion cancels monitoring, reporter failure cannot prevent release',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        start(manager).finish();
        clock.elapse(const Duration(minutes: 2));
        expect(events, isEmpty);
        manager.dispose();
        final broken = LocationChatSendGate(
          now: () => DateTime(2026).add(clock.elapsed),
          report: (_) => throw StateError('queue'),
        );
        final op = start(broken);
        clock.elapse(const Duration(seconds: 20));
        expect(op.released, isTrue);
        broken.dispose();
      });
    },
  );
  test('one stream ending does not postpone another silent character', () {
    fakeAsync((clock) {
      final events = <Map<String, Object?>>[];
      final manager = gate(clock, events);
      final op = start(manager);
      op.stream('a', 'start');
      op.stream('b', 'start');
      clock.elapse(const Duration(seconds: 4));
      op.stream('a', 'end', end: true);
      clock.elapse(const Duration(seconds: 1));
      expect(op.released, isTrue);
      manager.dispose();
    });
  });

  test(
    'new generation replaces open streams and ignores old attempt frames',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final op = start(manager);
        op.stream('old', 1, generationKey: 'g', attemptNo: 1);
        clock.elapse(const Duration(seconds: 4));
        op.stream('new', 1, generationKey: 'g', attemptNo: 2);
        clock.elapse(const Duration(seconds: 4));
        op.stream('old', 2, generationKey: 'g', attemptNo: 1);
        clock.elapse(const Duration(seconds: 1));
        expect(op.released, isTrue);
        manager.dispose();
      });
    },
  );

  test(
    'preparation hands off its deadline and cleanup to the real request',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final preparation = start(manager, id: 'prepare');
        var cleaned = false;
        preparation.onRelease(() => cleaned = true);
        final request = start(manager, id: 'request', scene: 'regenerate');
        preparation.handoffTo(request);
        for (var i = 0; i < 15; i++) {
          request.stream('m', i);
          clock.elapse(const Duration(seconds: 4));
        }
        expect(cleaned, isFalse);
        expect(events, isEmpty);
        clock.elapse(const Duration(seconds: 1));
        expect(cleaned, isTrue);
        expect(events.single['object3'], 'regenerate');
        manager.dispose();
      });
    },
  );

  test(
    'world tick is shared, deduplicated and new tick has a fresh identity',
    () {
      fakeAsync((clock) {
        final events = <Map<String, Object?>>[];
        final manager = gate(clock, events);
        final first = manager.beginTick('w');
        clock.elapse(const Duration(seconds: 55));
        expect(identical(manager.beginTick('w'), first), isTrue);
        clock.elapse(const Duration(seconds: 5));
        expect(manager.beginTick('w').released, isTrue);
        manager.reconcile();
        expect(events, hasLength(1));
        first.finish();
        expect(manager.beginTick('w').operationId, isNot(first.operationId));
        manager.dispose();
      });
    },
  );
}
