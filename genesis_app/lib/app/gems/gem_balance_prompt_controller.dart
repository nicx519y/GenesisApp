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

  void report(GemBalanceAlert alert, String? requestAuthorization) {
    if (_disposed || _presenting) return;
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
          _presenting ||
          session == null ||
          _token(session.authToken) != token) {
        return;
      }
      // An insufficient-balance error takes priority over a low-balance hint.
      if (_pending?.kind == GemBalanceAlertKind.insufficient) return;
      _pending = alert;
      notifyListeners();
    } catch (_) {
      // Unverifiable session ownership must not produce a payment prompt.
    }
  }

  GemBalanceAlert? beginPresentation() {
    if (_disposed || _presenting) return null;
    final alert = _pending;
    if (alert == null) return null;
    _pending = null;
    _presenting = true;
    return alert;
  }

  void endPresentation() {
    _presenting = false;
  }

  void reset() {
    _generation++;
    _pending = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
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
