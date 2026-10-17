import 'dart:async';

/// Preview replies survive internal navigation, but stop when the phone closes.
class MiniPhonePreviewActivity {
  final _timers = <Timer>{};

  void schedule(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
  }

  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
