import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../network/gem_balance_alert.dart';
import '../../platform/session/user_session_store.dart';

/// One application/session-wide queue, independent of the initiating page.
class GemBalancePromptController extends ChangeNotifier {
  GemBalancePromptController({required this.sessionStore});
  final UserSessionStore sessionStore;
  GemBalanceAlert? _pending;
  GemBalanceAlert? get pending => _pending;
  bool _presenting = false;
  bool _disposed = false;
  int _generation = 0;
  final _seenOccurrences = <String>{};
  int _presentationHolds = 0;

  /// Keep a result dialog and the shared purchase panel in one presentation lane.
  VoidCallback holdPresentation() {
    _presentationHolds++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _presentationHolds--;
      if (!_disposed && _presentationHolds == 0 && _pending != null) {
        notifyListeners();
      }
    };
  }

  final _idleWaiters = <Completer<void>>[];
  Future<void> waitUntilIdle() {
    if (_disposed || (!_presenting && _pending == null)) return Future.value();
    final waiter = Completer<void>();
    _idleWaiters.add(waiter);
    return waiter.future;
  }

  void _completeIdleWaiters() {
    for (final waiter in _idleWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _idleWaiters.clear();
  }

  Future<void> reportAndWait(
    GemBalanceAlert alert,
    String? authorization,
  ) async {
    if (_disposed) return;
    await _accept(alert, authorization, _generation);
    await waitUntilIdle();
  }

  void report(GemBalanceAlert alert, String? requestAuthorization) {
    if (_disposed) return;
    final generation = _generation;
    unawaited(_accept(alert, requestAuthorization, generation));
  }

  Future<void> _accept(
    GemBalanceAlert alert,
    String? authorization,
    int generation,
  ) async {
    final token = _token(authorization);
    if (token.isEmpty) return;
    try {
      final session = await sessionStore.readCompleteSession();
      if (_disposed ||
          generation != _generation ||
          session == null ||
          _token(session.authToken) != token) {
        return;
      }
      final occurrence = alert.occurrenceKey;
      if (occurrence != null) {
        if (!_seenOccurrences.add(occurrence)) return;
        if (_seenOccurrences.length > 512) {
          _seenOccurrences.remove(_seenOccurrences.first);
        }
      }
      if (_presenting) return;
      // An insufficient-balance error takes priority over a low-balance hint.
      if (_pending?.kind == GemBalanceAlertKind.insufficient) return;
      _pending = alert;
      notifyListeners();
    } catch (_) {
      // Unverifiable session ownership must not produce a payment prompt.
    }
  }

  GemBalanceAlert? beginPresentation() {
    if (_disposed || _presenting || _presentationHolds > 0) return null;
    final alert = _pending;
    if (alert == null) return null;
    _pending = null;
    _presenting = true;
    return alert;
  }

  void endPresentation() {
    _presenting = false;
    if (_pending == null) _completeIdleWaiters();
  }

  void reset() {
    _completeIdleWaiters();
    _generation++;
    _seenOccurrences.clear();
    _pending = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _completeIdleWaiters();
    _disposed = true;
    _generation++;
    _pending = null;
    super.dispose();
  }

  String _token(String? value) => (value ?? '')
      .trim()
      .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
      .trim();
}
