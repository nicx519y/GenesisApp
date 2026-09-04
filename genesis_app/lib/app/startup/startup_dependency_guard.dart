import 'dart:async';

/// Waits for a startup dependency without allowing it to block app rendering
/// indefinitely.
Future<void> waitForStartupDependency(
  Future<void> dependency, {
  required Duration timeout,
  void Function()? onTimeout,
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  try {
    await dependency.timeout(timeout);
  } on TimeoutException {
    onTimeout?.call();
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
  }
}
