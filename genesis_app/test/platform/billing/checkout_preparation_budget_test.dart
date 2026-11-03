import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/checkout_preparation_budget.dart';

void main() {
  testWidgets(
    'timeout releases caller but preserves shared lookup and ignores late errors',
    (tester) async {
      final budget = CheckoutPreparationBudget();
      final lookup = Completer<int>();
      var continued = false;
      Object? failure;
      final result = budget
          .wait(lookup.future)
          .then((_) {
            continued = true;
          })
          .catchError((Object e) {
            failure = e;
          });
      await tester.pump(const Duration(seconds: 30));
      await result;
      expect(failure, isA<TimeoutException>());
      expect(lookup.isCompleted, false);
      lookup.completeError(StateError('late native error'));
      await tester.pump();
      expect(continued, false);
    },
  );

  testWidgets('preflight stages share one 30 second budget', (tester) async {
    final budget = CheckoutPreparationBudget(
      startedAt: DateTime.now().subtract(const Duration(seconds: 20)),
    );
    final next = Completer<void>();
    final result = budget.wait(next.future);
    final check = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 10));
    await check;
    next.complete();
    await tester.pump();
  });
}
