import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int defaultWebSocketCaptureMaxRecords = 1000;
const int defaultWebSocketCaptureMaxBodyBytes = 40 * 1024 * 1024;
const int webSocketCaptureMaxFrameBodyBytes = 128 * 1024;

final WebSocketCaptureController webSocketCaptureController =
    WebSocketCaptureController();

enum WebSocketCaptureDirection { send, receive }

enum WebSocketCaptureFilterMode { onlyShow, hide }

class WebSocketCaptureRecord {
  const WebSocketCaptureRecord({
    required this.id,
    required this.connectionId,
    required this.sequence,
    required this.direction,
    required this.recordedAt,
    required this.uri,
    required this.type,
    required this.streamType,
    required this.worldId,
    required this.locationId,
    required this.globalMessageId,
    required this.messageId,
    required this.locationMessageId,
    required this.clientMessageId,
    required this.byteCount,
    required this.bodyText,
    required this.isJson,
    required this.omitted,
  });

  final String id;
  final String connectionId;
  final int sequence;
  final WebSocketCaptureDirection direction;
  final DateTime recordedAt;
  final Uri uri;
  final String type;
  final String streamType;
  final String worldId;
  final String locationId;
  final String globalMessageId;
  final String messageId;
  final String locationMessageId;
  final String clientMessageId;
  final int byteCount;
  final String bodyText;
  final bool isJson;
  final bool omitted;

  String get typeKey => type.isEmpty
      ? WebSocketCaptureController.unknownTypeKey
      : WebSocketCaptureController.normalizeType(type);

  int get retainedBodyBytes => utf8.encode(bodyText).length;
}

class WebSocketCaptureConnection {
  WebSocketCaptureConnection._({
    required WebSocketCaptureController controller,
    required this.connectionId,
    required this.uri,
  }) : _controller = controller;

  final WebSocketCaptureController _controller;
  final String connectionId;
  final Uri uri;
  int _nextSequence = 1;

  void recordFrame(WebSocketCaptureDirection direction, String message) {
    _controller.recordFrame(
      connectionId: connectionId,
      sequence: _nextSequence++,
      direction: direction,
      uri: uri,
      message: message,
    );
  }
}

class WebSocketCaptureController extends ChangeNotifier {
  WebSocketCaptureController({
    this.maxRecords = defaultWebSocketCaptureMaxRecords,
    this.maxBodyBytes = defaultWebSocketCaptureMaxBodyBytes,
    this.maxFrameBodyBytes = webSocketCaptureMaxFrameBodyBytes,
    this.notificationBatchDuration = const Duration(milliseconds: 100),
    bool? available,
  }) : available = available ?? kDebugMode;

  static const String unknownTypeKey = '(unknown)';
  static const String enabledStorageKey =
      'developer_websocket_capture_enabled_v1';
  static const String directionStorageKey =
      'developer_websocket_direction_filter_v1';
  static const String filterModeStorageKey =
      'developer_websocket_type_filter_mode_v1';
  static const String selectedTypesStorageKey =
      'developer_websocket_type_filter_values_v1';

  final int maxRecords;
  final int maxBodyBytes;
  final int maxFrameBodyBytes;
  final Duration notificationBatchDuration;
  final bool available;
  final List<WebSocketCaptureRecord> _records = <WebSocketCaptureRecord>[];
  final Set<String> _selectedTypes = <String>{};
  bool _enabled = false;
  WebSocketCaptureDirection? _directionFilter;
  WebSocketCaptureFilterMode _filterMode = WebSocketCaptureFilterMode.hide;
  int _nextConnectionId = 1;
  int _nextRecordId = 1;
  int _settingsRevision = 0;
  Timer? _notificationTimer;

  bool get enabled => _enabled;
  WebSocketCaptureDirection? get directionFilter => _directionFilter;
  WebSocketCaptureFilterMode get filterMode => _filterMode;
  Set<String> get selectedTypes => Set<String>.unmodifiable(_selectedTypes);
  List<WebSocketCaptureRecord> get records =>
      List<WebSocketCaptureRecord>.unmodifiable(_records);

  static String normalizeType(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ? unknownTypeKey : normalized;
  }

  Future<bool> loadSettings() async {
    if (!available) {
      _disableUnavailableCapture();
      return false;
    }
    final revision = _settingsRevision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (revision != _settingsRevision) return _enabled;
      _enabled = preferences.getBool(enabledStorageKey) ?? false;
      _directionFilter = _decodeDirection(
        preferences.getString(directionStorageKey),
      );
      _filterMode = _decodeFilterMode(
        preferences.getString(filterModeStorageKey),
      );
      _selectedTypes
        ..clear()
        ..addAll(
          (preferences.getStringList(selectedTypesStorageKey) ??
                  const <String>[])
              .map(normalizeType),
        );
      notifyListeners();
    } catch (_) {
      if (revision == _settingsRevision) {
        _enabled = false;
        notifyListeners();
      }
    }
    return _enabled;
  }

  Future<void> setEnabled(bool value) async {
    if (!available) {
      _disableUnavailableCapture();
      return;
    }
    if (_enabled == value) return;
    final previous = _enabled;
    final revision = ++_settingsRevision;
    _enabled = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(enabledStorageKey, value)) {
        throw StateError('Failed to save websocket capture setting.');
      }
    } catch (_) {
      if (revision == _settingsRevision) {
        _enabled = previous;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> setDirectionFilter(WebSocketCaptureDirection? value) async {
    if (!available || value == _directionFilter) return;
    _directionFilter = value;
    ++_settingsRevision;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    final saved = value == null
        ? await preferences.remove(directionStorageKey)
        : await preferences.setString(directionStorageKey, value.name);
    if (!saved) throw StateError('Failed to save websocket direction filter.');
  }

  Future<void> setTypeFilter({
    required WebSocketCaptureFilterMode mode,
    required Iterable<String> selectedTypes,
  }) async {
    if (!available) return;
    _filterMode = mode;
    _selectedTypes
      ..clear()
      ..addAll(selectedTypes.map(normalizeType));
    ++_settingsRevision;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait<bool>(<Future<bool>>[
      preferences.setString(filterModeStorageKey, mode.name),
      preferences.setStringList(
        selectedTypesStorageKey,
        _selectedTypes.toList()..sort(),
      ),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('Failed to save websocket type filter.');
    }
  }

  WebSocketCaptureConnection openConnection(Uri uri) {
    return WebSocketCaptureConnection._(
      controller: this,
      connectionId: 'ws-${_nextConnectionId++}',
      uri: uri,
    );
  }

  @visibleForTesting
  void recordFrame({
    required String connectionId,
    required int sequence,
    required WebSocketCaptureDirection direction,
    required Uri uri,
    required String message,
  }) {
    if (!available || !_enabled) return;
    final byteCount = utf8.encode(message).length;
    final oversized = byteCount > maxFrameBodyBytes;
    Map<String, Object?>? jsonMap;
    var isJson = false;
    if (!oversized) {
      try {
        final decoded = jsonDecode(message);
        isJson = true;
        if (decoded is Map) {
          jsonMap = decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {
        isJson = false;
      }
    }
    final type = _field(jsonMap, 'type');
    final bodyText = oversized
        ? '[Message omitted: $byteCount bytes exceeds '
              '$maxFrameBodyBytes-byte limit]'
        : message;
    final record = WebSocketCaptureRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_nextRecordId++}',
      connectionId: connectionId,
      sequence: sequence,
      direction: direction,
      recordedAt: DateTime.now(),
      uri: uri,
      type: type == null ? '' : normalizeType(type),
      streamType: _field(jsonMap, 'stream_type') ?? '',
      worldId: _field(jsonMap, 'world_id') ?? '',
      locationId: _field(jsonMap, 'location_id') ?? '',
      globalMessageId: _field(jsonMap, 'global_message_id') ?? '',
      messageId: _field(jsonMap, 'message_id') ?? '',
      locationMessageId: _field(jsonMap, 'location_message_id') ?? '',
      clientMessageId: _field(jsonMap, 'client_message_id') ?? '',
      byteCount: byteCount,
      bodyText: bodyText,
      isJson: isJson,
      omitted: oversized,
    );
    _records.insert(0, record);
    _enforceLimits();
    _scheduleNotification();
  }

  List<WebSocketCaptureRecord> filteredRecords({String query = ''}) {
    final normalizedQuery = query.trim().toLowerCase();
    return _records
        .where((record) {
          if (_directionFilter != null &&
              record.direction != _directionFilter) {
            return false;
          }
          final selected = _selectedTypes.contains(record.typeKey);
          if (_selectedTypes.isNotEmpty) {
            if (_filterMode == WebSocketCaptureFilterMode.onlyShow &&
                !selected) {
              return false;
            }
            if (_filterMode == WebSocketCaptureFilterMode.hide && selected) {
              return false;
            }
          }
          if (normalizedQuery.isEmpty) return true;
          final searchable = <String>[
            record.direction.name,
            record.typeKey,
            record.streamType,
            record.uri.toString(),
            record.connectionId,
            record.worldId,
            record.locationId,
            record.globalMessageId,
            record.messageId,
            record.locationMessageId,
            record.clientMessageId,
            record.bodyText,
          ].join(' ').toLowerCase();
          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  Map<String, int> typeCounts() {
    final counts = <String, int>{};
    for (final record in _records) {
      counts.update(record.typeKey, (count) => count + 1, ifAbsent: () => 1);
    }
    return Map<String, int>.unmodifiable(counts);
  }

  void clear() {
    if (_records.isEmpty) return;
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _records.clear();
    notifyListeners();
  }

  void _scheduleNotification() {
    if (notificationBatchDuration == Duration.zero) {
      notifyListeners();
      return;
    }
    _notificationTimer ??= Timer(notificationBatchDuration, () {
      _notificationTimer = null;
      notifyListeners();
    });
  }

  void _enforceLimits() {
    var retainedBytes = _records.fold<int>(
      0,
      (total, record) => total + record.retainedBodyBytes,
    );
    while (_records.length > maxRecords || retainedBytes > maxBodyBytes) {
      if (_records.isEmpty) break;
      final removed = _records.removeLast();
      retainedBytes -= removed.retainedBodyBytes;
    }
  }

  void _disableUnavailableCapture() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _enabled = false;
    _records.clear();
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    ++_settingsRevision;
    _enabled = false;
    _directionFilter = null;
    _filterMode = WebSocketCaptureFilterMode.hide;
    _selectedTypes.clear();
    _records.clear();
    _nextConnectionId = 1;
    _nextRecordId = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  static String? _field(Map<String, Object?>? json, String name) {
    final value = json?[name];
    if (value == null || value is Map || value is Iterable) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static WebSocketCaptureDirection? _decodeDirection(String? value) {
    for (final direction in WebSocketCaptureDirection.values) {
      if (direction.name == value) return direction;
    }
    return null;
  }

  static WebSocketCaptureFilterMode _decodeFilterMode(String? value) {
    for (final mode in WebSocketCaptureFilterMode.values) {
      if (mode.name == value) return mode;
    }
    return WebSocketCaptureFilterMode.hide;
  }
}
