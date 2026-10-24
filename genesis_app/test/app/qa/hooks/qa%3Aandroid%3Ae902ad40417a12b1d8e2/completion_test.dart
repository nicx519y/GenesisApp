import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../../../lib/app/qa/hooks/qa%253Aandroid%253Ae902ad40417a12b1d8e2/completion.dart';

void main() {
  test(
    'completion changes mapped round/time and events without corrupting snapshots',
    () {
      final before = <String, dynamic>{
        'info': {'world_id': 'owned', 'current_time': 'before'},
        'stats': {'tick_cnt': 8, 'sub_tick_no': 2, 'player_cnt': 3},
        'tick_list': [
          {'tick_no': 8},
        ],
      };
      final event = <String, dynamic>{
        'tick_no': 9,
        'tick_result': {'narrator': 'actual event'},
      };
      final after = completedResponse(before, 9, 'after', event);
      expect(after['stats']['tick_cnt'], 9);
      expect(after['stats']['sub_tick_no'], 0);
      expect(after['stats']['player_cnt'], 3);
      expect(after['info']['world_id'], 'owned');
      expect(after['info']['current_time'], 'after');
      expect(after['tick_list'], [event]);
      expect(before['stats']['tick_cnt'], 8);
      expect(before['info']['current_time'], 'before');
      expect(before['tick_list'], [
        {'tick_no': 8},
      ]);
      expect(
        () => completedResponse({'info': {}, 'stats': {}}, 9, 'after', event),
        throwsStateError,
      );
    },
  );
  test(
    'transport counts duplicates instead of hiding them and releases pending timer',
    () async {
      var finishes = 0;
      final attempt = TickAttempt(
        finish: () async {
          finishes++;
        },
        delay: const Duration(milliseconds: 20),
      );
      attempt.submit();
      attempt.submit();
      expect(attempt.submissions, 2);
      expect(attempt.completed, false);
      await attempt.close();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(finishes, 0);
      expect(attempt.completed, false);
      expect(attempt.released, true);
      expect(attempt.submit, throwsStateError);
    },
  );
  test(
    'cleanup awaits in-flight work and retains a completion failure',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final cause = StateError('write failed');
      final attempt = TickAttempt(
        delay: Duration.zero,
        finish: () async {
          entered.complete();
          await release.future;
          throw cause;
        },
      );
      attempt.submit();
      await entered.future;
      var closed = false;
      final closing = attempt.close().then((_) {
        closed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(closed, false);
      release.complete();
      await closing;
      expect(attempt.completed, false);
      expect(attempt.failure, same(cause));
      expect(attempt.failureStack, isNotNull);
    },
  );
  test('completion is observed only after actual data writes finish', () async {
    final written = Completer<void>();
    var actual = 0;
    final attempt = TickAttempt(
      delay: Duration.zero,
      finish: () async {
        actual = 9;
        written.complete();
      },
    );
    attempt.submit();
    await written.future;
    await Future<void>.delayed(Duration.zero);
    expect(actual, 9);
    expect(attempt.completed, true);
    expect(attempt.submissions, 1);
    await attempt.close();
    expect(attempt.released, true);
  });
}
