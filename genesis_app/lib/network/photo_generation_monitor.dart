import 'dart:async';
import 'dart:convert';

import '../app/telemetry/genesis_telemetry.dart';
import 'gem_balance_alert.dart';
import 'models/photo_task.dart';

typedef _PhotoResult = ({PhotoTaskStatus status, String failureCode});

/// Observes only creates sent during the current World connection lifetime.
class PhotoGenerationMonitor {
  PhotoGenerationMonitor(this.worldId);

  static const timeout = Duration(minutes: 2);

  final String worldId;
  final _requests = <(String, String), _PhotoRequest>{};
  final _earlyTerminals = <(String, String), _PhotoResult>{};
  bool _disposed = false;

  String? recordClick(String source, {String? locationId}) {
    if (_disposed || worldId.isEmpty) return null;
    final attemptId = newCollectEventId();
    _record(source, 'click', attemptId, {
      if (locationId != null) 'location_id': locationId,
    });
    return attemptId;
  }

  void start(
    String source,
    String requestId, {
    String? attemptId,
    String? locationId,
    int? roundId,
    int? cardId,
  }) {
    final key = (source, requestId);
    if (_disposed || _requests.containsKey(key)) return;
    final request = _PhotoRequest(attemptId, locationId, roundId, cardId);
    _requests[key] = request;
    request.timer = Timer(timeout, () {
      // A timeout ends the timer, but the real result may still arrive.
      request.timer = null;
      GenesisTelemetry.collectLog(
        actionType: 'monitor',
        action: 'photo_generation_timeout',
        object1: worldId,
        object2: source,
        object3: requestId,
        object4: request.taskId,
        extData: jsonEncode({
          'timeout_ms': timeout.inMilliseconds,
          if (locationId != null) 'location_id': locationId,
        }),
      );
    });
  }

  void acceptReceipt(String source, String requestId, PhotoTask photo) {
    final request = _requests[(source, requestId)];
    if (request == null || !_bindTask(request, photo.taskId)) return;
    if (!request.accepted) {
      request.accepted = true;
      _recordRequest(source, requestId, request, 'accepted');
    }
    observe(source, photo, requestId: requestId);
  }

  void observe(String source, PhotoTask photo, {String? requestId}) {
    final result = photo.terminal
        ? (status: photo.status, failureCode: photo.failureCode)
        : null;
    final id = requestId ?? photo.requestId;
    final taskKey = (source, photo.taskId);
    final key = id.isNotEmpty
        ? (source, id)
        : _requests.entries
              .where(
                (e) => e.key.$1 == source && e.value.taskId == photo.taskId,
              )
              .firstOrNull
              ?.key;
    final request = _requests[key];
    if (key == null || request == null) {
      if (result != null && id.isEmpty && _hasUnboundRequest(source)) {
        // A result without a request ID can arrive before the create receipt.
        _earlyTerminals.putIfAbsent(taskKey, () => result);
      }
      return;
    }
    if (request.closed || !_bindTask(request, photo.taskId)) return;
    final terminal = _earlyTerminals.remove(taskKey) ?? result;
    if (terminal != null) {
      request.close();
      _recordRequest(
        source,
        key.$2,
        request,
        terminal.status.name,
        failureCode: terminal.failureCode,
      );
    }
    _pruneEarlyTerminals(source);
  }

  void reject(String source, String requestId, {int? errorCode}) {
    final request = _requests[(source, requestId)];
    if (request == null || request.closed || request.accepted) return;
    request.close();
    if (isGemBalanceFailureCode(errorCode)) {
      _recordRequest(
        source,
        requestId,
        request,
        'rejected',
        failureCode: 'insufficient_balance',
      );
    }
    _pruneEarlyTerminals(source);
  }

  bool _bindTask(_PhotoRequest request, String taskId) {
    request.taskId ??= taskId;
    return request.taskId == taskId;
  }

  bool _hasUnboundRequest(String source) => _requests.entries.any(
    (e) => e.key.$1 == source && e.value.taskId == null && !e.value.closed,
  );

  void _pruneEarlyTerminals(String source) {
    if (_earlyTerminals.isNotEmpty && !_hasUnboundRequest(source)) {
      _earlyTerminals.removeWhere((key, _) => key.$1 == source);
    }
  }

  void _recordRequest(
    String source,
    String requestId,
    _PhotoRequest request,
    String stage, {
    String failureCode = '',
  }) {
    final attemptId = request.attemptId;
    if (attemptId == null) return;
    _record(source, stage, attemptId, {
      if (request.locationId != null) 'location_id': request.locationId!,
      'client_request_id': requestId,
      if (request.taskId != null) 'task_id': request.taskId!,
      if (request.roundId != null)
        'conversation_round_id': '${request.roundId}',
      if (request.cardId != null) 'card_id': '${request.cardId}',
      if (failureCode.isNotEmpty)
        'failure_code': isGemBalanceFailureCode(failureCode)
            ? 'insufficient_balance'
            : failureCode,
    });
  }

  void _record(
    String source,
    String stage,
    String attemptId,
    Map<String, String> data,
  ) {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'photo_generation',
      object1: worldId,
      object2: source,
      object3: stage,
      object4: attemptId,
      extData: data.isEmpty ? '' : jsonEncode(data),
    );
  }

  void dispose() {
    _disposed = true;
    for (final request in _requests.values) {
      request.close();
    }
    _requests.clear();
    _earlyTerminals.clear();
  }
}

class _PhotoRequest {
  _PhotoRequest(this.attemptId, this.locationId, this.roundId, this.cardId);

  final String? attemptId, locationId;
  final int? roundId, cardId;
  Timer? timer;
  String? taskId;
  bool accepted = false;
  bool closed = false;

  void close() {
    closed = true;
    timer?.cancel();
    timer = null;
  }
}
