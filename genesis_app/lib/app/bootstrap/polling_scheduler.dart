import 'dart:async';

class GenesisPollingScheduler {
  GenesisPollingScheduler({required this.interval, required this.onTick});

  final Duration interval;
  final Future<void> Function() onTick;

  Timer? _timer;
  bool _active = false;
  bool _inFlight = false;

  void start({bool immediately = true}) {
    if (_active) return;
    _active = true;
    if (immediately) {
      unawaited(_run());
    } else {
      _scheduleNext();
    }
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> runNow() {
    if (!_active) _active = true;
    return _run();
  }

  Future<void> _run() async {
    if (_inFlight) {
      _scheduleNext();
      return;
    }
    _timer?.cancel();
    _timer = null;
    _inFlight = true;
    try {
      await onTick();
    } finally {
      _inFlight = false;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    if (!_active) return;
    _timer?.cancel();
    _timer = Timer(interval, () {
      unawaited(_run());
    });
  }
}
