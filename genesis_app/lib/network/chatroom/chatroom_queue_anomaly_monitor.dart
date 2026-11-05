import 'dart:convert';

import '../../app/telemetry/genesis_telemetry.dart';

typedef QueueAnomalyReporter = void Function(Map<String, Object?> event);

/// Scalar provenance only: never retains message bodies or presentation state.
class ChatroomQueueMessageInfo {
  const ChatroomQueueMessageInfo({
    required this.globalMessageId,
    required this.messageId,
    required this.locationMessageId,
    required this.conversationRoundId,
    this.clientMsgId = '',
    this.type = '',
    this.streamType = '',
    this.gatewayRequestId = '',
    this.attemptNo,
  });

  final int globalMessageId, messageId, locationMessageId, conversationRoundId;
  final String clientMsgId, type, streamType, gatewayRequestId;
  final int? attemptNo;
  bool get hasIdentity => globalMessageId > 0 || messageId > 0;
  Object get identity => globalMessageId > 0
      ? ('global', globalMessageId)
      : clientMsgId.isNotEmpty
      ? ('client', clientMsgId)
      : ('message', messageId);

  bool sameMessage(ChatroomQueueMessageInfo other) {
    if (globalMessageId > 0 && other.globalMessageId > 0) {
      return globalMessageId == other.globalMessageId;
    }
    if (clientMsgId.isNotEmpty && other.clientMsgId.isNotEmpty) {
      return clientMsgId == other.clientMsgId;
    }
    return messageId > 0 && messageId == other.messageId;
  }
}

class ChatroomQueueObservation {
  ChatroomQueueObservation._(
    this.location,
    this.message,
    this.normal,
    this.epoch,
  );
  final String location;
  final ChatroomQueueMessageInfo message;
  final bool normal;
  final int epoch;
}

class _QueueIndex {
  final global = <int, ChatroomQueueMessageInfo>{};
  final client = <String, List<ChatroomQueueMessageInfo>>{};
  final message = <int, List<ChatroomQueueMessageInfo>>{};
  final cursor = <int, List<ChatroomQueueMessageInfo>>{};
  final abnormal = <Object>{};
  int count = 0;
  Iterable<ChatroomQueueMessageInfo> get values =>
      message.values.expand((v) => v);

  bool contains(ChatroomQueueMessageInfo incoming) =>
      (incoming.globalMessageId > 0 &&
          global.containsKey(incoming.globalMessageId)) ||
      (client[incoming.clientMsgId]?.any(incoming.sameMessage) ?? false) ||
      (message[incoming.messageId]?.any(incoming.sameMessage) ?? false);
}

/// Checks first appearances against cached IDs, independently of queue sorting.
class ChatroomQueueAnomalyMonitor {
  ChatroomQueueAnomalyMonitor({QueueAnomalyReporter? report})
    : _report = report ?? _collect;

  static const maxObservedMessages = 1024;
  final QueueAnomalyReporter _report;
  final _queues = <String, _QueueIndex>{};
  final _latest = <String, ({int round, int cursor})>{};
  final Map<(String, Object), bool> _seen = <(String, Object), bool>{};
  String _world = '';
  int _connection = 0;
  int _epoch = 0;

  ({int round, int cursor}) latestFor(String location) =>
      _latest[location] ?? (round: 0, cursor: 0);
  int get observedCount => _seen.length;

  /// Content-only stream changes do not require rebuilding queue indexes.
  bool matchesQueuedMessage(String location, ChatroomQueueMessageInfo info) {
    if (!info.hasIdentity) return true;
    final queue = _queues[location];
    if (queue == null) return false;
    final old = info.globalMessageId > 0
        ? queue.global[info.globalMessageId]
        : (queue.client[info.clientMsgId] ?? queue.message[info.messageId])
              ?.where(info.sameMessage)
              .firstOrNull;
    return old != null &&
        old.globalMessageId == info.globalMessageId &&
        old.messageId == info.messageId &&
        old.clientMsgId == info.clientMsgId &&
        old.conversationRoundId == info.conversationRoundId &&
        old.locationMessageId == info.locationMessageId;
  }

  void reset({required String worldId, required int connectionGeneration}) {
    clear();
    _world = worldId;
    _connection = connectionGeneration;
  }

  void clear() {
    _epoch++;
    _world = '';
    _connection = 0;
    _queues.clear();
    _latest.clear();
    _seen.clear();
  }

  /// Refresh identity/cursor indexes without deriving maxima from WS arrivals.
  void replaceQueue(
    String location,
    Iterable<ChatroomQueueMessageInfo> messages,
  ) {
    final previous = _queues[location];
    final index = _QueueIndex();
    for (final info in messages) {
      index.count++;
      if (!info.hasIdentity) continue;
      if (info.globalMessageId > 0) index.global[info.globalMessageId] = info;
      if (info.clientMsgId.isNotEmpty) {
        index.client.putIfAbsent(info.clientMsgId, () => []).add(info);
      }
      index.message.putIfAbsent(info.messageId, () => []).add(info);
      if (info.locationMessageId > 0) {
        index.cursor.putIfAbsent(info.locationMessageId, () => []).add(info);
      }
      if (_seen[(location, info.identity)] == false ||
          (previous?.abnormal.contains(info.identity) ?? false)) {
        index.abnormal.add(info.identity);
      }
    }
    if (index.count == 0) {
      _queues.remove(location);
    } else {
      _queues[location] = index;
    }
  }

  /// Called only for initialization or an actual removal/replacement/eviction.
  void rebuildBaseline(String location) {
    _latest.remove(location);
    final queue = _queues[location];
    if (queue == null) return;
    for (final info in queue.values) {
      if (!queue.abnormal.contains(info.identity)) _advance(location, info);
    }
  }

  /// HTTP/local reads are trusted calibration; they never emit arrival events.
  void calibrate(String location, Iterable<ChatroomQueueMessageInfo> messages) {
    for (final info in messages) {
      if (!info.hasIdentity) continue;
      _queues[location]?.abnormal.remove(info.identity);
      final key = (location, info.identity);
      if (_seen.containsKey(key)) _seen[key] = true;
      _advance(location, info);
    }
  }

  ChatroomQueueObservation? inspect({
    required String location,
    required ChatroomQueueMessageInfo incoming,
    required Map<String, Object?> context,
  }) {
    if (_world.isEmpty || location.isEmpty || !incoming.hasIdentity) {
      return null;
    }
    final key = (location, incoming.identity);
    if (_seen.containsKey(key)) {
      final normal = _seen.remove(key)!;
      _seen[key] = normal;
      return null;
    }
    final queue = _queues[location];
    if (queue?.contains(incoming) ?? false) {
      _remember(key, !(queue!.abnormal.contains(incoming.identity)));
      return null;
    }
    final baseline = latestFor(location);
    final oldRound =
        incoming.conversationRoundId > 0 &&
        incoming.conversationRoundId < baseline.round;
    final oldCursor =
        incoming.locationMessageId > 0 &&
        incoming.locationMessageId < baseline.cursor;
    final collision =
        incoming.locationMessageId > 0 &&
        (queue?.cursor[incoming.locationMessageId]?.any(
              (old) => !incoming.sameMessage(old),
            ) ??
            false);
    final normal = !oldRound && !oldCursor && !collision;
    _remember(key, normal);
    final details = <String, Object?>{
      ...context,
      'incoming_conversation_round_id': '${incoming.conversationRoundId}',
      'incoming_location_message_id': '${incoming.locationMessageId}',
      'cached_conversation_round_id': '${baseline.round}',
      'cached_location_message_id': '${baseline.cursor}',
      'global_message_id': '${incoming.globalMessageId}',
      'message_id': '${incoming.messageId}',
      'client_msg_id': incoming.clientMsgId,
      'type': incoming.type,
      'stream_type': incoming.streamType,
      'gateway_request_id': incoming.gatewayRequestId,
      'attempt_no': incoming.attemptNo,
      'queue_count': queue?.count ?? 0,
      'connection_generation': _connection,
    };
    if (oldRound) {
      _emit(
        'location_chat_queue_old_conversation_round',
        location,
        incoming.conversationRoundId,
        baseline.round,
        details,
        'less_than_cached_latest',
      );
    }
    if (oldCursor || collision) {
      _emit(
        'location_chat_queue_old_location_message_id',
        location,
        incoming.locationMessageId,
        baseline.cursor,
        details,
        collision ? 'same_cursor_different_message' : 'less_than_cached_latest',
      );
    }
    return ChatroomQueueObservation._(location, incoming, normal, _epoch);
  }

  /// Only after the existing reducer has processed the arrival successfully.
  void commit(ChatroomQueueObservation? observation) {
    if (observation == null ||
        observation.epoch != _epoch ||
        !observation.normal) {
      return;
    }
    _advance(observation.location, observation.message);
  }

  void _advance(String location, ChatroomQueueMessageInfo info) {
    final previous = latestFor(location);
    _latest[location] = (
      round: info.conversationRoundId > previous.round
          ? info.conversationRoundId
          : previous.round,
      cursor: info.locationMessageId > previous.cursor
          ? info.locationMessageId
          : previous.cursor,
    );
  }

  void _remember((String, Object) key, bool normal) {
    _seen[key] = normal;
    if (_seen.length > maxObservedMessages) _seen.remove(_seen.keys.first);
  }

  void _emit(
    String action,
    String location,
    int incoming,
    int latest,
    Map<String, Object?> details,
    String reason,
  ) {
    try {
      final data = <String, Object?>{...details, 'reason': reason};
      var encoded = jsonEncode(data);
      // Collect caps ext_data at 4096 characters. Keep it valid JSON even if
      // a malformed server identifier contains thousands of escaped characters.
      for (final limit in [256, 128, 64, 0]) {
        if (encoded.length <= 4000) break;
        for (final key in [
          'client_msg_id',
          'gateway_request_id',
          'type',
          'stream_type',
        ]) {
          final value = data[key]! as String;
          if (value.length > limit) data[key] = value.substring(0, limit);
        }
        data['metadata_truncated'] = true;
        encoded = jsonEncode(data);
      }
      _report({
        'action_type': 'monitor',
        'action': action,
        'object1': _world,
        'object2': location,
        'object3': '$incoming',
        'object4': '$latest',
        'ext_data': encoded,
      });
    } catch (_) {
      // Reporting is independent of message ingestion and of the other event.
    }
  }

  static void _collect(Map<String, Object?> event) =>
      GenesisTelemetry.collectLog(
        actionType: 'monitor',
        action: event['action']! as String,
        object1: event['object1'],
        object2: event['object2'],
        object3: event['object3'],
        object4: event['object4'],
        extData: event['ext_data']! as String,
      );
}
