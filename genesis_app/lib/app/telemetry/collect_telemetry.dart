import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../network/genesis_http_transport_pool.dart';
import '../../network/http_transport.dart';

const Duration defaultCollectUploadInterval = Duration(seconds: 5);
const int defaultCollectUploadBatchSize = 100;
const int defaultCollectUploadBatchBytes = 256 * 1024;
const int defaultCollectMemoryFallbackLimit = 300;
const Duration defaultCollectStoreTimeout = Duration(seconds: 2);
const Duration defaultCollectRequestTimeout = Duration(seconds: 8);

enum CollectStoreStatus { healthy, recovering, unavailable }

@immutable
class CollectTelemetryHealth {
  const CollectTelemetryHealth({
    required this.storeStatus,
    required this.memoryFallbackCount,
    required this.deadLetterCount,
    required this.droppedEventCount,
    required this.consecutiveUploadFailures,
    this.lastError = '',
    this.lastUploadSuccessAt,
    this.lastUploadFailureAt,
  });

  const CollectTelemetryHealth.initial()
    : storeStatus = CollectStoreStatus.healthy,
      memoryFallbackCount = 0,
      deadLetterCount = 0,
      droppedEventCount = 0,
      consecutiveUploadFailures = 0,
      lastError = '',
      lastUploadSuccessAt = null,
      lastUploadFailureAt = null;

  final CollectStoreStatus storeStatus;
  final int memoryFallbackCount;
  final int deadLetterCount;
  final int droppedEventCount;
  final int consecutiveUploadFailures;
  final String lastError;
  final DateTime? lastUploadSuccessAt;
  final DateTime? lastUploadFailureAt;
}

enum CollectUploadFailureKind { transient, permanent, authorization }

class CollectUploadException implements Exception {
  const CollectUploadException({
    required this.message,
    required this.kind,
    this.statusCode,
    this.errNo,
  });

  final String message;
  final CollectUploadFailureKind kind;
  final int? statusCode;
  final int? errNo;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' status=$statusCode';
    final errorNumber = errNo == null ? '' : ' err_no=$errNo';
    return 'CollectUploadException($message$status$errorNumber)';
  }
}

class CollectEvent {
  const CollectEvent({
    required this.eventId,
    required this.actionType,
    required this.action,
    required this.appTimestamp,
    required this.object1,
    required this.object2,
    required this.object3,
    this.appEnvironment = '',
    this.includeIdentityHeaders = true,
  });

  final String eventId;
  final String actionType;
  final String action;
  final int appTimestamp;
  final String object1;
  final String object2;
  final String object3;
  final String appEnvironment;
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
  Future<void> resetConnection();
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
  Future<Database>? _openingDatabase;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    _database = null;
    final opening = _openingDatabase;
    if (opening != null) return opening;
    final nextOpening = _openDatabase();
    _openingDatabase = nextOpening;
    try {
      final database = await nextOpening;
      if (!identical(_openingDatabase, nextOpening)) {
        await database.close();
        throw StateError('Collect database open was superseded');
      }
      _database = database;
      return database;
    } finally {
      if (identical(_openingDatabase, nextOpening)) {
        _openingDatabase = null;
      }
    }
  }

  Future<Database> _openDatabase() async {
    final factory = _databaseFactory ?? databaseFactory;
    final path =
        databasePath ?? '${await factory.getDatabasesPath()}/$databaseName';
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(_createCollectEventsSql);
          await db.execute(_createCollectEventsStateIndexSql);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute(_addCollectAppEnvironmentSql);
          }
        },
      ),
    );
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
      final oldestRows = await txn.query(
        'collect_events',
        where: 'state = ?',
        whereArgs: <Object>[_pendingState],
        orderBy: 'sequence_id ASC',
        limit: 1,
      );
      if (oldestRows.isEmpty) return null;
      final appEnvironment = '${oldestRows.single['app_environment'] ?? ''}';
      final rows = await txn.query(
        'collect_events',
        where: 'state = ? AND app_environment = ?',
        whereArgs: <Object>[_pendingState, appEnvironment],
        orderBy: 'sequence_id ASC',
        limit: limit,
      );

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
    final opening = _openingDatabase;
    _database = null;
    _openingDatabase = null;
    await database?.close();
    if (database == null && opening != null) {
      try {
        final openedDatabase = await opening;
        await openedDatabase.close();
      } catch (_) {
        // The failed open is the reason the connection is being reset.
      }
    }
  }

  @override
  Future<void> resetConnection() => close();
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
    final appEnvironment = pending.first.event.appEnvironment;
    final selected = pending
        .where((row) => row.event.appEnvironment == appEnvironment)
        .take(limit)
        .toList(growable: false);
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

  @override
  Future<void> resetConnection() async {}
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
       _transport =
           transport ??
           ((debugProxy?.trim().isNotEmpty ?? false)
               ? GenesisHttpTransportRegistry.configure(debugProxy: debugProxy)
               : GenesisHttpTransportRegistry.current);

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
      final statusCode = response.statusCode;
      final kind = statusCode == 401 || statusCode == 403
          ? CollectUploadFailureKind.authorization
          : statusCode == 408 || statusCode == 429 || statusCode >= 500
          ? CollectUploadFailureKind.transient
          : CollectUploadFailureKind.permanent;
      throw CollectUploadException(
        message: 'Collect request failed',
        kind: kind,
        statusCode: statusCode,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const CollectUploadException(
        message: 'Collect response is not valid JSON',
        kind: CollectUploadFailureKind.transient,
      );
    }
    if (decoded is! Map) {
      throw const CollectUploadException(
        message: 'Collect response is not a JSON object',
        kind: CollectUploadFailureKind.transient,
      );
    }
    final errNo = decoded['err_no'];
    if (errNo != 0 && errNo?.toString() != '0') {
      throw CollectUploadException(
        message: 'Collect response err_no is not zero',
        kind: CollectUploadFailureKind.permanent,
        errNo: _asInt(errNo),
      );
    }
  }
}

class CollectTelemetryUploader {
  CollectTelemetryUploader({
    required CollectEventStore store,
    Duration interval = defaultCollectUploadInterval,
    int batchSize = defaultCollectUploadBatchSize,
    int maxBatchBytes = defaultCollectUploadBatchBytes,
    int memoryFallbackLimit = defaultCollectMemoryFallbackLimit,
    Duration storeTimeout = defaultCollectStoreTimeout,
    Duration requestTimeout = defaultCollectRequestTimeout,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _store = store,
       _interval = interval,
       _batchSize = batchSize,
       _maxBatchBytes = maxBatchBytes,
       _memoryFallbackLimit = memoryFallbackLimit,
       _storeTimeout = storeTimeout,
       _requestTimeout = requestTimeout,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? newCollectEventId;

  final CollectEventStore _store;
  final Duration _interval;
  final int _batchSize;
  final int _maxBatchBytes;
  final int _memoryFallbackLimit;
  final Duration _storeTimeout;
  final Duration _requestTimeout;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  CollectTelemetryClient? _client;
  CollectUploadContext _context = const CollectUploadContext();
  Future<void> _pendingWrites = Future<void>.value();
  final List<CollectEvent> _memoryFallback = <CollectEvent>[];
  final List<CollectEvent> _deadLetters = <CollectEvent>[];
  Timer? _timer;
  Timer? _immediateCheckTimer;
  Timer? _storeRecoveryTimer;
  Future<void>? _storeRecovery;
  bool _enabled = false;
  bool _started = false;
  bool _checking = false;
  bool _disposed = false;
  CollectStoreStatus _storeStatus = CollectStoreStatus.healthy;
  int _droppedEventCount = 0;
  int _consecutiveUploadFailures = 0;
  String _lastError = '';
  DateTime? _lastUploadSuccessAt;
  DateTime? _lastUploadFailureAt;
  DateTime? _nextUploadAt;

  bool get isStartedForTesting => _started;
  bool get hasTimerForTesting => _timer != null;
  bool get isCheckingForTesting => _checking;
  List<CollectEvent> get deadLettersForTesting =>
      List<CollectEvent>.unmodifiable(_deadLetters);

  CollectTelemetryHealth get health => CollectTelemetryHealth(
    storeStatus: _storeStatus,
    memoryFallbackCount: _memoryFallback.length,
    deadLetterCount: _deadLetters.length,
    droppedEventCount: _droppedEventCount,
    consecutiveUploadFailures: _consecutiveUploadFailures,
    lastError: _lastError,
    lastUploadSuccessAt: _lastUploadSuccessAt,
    lastUploadFailureAt: _lastUploadFailureAt,
  );

  void configure({required bool enabled, CollectTelemetryClient? client}) {
    _enabled = enabled;
    _client = client;
  }

  void setContext(CollectUploadContext context) {
    _context = context;
  }

  void setAppEnvironment(String value) {
    _context = _context.copyWith(appEnvironment: value.trim());
  }

  void setUserId(String? uid) {
    _context = _context.copyWith(userId: uid?.trim() ?? '');
  }

  Future<void> enqueuePayload(
    Map<String, Object?> payload, {
    bool includeIdentityHeaders = true,
  }) {
    if (!_enabled) return Future<void>.value();
    if (_disposed) {
      _droppedEventCount += 1;
      return Future<void>.value();
    }
    final actionType = _boundedString(payload['action_type'], 64).trim();
    final action = _boundedString(payload['action'], 128).trim();
    if (actionType.isEmpty || action.isEmpty) return Future<void>.value();
    final CollectEvent event;
    try {
      event = CollectEvent(
        eventId: _idGenerator(),
        actionType: actionType,
        action: action,
        appTimestamp: _clock().millisecondsSinceEpoch,
        object1: _boundedString(payload['object1'], 2048),
        object2: _boundedString(payload['object2'], 2048),
        object3: _boundedString(payload['object3'], 2048),
        appEnvironment: _context.appEnvironment,
        includeIdentityHeaders: includeIdentityHeaders,
      );
    } catch (error) {
      _droppedEventCount += 1;
      _recordError('event_build', error);
      return Future<void>.value();
    }
    final previousWrite = _pendingWrites;
    final write = _writeAfter(previousWrite, event);
    _pendingWrites = write.catchError((_) {});
    return write;
  }

  Future<void> _writeAfter(
    Future<void> previousWrite,
    CollectEvent event,
  ) async {
    try {
      await previousWrite.timeout(_storeTimeout);
    } catch (error) {
      _recordStoreFailure('write_chain', error);
    }
    try {
      await _store.enqueue(event).timeout(_storeTimeout);
      _markStoreHealthy();
    } catch (error) {
      _addMemoryFallback(event);
      _recordStoreFailure('enqueue', error);
    } finally {
      _scheduleImmediateCheck();
    }
  }

  void start() {
    if (!_enabled || _client == null || _started || _disposed) return;
    _started = true;
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _pendingWrites.timeout(_storeTimeout);
      await _store.recoverInFlight().timeout(_storeTimeout);
      _markStoreHealthy();
    } catch (error) {
      _recordStoreFailure('startup_recovery', error);
    }
    try {
      await checkNow(force: true);
    } finally {
      _startTimer();
    }
  }

  Future<void> checkNow({bool force = false}) async {
    if (!_enabled || _client == null || _checking || _disposed) return;
    final nextUploadAt = _nextUploadAt;
    if (!force && nextUploadAt != null && _clock().isBefore(nextUploadAt)) {
      return;
    }
    _checking = true;
    ClaimedCollectEventBatch? batch;
    try {
      try {
        await _pendingWrites.timeout(_storeTimeout);
      } catch (error) {
        _recordStoreFailure('pending_writes', error);
      }

      final fallbackCompleted = await _uploadMemoryFallback();
      if (!fallbackCompleted) return;

      try {
        batch = await _store
            .claimPending(limit: _batchSize)
            .timeout(_storeTimeout);
        _markStoreHealthy();
      } catch (error) {
        _recordStoreFailure('claim', error);
        return;
      }
      if (batch == null || batch.events.isEmpty) return;

      final completed = await _uploadWithIsolation(batch.events);
      if (completed) {
        try {
          await _store.deleteClaimed(batch.batchId).timeout(_storeTimeout);
          _markStoreHealthy();
          _recordUploadSuccess();
        } catch (error) {
          // Keep the accepted batch in-flight. Later pending events can still
          // advance; a future app start will recover and retry these event IDs.
          _recordStoreFailure('delete_after_upload', error);
        }
      } else {
        try {
          await _store.releaseClaimed(batch.batchId).timeout(_storeTimeout);
          _markStoreHealthy();
        } catch (error) {
          // Leaving the batch in-flight is safer than putting it back at the
          // queue head and blocking every later event.
          _recordStoreFailure('release_after_failure', error);
        }
      }
    } finally {
      _checking = false;
    }
  }

  Future<bool> _uploadMemoryFallback() async {
    if (_memoryFallback.isEmpty) return true;
    final environment = _memoryFallback.first.appEnvironment;
    final batch = _memoryFallback
        .where((event) => event.appEnvironment == environment)
        .take(_batchSize)
        .toList(growable: false);
    final completed = await _uploadWithIsolation(batch);
    if (!completed) return false;
    final uploadedIds = batch.map((event) => event.eventId).toSet();
    _memoryFallback.removeWhere((event) => uploadedIds.contains(event.eventId));
    _recordUploadSuccess();
    return true;
  }

  Future<bool> _uploadWithIsolation(List<CollectEvent> events) async {
    if (events.isEmpty) return true;
    if (_encodedBatchSize(events) > _maxBatchBytes) {
      if (events.length == 1) {
        _addDeadLetter(events.single, 'payload_too_large');
        return true;
      }
      final middle = events.length ~/ 2;
      final left = await _uploadWithIsolation(events.sublist(0, middle));
      final right = await _uploadWithIsolation(events.sublist(middle));
      return left && right;
    }

    try {
      final includeIdentity = events.every(
        (event) => event.includeIdentityHeaders,
      );
      await _client!
          .collectBatch(
            events,
            headers: _headers(
              includeIdentity: includeIdentity,
              appEnvironment: events.first.appEnvironment,
            ),
          )
          .timeout(_requestTimeout);
      return true;
    } catch (error) {
      final kind = _uploadFailureKind(error);
      if (kind == CollectUploadFailureKind.permanent) {
        if (events.length == 1) {
          _addDeadLetter(events.single, _safeError(error));
          return true;
        }
        final middle = events.length ~/ 2;
        final left = await _uploadWithIsolation(events.sublist(0, middle));
        final right = await _uploadWithIsolation(events.sublist(middle));
        return left && right;
      }
      _recordUploadFailure(error);
      return false;
    }
  }

  void handleAppResumed() {
    if (!_started || _disposed) return;
    _timer?.cancel();
    _timer = null;
    unawaited(_checkAfterResume());
  }

  Future<void> _checkAfterResume() async {
    await checkNow(force: true);
    _startTimer();
  }

  void handleAppBackgrounded() {
    if (!_started || _disposed) return;
    unawaited(checkNow(force: true));
  }

  Future<void> waitForPendingWrites() async {
    try {
      await _pendingWrites.timeout(_storeTimeout);
    } catch (_) {
      // The event has already fallen back to memory, or will do so when its
      // timed operation completes. Tests and shutdown paths must not hang.
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _immediateCheckTimer?.cancel();
    _immediateCheckTimer = null;
    _storeRecoveryTimer?.cancel();
    _storeRecoveryTimer = null;
  }

  void _startTimer() {
    if (!_started || _disposed || _timer != null) return;
    _timer = Timer.periodic(_interval, (_) {
      unawaited(checkNow());
    });
  }

  void _scheduleImmediateCheck() {
    if (!_started || _disposed || _immediateCheckTimer != null) return;
    _immediateCheckTimer = Timer(Duration.zero, () {
      _immediateCheckTimer = null;
      unawaited(checkNow());
    });
  }

  void _addMemoryFallback(CollectEvent event) {
    if (_memoryFallback.any((item) => item.eventId == event.eventId)) return;
    if (_memoryFallbackLimit <= 0) {
      _droppedEventCount += 1;
      return;
    }
    while (_memoryFallback.length >= _memoryFallbackLimit) {
      _memoryFallback.removeAt(0);
      _droppedEventCount += 1;
    }
    _memoryFallback.add(event);
  }

  void _addDeadLetter(CollectEvent event, String reason) {
    if (_deadLetters.length >= 100) _deadLetters.removeAt(0);
    _deadLetters.add(event);
    _lastError = 'dead_letter:${event.action}:${_boundedString(reason, 256)}';
    debugPrint('[Collect] isolated invalid event ${event.eventId}: $reason');
  }

  void _recordUploadSuccess() {
    _lastUploadSuccessAt = _clock();
    _consecutiveUploadFailures = 0;
    _nextUploadAt = null;
  }

  void _recordUploadFailure(Object error) {
    _lastUploadFailureAt = _clock();
    _consecutiveUploadFailures += 1;
    _lastError = 'upload:${_safeError(error)}';
    _nextUploadAt = _clock().add(_retryDelay(_consecutiveUploadFailures));
    debugPrint('[Collect] upload failed: $error');
  }

  void _recordStoreFailure(String operation, Object error) {
    _storeStatus = CollectStoreStatus.unavailable;
    _recordError('sqlite_$operation', error);
    _scheduleStoreRecovery();
  }

  void _recordError(String operation, Object error) {
    _lastError = '$operation:${_safeError(error)}';
    debugPrint('[Collect] $operation failed: $error');
  }

  void _markStoreHealthy() {
    _storeStatus = CollectStoreStatus.healthy;
  }

  void _scheduleStoreRecovery() {
    if (_disposed || _storeRecovery != null || _storeRecoveryTimer != null) {
      return;
    }
    _storeRecoveryTimer = Timer(const Duration(seconds: 1), () {
      _storeRecoveryTimer = null;
      if (_checking) {
        _scheduleStoreRecovery();
        return;
      }
      final recovery = _recoverStore();
      _storeRecovery = recovery;
      unawaited(
        recovery.whenComplete(() {
          if (identical(_storeRecovery, recovery)) _storeRecovery = null;
        }),
      );
    });
  }

  Future<void> _recoverStore() async {
    if (_disposed) return;
    _storeStatus = CollectStoreStatus.recovering;
    try {
      await _store.resetConnection().timeout(_storeTimeout);
      _markStoreHealthy();
      _scheduleImmediateCheck();
    } catch (error) {
      _recordStoreFailure('reopen', error);
    }
  }

  Map<String, String> _headers({
    required bool includeIdentity,
    required String appEnvironment,
  }) {
    return <String, String>{
      for (final entry in <String, String?>{
        'X-Platform': _collectPlatformHeaderValue(_context.platform),
        'X-App-Version': _context.appVersion,
        'x-app-environment': appEnvironment.trim().isEmpty
            ? _context.appEnvironment
            : appEnvironment,
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
    'app_environment': event.appEnvironment,
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
    appEnvironment: '${row['app_environment'] ?? ''}',
    includeIdentityHeaders: (row['include_identity_headers'] as int? ?? 1) != 0,
  );
}

String _stringValue(Object? value) {
  if (value == null) return '';
  return value.toString();
}

String _boundedString(Object? value, int maxLength) {
  final text = _stringValue(value);
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength);
}

int _encodedBatchSize(List<CollectEvent> events) {
  return utf8
      .encode(
        jsonEncode(<String, Object>{
          'events': events.map((event) => event.toWireMap()).toList(),
        }),
      )
      .length;
}

CollectUploadFailureKind _uploadFailureKind(Object error) {
  if (error is CollectUploadException) return error.kind;
  return CollectUploadFailureKind.transient;
}

Duration _retryDelay(int failureCount) {
  return switch (failureCount) {
    <= 1 => const Duration(seconds: 5),
    2 => const Duration(seconds: 15),
    3 => const Duration(seconds: 30),
    4 => const Duration(minutes: 1),
    _ => const Duration(minutes: 5),
  };
}

String _safeError(Object error) {
  if (error is CollectUploadException) return error.toString();
  return error.runtimeType.toString();
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
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
    app_environment TEXT NOT NULL DEFAULT '',
    include_identity_headers INTEGER NOT NULL,
    state TEXT NOT NULL,
    batch_id TEXT
  )
''';

const _createCollectEventsStateIndexSql = '''
  CREATE INDEX idx_collect_events_state_sequence
  ON collect_events(state, sequence_id)
''';

const _addCollectAppEnvironmentSql = '''
  ALTER TABLE collect_events
  ADD COLUMN app_environment TEXT NOT NULL DEFAULT ''
''';
