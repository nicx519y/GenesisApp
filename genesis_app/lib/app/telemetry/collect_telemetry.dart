import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../network/http_transport.dart';
import '../../network/io_http_transport.dart';

const Duration defaultCollectUploadInterval = Duration(seconds: 5);
const int defaultCollectUploadBatchSize = 500;

class CollectEvent {
  const CollectEvent({
    required this.eventId,
    required this.actionType,
    required this.action,
    required this.appTimestamp,
    required this.object1,
    required this.object2,
    required this.object3,
    this.includeIdentityHeaders = true,
  });

  final String eventId;
  final String actionType;
  final String action;
  final int appTimestamp;
  final String object1;
  final String object2;
  final String object3;
  final bool includeIdentityHeaders;

  Map<String, Object> toWireMap() {
    return <String, Object>{
      'event_id': eventId,
      'action_type': actionType,
      'action': action,
      'app_timestamp': appTimestamp,
      'object1': object1,
      'object2': object2,
      'object3': object3,
    };
  }
}

class ClaimedCollectEventBatch {
  const ClaimedCollectEventBatch({required this.batchId, required this.events});

  final String batchId;
  final List<CollectEvent> events;
}

abstract interface class CollectEventStore {
  Future<void> enqueue(CollectEvent event);
  Future<void> recoverInFlight();
  Future<ClaimedCollectEventBatch?> claimPending({required int limit});
  Future<void> deleteClaimed(String batchId);
  Future<void> releaseClaimed(String batchId);
}

class SqfliteCollectEventStore implements CollectEventStore {
  SqfliteCollectEventStore({
    this.databaseName = 'genesis_collect_events.db',
    DatabaseFactory? databaseFactoryOverride,
    this.databasePath,
  }) : _databaseFactory = databaseFactoryOverride;

  final String databaseName;
  final String? databasePath;
  final DatabaseFactory? _databaseFactory;
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final factory = _databaseFactory ?? databaseFactory;
    final path =
        databasePath ?? '${await factory.getDatabasesPath()}/$databaseName';
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(_createCollectEventsSql);
          await db.execute(_createCollectEventsStateIndexSql);
        },
      ),
    );
    _database = database;
    return database;
  }

  @override
  Future<void> enqueue(CollectEvent event) async {
    await (await _db).insert(
      'collect_events',
      _eventToRow(event),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> recoverInFlight() async {
    await (await _db).update(
      'collect_events',
      <String, Object?>{'state': _pendingState, 'batch_id': null},
      where: 'state = ?',
      whereArgs: <Object>[_inFlightState],
    );
  }

  @override
  Future<ClaimedCollectEventBatch?> claimPending({required int limit}) async {
    if (limit <= 0) return null;
    return (await _db).transaction((txn) async {
      final rows = await txn.query(
        'collect_events',
        where: 'state = ?',
        whereArgs: <Object>[_pendingState],
        orderBy: 'sequence_id ASC',
        limit: limit,
      );
      if (rows.isEmpty) return null;

      final batchId = newCollectEventId();
      final eventIds = rows
          .map((row) => '${row['event_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final placeholders = List.filled(eventIds.length, '?').join(',');
      await txn.update(
        'collect_events',
        <String, Object?>{'state': _inFlightState, 'batch_id': batchId},
        where: 'state = ? AND event_id IN ($placeholders)',
        whereArgs: <Object>[_pendingState, ...eventIds],
      );
      return ClaimedCollectEventBatch(
        batchId: batchId,
        events: rows.map(_eventFromRow).toList(growable: false),
      );
    });
  }

  @override
  Future<void> deleteClaimed(String batchId) async {
    await (await _db).delete(
      'collect_events',
      where: 'state = ? AND batch_id = ?',
      whereArgs: <Object>[_inFlightState, batchId],
    );
  }

  @override
  Future<void> releaseClaimed(String batchId) async {
    await (await _db).update(
      'collect_events',
      <String, Object?>{'state': _pendingState, 'batch_id': null},
      where: 'state = ? AND batch_id = ?',
      whereArgs: <Object>[_inFlightState, batchId],
    );
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}

class MemoryCollectEventStore implements CollectEventStore {
  final List<_MemoryCollectEventRow> _rows = <_MemoryCollectEventRow>[];
  var _nextSequence = 1;

  List<CollectEvent> get eventsForTesting =>
      _rows.map((row) => row.event).toList(growable: false);

  int get pendingCountForTesting =>
      _rows.where((row) => row.state == _pendingState).length;

  int get inFlightCountForTesting =>
      _rows.where((row) => row.state == _inFlightState).length;

  @override
  Future<void> enqueue(CollectEvent event) async {
    if (_rows.any((row) => row.event.eventId == event.eventId)) return;
    _rows.add(_MemoryCollectEventRow(_nextSequence++, event));
  }

  @override
  Future<void> recoverInFlight() async {
    for (final row in _rows) {
      if (row.state != _inFlightState) continue;
      row
        ..state = _pendingState
        ..batchId = null;
    }
  }

  @override
  Future<ClaimedCollectEventBatch?> claimPending({required int limit}) async {
    if (limit <= 0) return null;
    final pending =
        _rows.where((row) => row.state == _pendingState).toList(growable: false)
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (pending.isEmpty) return null;
    final selected = pending.take(limit).toList(growable: false);
    final batchId = newCollectEventId();
    for (final row in selected) {
      row
        ..state = _inFlightState
        ..batchId = batchId;
    }
    return ClaimedCollectEventBatch(
      batchId: batchId,
      events: selected.map((row) => row.event).toList(growable: false),
    );
  }

  @override
  Future<void> deleteClaimed(String batchId) async {
    _rows.removeWhere(
      (row) => row.state == _inFlightState && row.batchId == batchId,
    );
  }

  @override
  Future<void> releaseClaimed(String batchId) async {
    for (final row in _rows) {
      if (row.state != _inFlightState || row.batchId != batchId) continue;
      row
        ..state = _pendingState
        ..batchId = null;
    }
  }
}

class CollectUploadContext {
  const CollectUploadContext({
    this.platform = '',
    this.appVersion = '',
    this.appEnvironment = 'production',
    this.deviceId = '',
    this.userId = '',
  });

  final String platform;
  final String appVersion;
  final String appEnvironment;
  final String deviceId;
  final String userId;

  CollectUploadContext copyWith({
    String? platform,
    String? appVersion,
    String? appEnvironment,
    String? deviceId,
    String? userId,
  }) {
    return CollectUploadContext(
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      appEnvironment: appEnvironment ?? this.appEnvironment,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
    );
  }
}

abstract interface class CollectTelemetryClient {
  Future<void> collectBatch(
    List<CollectEvent> events, {
    Map<String, String> headers = const <String, String>{},
  });
}

class SdkCollectTelemetryClient implements CollectTelemetryClient {
  SdkCollectTelemetryClient({
    required String endpoint,
    HttpTransport? transport,
    String? debugProxy,
    this.timeoutMs = 5000,
  }) : _endpoint = Uri.parse(endpoint),
       _transport = transport ?? IoHttpTransport(proxy: debugProxy);

  final Uri _endpoint;
  final HttpTransport _transport;
  final int timeoutMs;

  @override
  Future<void> collectBatch(
    List<CollectEvent> events, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await _transport.send(
      TransportRequest(
        method: 'POST',
        uri: _endpoint,
        headers: <String, String>{
          'content-type': 'application/json',
          'accept': 'application/json',
          ...headers,
        },
        bodyBytes: utf8.encode(
          jsonEncode(<String, Object>{
            'events': events.map((event) => event.toWireMap()).toList(),
          }),
        ),
        timeoutMs: timeoutMs,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Collect request failed: ${response.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const FormatException('Collect response is not valid JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('Collect response is not a JSON object');
    }
    final errNo = decoded['err_no'];
    if (errNo != 0 && errNo?.toString() != '0') {
      throw StateError('Collect response err_no is not zero: $errNo');
    }
  }
}

class CollectTelemetryUploader {
  CollectTelemetryUploader({
    required CollectEventStore store,
    Duration interval = defaultCollectUploadInterval,
    int batchSize = defaultCollectUploadBatchSize,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _store = store,
       _interval = interval,
       _batchSize = batchSize,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? newCollectEventId;

  final CollectEventStore _store;
  final Duration _interval;
  final int _batchSize;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  CollectTelemetryClient? _client;
  CollectUploadContext _context = const CollectUploadContext();
  Future<void> _pendingWrites = Future<void>.value();
  Timer? _timer;
  bool _enabled = false;
  bool _started = false;
  bool _checking = false;
  bool _disposed = false;

  bool get isStartedForTesting => _started;
  bool get hasTimerForTesting => _timer != null;

  void configure({required bool enabled, CollectTelemetryClient? client}) {
    _enabled = enabled;
    _client = client;
  }

  void setContext(CollectUploadContext context) {
    _context = context;
  }

  void setUserId(String? uid) {
    _context = _context.copyWith(userId: uid?.trim() ?? '');
  }

  Future<void> enqueuePayload(
    Map<String, Object?> payload, {
    bool includeIdentityHeaders = true,
  }) {
    if (!_enabled || _disposed) return Future<void>.value();
    final actionType = '${payload['action_type'] ?? ''}'.trim();
    final action = '${payload['action'] ?? ''}'.trim();
    if (actionType.isEmpty || action.isEmpty) return Future<void>.value();
    final event = CollectEvent(
      eventId: _idGenerator(),
      actionType: actionType,
      action: action,
      appTimestamp: _clock().millisecondsSinceEpoch,
      object1: _stringValue(payload['object1']),
      object2: _stringValue(payload['object2']),
      object3: _stringValue(payload['object3']),
      includeIdentityHeaders: includeIdentityHeaders,
    );
    final write = _pendingWrites.then((_) => _store.enqueue(event));
    _pendingWrites = write.catchError((_) {});
    return write;
  }

  void start() {
    if (!_enabled || _client == null || _started || _disposed) return;
    _started = true;
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _pendingWrites;
      await _store.recoverInFlight();
      await checkNow();
    } finally {
      _startTimer();
    }
  }

  Future<void> checkNow() async {
    if (!_enabled || _client == null || _checking || _disposed) return;
    _checking = true;
    ClaimedCollectEventBatch? batch;
    try {
      await _pendingWrites;
      batch = await _store.claimPending(limit: _batchSize);
      if (batch == null || batch.events.isEmpty) return;
      final includeIdentity = batch.events.every(
        (event) => event.includeIdentityHeaders,
      );
      await _client!.collectBatch(
        batch.events,
        headers: _headers(includeIdentity: includeIdentity),
      );
      await _store.deleteClaimed(batch.batchId);
    } catch (_) {
      final failedBatch = batch;
      if (failedBatch != null) {
        try {
          await _store.releaseClaimed(failedBatch.batchId);
        } catch (_) {
          // The startup recovery pass will release it on the next app launch.
        }
      }
    } finally {
      _checking = false;
    }
  }

  void handleAppResumed() {
    if (!_started || _disposed) return;
    _timer?.cancel();
    _timer = null;
    unawaited(_checkAfterResume());
  }

  Future<void> _checkAfterResume() async {
    await checkNow();
    _startTimer();
  }

  Future<void> waitForPendingWrites() => _pendingWrites;

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    if (!_started || _disposed || _timer != null) return;
    _timer = Timer.periodic(_interval, (_) {
      unawaited(checkNow());
    });
  }

  Map<String, String> _headers({required bool includeIdentity}) {
    return <String, String>{
      for (final entry in <String, String?>{
        'X-Platform': _collectPlatformHeaderValue(_context.platform),
        'X-App-Version': _context.appVersion,
        'x-app-environment': _context.appEnvironment,
        if (includeIdentity) 'X-Device-ID': _context.deviceId,
        if (includeIdentity) 'X-UID': _context.userId,
      }.entries)
        if ((entry.value ?? '').trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };
  }
}

class _MemoryCollectEventRow {
  _MemoryCollectEventRow(this.sequence, this.event);

  final int sequence;
  final CollectEvent event;
  String state = _pendingState;
  String? batchId;
}

Map<String, Object?> _eventToRow(CollectEvent event) {
  return <String, Object?>{
    'event_id': event.eventId,
    'action_type': event.actionType,
    'action': event.action,
    'app_timestamp': event.appTimestamp,
    'object1': event.object1,
    'object2': event.object2,
    'object3': event.object3,
    'include_identity_headers': event.includeIdentityHeaders ? 1 : 0,
    'state': _pendingState,
    'batch_id': null,
  };
}

CollectEvent _eventFromRow(Map<String, Object?> row) {
  return CollectEvent(
    eventId: '${row['event_id'] ?? ''}',
    actionType: '${row['action_type'] ?? ''}',
    action: '${row['action'] ?? ''}',
    appTimestamp: row['app_timestamp'] as int? ?? 0,
    object1: '${row['object1'] ?? ''}',
    object2: '${row['object2'] ?? ''}',
    object3: '${row['object3'] ?? ''}',
    includeIdentityHeaders: (row['include_identity_headers'] as int? ?? 1) != 0,
  );
}

String _stringValue(Object? value) {
  if (value == null) return '';
  return value.toString();
}

String _collectPlatformHeaderValue(String platform) {
  final normalized = platform.trim().toLowerCase();
  if (normalized == 'ios') return 'ios';
  if (normalized == 'android') return 'android';
  return platform.trim();
}

String newCollectEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

const _pendingState = 'pending';
const _inFlightState = 'inflight';

const _createCollectEventsSql = '''
  CREATE TABLE collect_events (
    sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    action_type TEXT NOT NULL,
    action TEXT NOT NULL,
    app_timestamp INTEGER NOT NULL,
    object1 TEXT NOT NULL,
    object2 TEXT NOT NULL,
    object3 TEXT NOT NULL,
    include_identity_headers INTEGER NOT NULL,
    state TEXT NOT NULL,
    batch_id TEXT
  )
''';

const _createCollectEventsStateIndexSql = '''
  CREATE INDEX idx_collect_events_state_sequence
  ON collect_events(state, sequence_id)
''';
