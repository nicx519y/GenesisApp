import 'dart:async';
import 'dart:convert';

import '../app/telemetry/genesis_telemetry.dart';
import 'models/photo_task.dart';

/// Observes only creates sent during the current World connection lifetime.
class PhotoGenerationMonitor {
  PhotoGenerationMonitor(this.worldId);

  static const timeout = Duration(minutes: 2);

  final String worldId;
  final _waiting = <(String, String), _PhotoWait>{};
  final _finished = <(String, String)>{};
  final _earlyTerminals = <(String, String)>{};
  bool _disposed = false;

  void start(String source, String requestId, {String? locationId}) {
    final key = (source, requestId);
    if (_disposed || _waiting.containsKey(key) || _finished.contains(key)) {
      return;
    }
    _waiting[key] = _PhotoWait(
      Timer(timeout, () {
        final wait = _waiting[key];
        if (wait == null) return;
        finish(source, requestId);
        GenesisTelemetry.collectLog(
          actionType: 'monitor',
          action: 'photo_generation_timeout',
          object1: worldId,
          object2: source,
          object3: requestId,
          object4: wait.taskId,
          extData: jsonEncode({
            'timeout_ms': timeout.inMilliseconds,
            if (locationId != null) 'location_id': locationId,
          }),
        );
      }),
    );
  }

  void observe(String source, PhotoTask photo, {String? requestId}) {
    final id = requestId ?? photo.requestId;
    final key = (source, id);
    final wait = _waiting[key];
    if (wait != null) {
      wait.taskId = photo.taskId;
      if (photo.terminal || _earlyTerminals.contains((source, photo.taskId))) {
        finish(source, id);
      } else {
        _pruneEarlyTerminals(source);
      }
    } else if (photo.terminal) {
      final match = _waiting.entries
          .where((e) => e.key.$1 == source && e.value.taskId == photo.taskId)
          .firstOrNull;
      if (match != null) {
        finish(source, match.key.$2);
      } else if (id.isEmpty && _hasUnboundRequest(source)) {
        // A result without a request ID can arrive before the create receipt.
        _earlyTerminals.add((source, photo.taskId));
      }
    }
  }

  void finish(String source, String requestId) {
    final key = (source, requestId);
    final wait = _waiting.remove(key);
    if (wait == null) return;
    wait.timer.cancel();
    _finished.add(key);
    _pruneEarlyTerminals(source);
  }

  bool _hasUnboundRequest(String source) =>
      _waiting.entries.any((e) => e.key.$1 == source && e.value.taskId == null);

  void _pruneEarlyTerminals(String source) {
    if (_earlyTerminals.isNotEmpty && !_hasUnboundRequest(source)) {
      _earlyTerminals.removeWhere((key) => key.$1 == source);
    }
  }

  void dispose() {
    _disposed = true;
    for (final wait in _waiting.values) {
      wait.timer.cancel();
    }
    _waiting.clear();
    _finished.clear();
    _earlyTerminals.clear();
  }
}

class _PhotoWait {
  _PhotoWait(this.timer);

  final Timer timer;
  String? taskId;
}
