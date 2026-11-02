import 'dart:async';

/// A click's original preparation deadline, shared with the purchase service.
/// Only pre-store work is awaited through this budget, never the store UI.
class CheckoutPreparationBudget {
  CheckoutPreparationBudget({DateTime? startedAt})
    : startedAt = startedAt ?? DateTime.now();

  static const timeout = Duration(seconds: 90);
  static final Object _key = Object();
  static CheckoutPreparationBudget? get current =>
      Zone.current[_key] as CheckoutPreparationBudget?;
  final DateTime startedAt;

  Duration get remaining {
    final value = timeout - DateTime.now().difference(startedAt);
    return value.isNegative ? Duration.zero : value;
  }

  Future<T> wait<T>(Future<T> work) => work.timeout(remaining);
  Future<T> run<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_key: this});
}
