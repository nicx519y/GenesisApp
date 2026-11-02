import 'package:flutter/widgets.dart';

class AppBackgroundResume {
  bool _background = false;
  bool update(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _background = true;
    }
    if (state != AppLifecycleState.resumed) return false;
    final resumed = _background;
    _background = false;
    return resumed;
  }
}
