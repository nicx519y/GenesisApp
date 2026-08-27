import 'package:flutter/foundation.dart';

/// Keeps a page subscribed to the app-level authenticated-session revision.
///
/// The revision changes only when the active identity changes (login, logout,
/// account replacement, or session expiry). Profile edits use
/// `UserSessionStore.userInfoRevision` instead and must not invalidate lists.
class SessionRevisionSubscription {
  SessionRevisionSubscription(this._onChanged);

  final VoidCallback _onChanged;
  ValueListenable<int>? _source;

  int get value => _source?.value ?? 0;

  void bind(ValueListenable<int> source) {
    if (identical(_source, source)) return;
    _source?.removeListener(_onChanged);
    _source = source;
    source.addListener(_onChanged);
  }

  bool matches(int revision) => value == revision;

  void dispose() {
    _source?.removeListener(_onChanged);
    _source = null;
  }
}
