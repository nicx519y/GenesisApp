import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:genesis_flutter_android/network/chatroom/location_chat_send_gate.dart';

void main() {
  LocationChatSendGate gate(FakeAsync clock) => LocationChatSendGate(
    now: () => DateTime(2026).add(clock.elapsed),
    report: (_) {},
  );
  ChatSendOperation start(
    LocationChatSendGate gate,
    String id, {
    String scene = 'send',
  }) =>
      gate.begin(worldId: 'w', locationId: 'l', operationId: id, scene: scene);

  test(
    '10000 completed identities retain no runtime or owner subscriptions',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final owner = ChatSendReleaseScope();
        for (var i = 0; i < 10000; i++) {
          final op = start(manager, '$i');
          op.diagnostics['round_id'] = '$i';
          op.stream('m', i);
          owner.listen(op, () => fail('normal completion must not release'));
          op.finish();
        }
        final resources = manager.debugResources;
        expect(resources.history, 10000);
        expect(resources.active, 0);
        expect(resources.progressStates, 0);
        expect(resources.progressKeys, 0);
        expect(resources.listeners, 0);
        expect(resources.guards, 0);
        expect(resources.timer, false);
        expect(owner.debugListenerCount, 0);
        final retained = manager.find('w', 'l', '42')!;
        expect(identical(start(manager, '42'), retained), true);
        expect(identical(manager.forRound('w', 'l', '42'), retained), true);
        expect(retained.finished, true);
        expect(
          retained.streaming,
          true,
        ); // terminal snapshot remains compatible
        final active = start(manager, 'new');
        active.progress('ack');
        expect(manager.debugResources.scheduleScans, 1);
        manager.updateConnection('w', connected: true, joining: false);
        clock.elapse(const Duration(seconds: 45));
        expect(active.released, true);
        expect(manager.debugResources.progressStates, 0);
        manager.dispose();
      });
    },
  );

  test(
    'presentation frames allocate no progress keys and cannot extend network wait',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final visual = start(manager, 'visual', scene: 'reply_presentation');
        final network = start(manager, 'network');
        network.stream('m', 1);
        for (var i = 0; i < 100000; i++) {
          visual.presentationProgress();
          network.presentationProgress();
        }
        expect(manager.debugResources.progressKeys, 1);
        clock.elapse(const Duration(seconds: 4));
        visual.presentationProgress();
        network.presentationProgress();
        clock.elapse(const Duration(seconds: 1));
        expect(network.released, true);
        expect(visual.blocks, true);
        clock.elapse(const Duration(seconds: 39));
        expect(visual.blocks, true);
        clock.elapse(const Duration(seconds: 5));
        expect(visual.released, true);
        expect(manager.debugResources.progressKeys, 0);
        manager.dispose();
      });
    },
  );

  test(
    'guard unregisters on success/error without retaining completed values',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final op = start(manager, 'a');
        var sum = 0;
        var errors = 0;
        for (var i = 0; i < 1000; i++) {
          op.guard(Future.value(1)).then((value) => sum += value);
          op
              .guard(Future<int>.error(StateError('expected')))
              .then<void>(
                (_) => fail('expected error'),
                onError: (Object _) {
                  errors++;
                },
              );
        }
        clock.flushMicrotasks();
        expect(sum, 1000);
        expect(errors, 1000);
        expect(manager.debugResources.guards, 0);
        expect(op.blocks, true);
        op.finish();
        manager.dispose();
      });
    },
  );

  test(
    'finish before ACK preserves its result; late failure is still delivered',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final op = start(manager, 'a');
        final ack = Completer<int>();
        final echo = Completer<int>();
        int? value;
        Object? error;
        op.guard(ack.future).then((v) => value = v);
        op
            .guard(echo.future)
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        op.finish();
        expect(manager.debugResources.guards, 0);
        expect(manager.debugResources.timer, false);
        ack.complete(7);
        echo.completeError(StateError('late transport error'));
        clock.flushMicrotasks();
        expect(value, 7);
        expect(error, isA<StateError>());
        expect(op.released, false);
        manager.dispose();
      });
    },
  );

  test('timeout clears guards and consumes late original errors once', () {
    fakeAsync((clock) {
      final manager = gate(clock);
      final op = start(manager, 'a');
      final ack = Completer<void>();
      var errors = 0;
      Object? error;
      op
          .guard(ack.future)
          .then<void>(
            (_) => fail('expected cancellation'),
            onError: (Object e) {
              errors++;
              error = e;
            },
          );
      clock.elapse(const Duration(seconds: 45));
      expect(error, isA<ChatSendWaitReleased>());
      expect(manager.debugResources.guards, 0);
      ack.completeError(StateError('late'));
      clock.flushMicrotasks();
      expect(errors, 1);
      manager.dispose();
    });
  });

  test(
    'already released guard handles original failures and scope cancels idempotently',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final op = start(manager, 'a');
        var calls = 0;
        final cancel = op.onRelease(() => calls++);
        cancel();
        cancel();
        op.releaseLocalWait();
        final cancelLate = op.onRelease(() => calls++);
        cancelLate();
        expect(calls, 1);
        Object? error;
        op
            .guard(Future<void>.error(StateError('original')))
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        clock.flushMicrotasks();
        expect(error, isA<ChatSendWaitReleased>());
        expect(manager.debugResources.listeners, 0);
        manager.dispose();
      });
    },
  );

  for (final release in [false, true]) {
    for (final earlyFinally in [false, true]) {
      test('handoff terminal release=$release earlyFinally=$earlyFinally', () {
        fakeAsync((clock) {
          final manager = gate(clock);
          final preparation = start(manager, 'prepare');
          final request = start(manager, 'request');
          final result = Completer<int>();
          int? value;
          Object? error;
          var cleaned = 0;
          preparation.onRelease(() => cleaned++);
          preparation
              .guard(result.future)
              .then<void>(
                (v) {
                  value = v;
                },
                onError: (Object e) {
                  error = e;
                },
              );
          preparation.handoffTo(request);
          if (earlyFinally) preparation.finish();
          expect(manager.debugResources.progressStates, 1);
          expect(manager.debugResources.active, 1);
          if (release) {
            request.releaseLocalWait();
          } else {
            request.finish();
          }
          clock.flushMicrotasks();
          expect(manager.debugResources.guards, 0);
          expect(manager.debugResources.handoffs, 0);
          expect(manager.debugResources.listeners, 0);
          expect(preparation.released, release);
          expect(cleaned, release && !earlyFinally ? 1 : 0);
          if (release) {
            expect(error, isA<ChatSendWaitReleased>());
          } else {
            expect(error, isNull);
          }
          result.complete(9);
          clock.flushMicrotasks();
          expect(value, release ? null : 9);
          manager.dispose();
        });
      });
    }
  }

  test(
    'nested handoff preserves cancellation without retaining terminated preparation',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final first = start(manager, 'first');
        final second = start(manager, 'second');
        final third = start(manager, 'third');
        first.handoffTo(second);
        second.handoffTo(third);
        Object? error;
        first
            .guard(Completer<void>().future)
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        third.releaseLocalWait();
        clock.flushMicrotasks();
        expect(error, isA<ChatSendWaitReleased>());
        expect(first.released, true);
        expect(second.released, true);
        expect(manager.debugResources.guards, 0);
        expect(manager.debugResources.handoffs, 0);
        manager.dispose();
      });
    },
  );

  test('disposing an owner leaves deadline for a replacement owner', () {
    fakeAsync((clock) {
      final manager = gate(clock);
      final first = ChatSendReleaseScope();
      final second = ChatSendReleaseScope();
      final op = start(manager, 'same');
      var oldCalls = 0;
      var newCalls = 0;
      first.listen(op, () => oldCalls++);
      clock.elapse(const Duration(seconds: 40));
      first.clear();
      second.listen(start(manager, 'same'), () => newCalls++);
      clock.elapse(const Duration(seconds: 5));
      expect(oldCalls, 0);
      expect(newCalls, 1);
      expect(first.debugListenerCount, 0);
      expect(second.debugListenerCount, 0);
      expect(identical(start(manager, 'same'), op), true);
      expect(start(manager, 'same').released, true);
      manager.dispose();
    });
  });

  test('finish inside release still notifies remaining live owners', () {
    fakeAsync((clock) {
      final manager = gate(clock);
      final op = start(manager, 'a');
      var calls = 0;
      op.onRelease(() {
        calls++;
        op.finish();
      });
      op.onRelease(() => calls++);
      op.releaseLocalWait();
      expect(calls, 2);
      expect(manager.debugResources.listeners, 0);
      manager.dispose();
    });
  });

  test(
    'release callbacks may unsubscribe/reset/create without affecting next session',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final op = start(manager, 'old');
        final other = start(manager, 'other');
        var oldCalls = 0;
        late void Function() cancel;
        op.onRelease(() {
          cancel();
          manager.reset();
          start(manager, 'fresh');
        });
        cancel = op.onRelease(() => oldCalls++);
        other.onRelease(() {
          start(manager, 'during-reset');
        });
        op.releaseLocalWait();
        expect(oldCalls, 0);
        expect(manager.find('w', 'l', 'old'), isNull);
        expect(manager.find('w', 'l', 'during-reset'), isNull);
        expect(manager.debugResources.active, 1);
        expect(start(manager, 'fresh').blocks, true);
        manager.reset();
        expect(manager.debugResources.history, 0);
        expect(manager.debugResources.active, 0);
        expect(manager.debugResources.timer, false);
        manager.dispose();
      });
    },
  );
  test(
    'reset during notification skips remaining old listeners and Tick registration',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final op = start(manager, 'old');
        final other = start(manager, 'other');
        var staleCalls = 0;
        op.onRelease(() {
          manager.reset();
          start(manager, 'new');
        });
        op.onRelease(() => staleCalls++);
        other.onRelease(() => manager.beginTick('w'));
        op.releaseLocalWait();
        expect(staleCalls, 0);
        expect(manager.debugResources.history, 1);
        expect(manager.beginTick('w').blocks, true);
        manager.dispose();
      });
    },
  );

  test('dispose inside a release callback is safe and skips old listeners', () {
    fakeAsync((clock) {
      final manager = gate(clock);
      final op = start(manager, 'old');
      var staleCalls = 0;
      op.onRelease(manager.dispose);
      op.onRelease(() => staleCalls++);
      op.releaseLocalWait();
      expect(staleCalls, 0);
      expect(manager.debugResources.history, 0);
      expect(manager.debugResources.timer, false);
    });
  });

  test(
    'synchronous futures do not retain guards or bypass released identity',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final op = start(manager, 'sync');
        int? value;
        op.guard(SynchronousFuture(3)).then((v) => value = v);
        expect(manager.debugResources.guards, 0);
        clock.flushMicrotasks();
        expect(value, 3);
        op.releaseLocalWait();
        Object? error;
        op
            .guard(SynchronousFuture(4))
            .then<void>(
              (_) => fail('must remain released'),
              onError: (Object e) {
                error = e;
              },
            );
        clock.flushMicrotasks();
        expect(error, isA<ChatSendWaitReleased>());
        manager.dispose();
      });
    },
  );

  test(
    'handoff request failure frees registrations and returns original error',
    () {
      fakeAsync((clock) {
        final manager = gate(clock);
        final preparation = start(manager, 'prepare');
        final request = start(manager, 'request');
        final original = Completer<void>();
        final expected = StateError('request failed');
        Object? error;
        preparation
            .guard(original.future)
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        preparation.handoffTo(request);
        request.finish();
        preparation.finish();
        original.completeError(expected);
        clock.flushMicrotasks();
        expect(error, same(expected));
        expect(manager.debugResources.guards, 0);
        expect(manager.debugResources.handoffs, 0);
        expect(manager.debugResources.listeners, 0);
        manager.dispose();
      });
    },
  );
}
