import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The native event is a retry hint, not proof that either server is reachable.
class NetworkAvailabilityEvents {
  const NetworkAvailabilityEvents._();

  static const EventChannel _channel = EventChannel(
    'com.worldo.ai/network_availability',
  );

  static Stream<bool> get changes => _channel
      .receiveBroadcastStream()
      .where((event) => event is bool)
      .cast<bool>();
}

/// Coalesces the initial network snapshot and offline-to-online transitions.
class AdjustNetworkRecoveryTrigger {
  AdjustNetworkRecoveryTrigger({
    required Stream<bool> availability,
    required Future<void> Function() recover,
    this.debounce = const Duration(milliseconds: 800),
  }) : _recover = recover {
    _subscription = availability.listen(
      _onAvailability,
      onError: (Object error) {
        debugPrint('[Adjust] network availability monitor failed: $error');
      },
    );
  }

  final Future<void> Function() _recover;
  final Duration debounce;
  late final StreamSubscription<bool> _subscription;
  Timer? _timer;
  Future<void>? _inFlight;
  bool? _available;
  bool _foreground = true;
  bool _disposed = false;
  bool _pendingRecovery = false;

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
      _timer = null;
      _pendingRecovery = false;
    }
  }

  void _onAvailability(bool available) {
    final wasAvailable = _available;
    _available = available;
    if (!available) {
      _timer?.cancel();
      _timer = null;
      _pendingRecovery = false;
      return;
    }
    if (wasAvailable == true || !_foreground || _disposed) return;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      if (_foreground && !_disposed) unawaited(_run());
    });
  }

  Future<void> _run() {
    final active = _inFlight;
    if (active != null) {
      _pendingRecovery = true;
      return active;
    }
    _pendingRecovery = false;
    late final Future<void> attempt;
    attempt = Future<void>.sync(_recover)
        .catchError((Object error, StackTrace stack) {
          debugPrint('[Adjust] network recovery failed: $error');
          debugPrint('[Adjust] network recovery stacktrace:\n$stack');
        })
        .whenComplete(() {
          if (identical(_inFlight, attempt)) {
            _inFlight = null;
            if (_pendingRecovery &&
                _available == true &&
                _foreground &&
                !_disposed) {
              _pendingRecovery = false;
              _schedule();
            }
          }
        });
    _inFlight = attempt;
    return attempt;
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _subscription.cancel();
  }
}
