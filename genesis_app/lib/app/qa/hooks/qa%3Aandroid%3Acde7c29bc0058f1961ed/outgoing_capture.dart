import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../network/websocket_capture.dart';

/// Uses the production transport's synchronous send record, not delayed receipt
/// on the loopback server. A real heartbeat anchors the observation interval.
class ParentOutgoingCapture {
  ParentOutgoingCapture({
    required this.endpoint,
    required this.worldId,
    required this.parentId,
    this.heartbeatInterval = const Duration(seconds: 10),
    WebSocketCaptureController? controller,
  }) : controller = controller ?? webSocketCaptureController;
  final Uri endpoint;
  final String worldId, parentId;
  final Duration heartbeatInterval;
  final WebSocketCaptureController controller;
  bool? _beforeEnabled, _beforeStored;
  String? _anchor;
  bool restored = false;
  int get startSequence => _sequence(_anchor!);
  int _sequence(String id) => int.parse(id.substring(id.lastIndexOf('-') + 1));
  bool _owned(WebSocketCaptureRecord r) =>
      r.uri.scheme == endpoint.scheme &&
      r.uri.host == endpoint.host &&
      r.uri.port == endpoint.port &&
      r.uri.path == endpoint.path &&
      r.uri.queryParameters['world_id'] == worldId;

  Future<void> start([Future<void> Function()? heartbeat]) async {
    if (_beforeEnabled != null) throw StateError('Capture already acquired');
    if (heartbeatInterval <= Duration.zero) {
      throw ArgumentError('Positive heartbeat interval required');
    }
    if (!controller.available) throw StateError('Outgoing capture unavailable');
    _beforeEnabled = controller.enabled;
    final prefs = await SharedPreferences.getInstance();
    _beforeStored = prefs.getBool(WebSocketCaptureController.enabledStorageKey);
    await controller.setEnabled(true);
    final before = controller.records.map((r) => r.id).toSet();
    if (heartbeat != null) await heartbeat();
    // Readiness precedes the business interval. Allow the configured periodic
    // heartbeat to occur; a fixed five seconds is shorter than the App default.
    final deadline = DateTime.now().add(
      heartbeatInterval + const Duration(seconds: 5),
    );
    while (!controller.records.any(
          (r) =>
              !before.contains(r.id) &&
              _owned(r) &&
              r.direction == WebSocketCaptureDirection.send &&
              r.type == 'heartbeat',
        ) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    final anchors = controller.records
        .where(
          (r) =>
              !before.contains(r.id) &&
              _owned(r) &&
              r.direction == WebSocketCaptureDirection.send &&
              r.type == 'heartbeat',
        )
        .toList();
    if (anchors.isEmpty)
      throw StateError('Actual outgoing heartbeat was not captured');
    _anchor = anchors.first.id;
  }

  int count(String type) {
    if (_anchor == null || restored || !controller.enabled) {
      throw StateError('Outgoing observation unavailable');
    }
    final records = controller.records;
    if (!records.any((r) => r.id == _anchor)) {
      throw StateError(
        'Outgoing observation interval was truncated or cleared',
      );
    }
    final owned =
        records
            .where(
              (r) => _owned(r) && r.direction == WebSocketCaptureDirection.send,
            )
            .toList()
          ..sort((a, b) => _sequence(a.id).compareTo(_sequence(b.id)));
    final joined = <String, String>{};
    var count = 0;
    for (final record in owned) {
      if (record.omitted || !record.isJson) {
        throw StateError('Outgoing frame could not be classified');
      }
      final value = jsonDecode(record.bodyText);
      if (value is! Map)
        throw StateError('Outgoing frame has no object payload');
      final frame = Map<String, dynamic>.from(value);
      final payload = frame['payload'] is Map
          ? frame['payload'] as Map
          : const {};
      final frameWorld = '${frame['world_id'] ?? ''}';
      if (frameWorld.isNotEmpty && frameWorld != worldId) {
        throw StateError(
          'Outgoing frame world differs from its owned connection',
        );
      }
      final kind = '${frame['type'] ?? ''}';
      if (!['join', 'send_message', 'leave'].contains(kind)) continue;
      final explicit =
          '${frame['location_id'] ?? payload['location_id'] ?? ''}';
      final location = explicit.isNotEmpty
          ? explicit
          : joined[record.connectionId];
      if (location == null || location.isEmpty) {
        throw StateError('Outgoing $kind has no observed location context');
      }
      if (kind == 'join') joined[record.connectionId] = location;
      if (_sequence(record.id) > startSequence &&
          kind == type &&
          location == parentId)
        count++;
      if (kind == 'leave') joined.remove(record.connectionId);
    }
    return count;
  }

  Future<void> restore() async {
    final before = _beforeEnabled;
    if (before == null || restored) return;
    await controller.setEnabled(before);
    final prefs = await SharedPreferences.getInstance();
    if (_beforeStored == null) {
      if (!await prefs.remove(WebSocketCaptureController.enabledStorageKey)) {
        throw StateError('Capture setting restoration failed');
      }
    } else if (!await prefs.setBool(
      WebSocketCaptureController.enabledStorageKey,
      _beforeStored!,
    )) {
      throw StateError('Capture setting restoration failed');
    }
    if (controller.enabled != before ||
        prefs.getBool(WebSocketCaptureController.enabledStorageKey) !=
            _beforeStored) {
      throw StateError('Capture setting restoration mismatch');
    }
    restored = true;
  }
}
