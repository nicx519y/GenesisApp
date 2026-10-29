import 'package:flutter/foundation.dart';

import 'auth_session.dart';

/// One interactive login at a time across all login surfaces in an app session.
class LoginSubmissionController extends ValueNotifier<IdentityProvider?> {
  LoginSubmissionController() : super(null);

  bool _disposed = false;
  bool _active = true;
  bool _succeeded = false;

  bool get isActive => _active && !_disposed;
  bool get succeeded => _succeeded;

  void markSucceeded() {
    if (!isActive || _succeeded) return;
    _succeeded = true;
    notifyListeners();
  }

  void resetSessionResult() {
    if (!isActive || !_succeeded) return;
    _succeeded = false;
    notifyListeners();
  }

  /// Retire immediately on configuration replacement, before widgets rebind.
  /// Listeners remain attached until their normal disposal/dependency update.
  void invalidate() => _active = false;

  Future<void> submit(
    IdentityProvider provider,
    Future<void> Function() work,
  ) async {
    if (!isActive || value != null || _succeeded) return;
    value = provider;
    try {
      await work();
    } finally {
      if (!_disposed) value = null;
    }
  }

  @override
  void dispose() {
    invalidate();
    _disposed = true;
    super.dispose();
  }
}
