import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../network/api_exception.dart';

typedef AppEventReportSender = Future<void> Function(AppEventReport report);
typedef AppEventReportEnvironmentProvider = String Function();

String eventReportEnvironmentForFirebase(String firebaseEnvironment) {
  return firebaseEnvironment.trim().toLowerCase() == 'production'
      ? 'production'
      : 'sandbox';
}

@immutable
class AppEventReport {
  const AppEventReport({
    required this.event,
    required this.environment,
    required this.occurredAtSeconds,
    required this.params,
    required this.reportKey,
    this.transactionId,
  });

  final String event;
  final String environment;
  final int occurredAtSeconds;
  final Map<String, String> params;
  final String reportKey;
  final String? transactionId;
}

abstract interface class AppEventReportStore {
  Future<void> enqueue(AppEventReport report);

  Future<List<AppEventReport>> pending({required int limit});

  Future<void> markDelivered(String reportKey);

  Future<void> close();
}

class SqfliteAppEventReportStore implements AppEventReportStore {
  SqfliteAppEventReportStore({
    this.databaseName = 'genesis_app_event_reports.db',
    DatabaseFactory? databaseFactoryOverride,
    this.databasePath,
  }) : _databaseFactory = databaseFactoryOverride;

  final String databaseName;
  final String? databasePath;
  final DatabaseFactory? _databaseFactory;
  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get _db async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    final opening = _openingDatabase;
    if (opening != null) return opening;
    final next = _openDatabase();
    _openingDatabase = next;
    try {
      final database = await next;
      _database = database;
      return database;
    } finally {
      if (identical(_openingDatabase, next)) _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() async {
    final factory = _databaseFactory ?? databaseFactory;
    final path =
        databasePath ?? '${await factory.getDatabasesPath()}/$databaseName';
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (database, _) => database.execute('''
CREATE TABLE app_event_reports (
  sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_key TEXT NOT NULL UNIQUE,
  event_name TEXT NOT NULL,
  environment TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  transaction_id TEXT,
  params_json TEXT NOT NULL,
  delivered INTEGER NOT NULL DEFAULT 0
)
'''),
        onUpgrade: (database, oldVersion, _) async {
          if (oldVersion < 2) {
            await database.execute(
              'ALTER TABLE app_event_reports '
              'ADD COLUMN occurred_at INTEGER NOT NULL DEFAULT 0',
            );
            await database.update('app_event_reports', <String, Object?>{
              'occurred_at':
                  DateTime.now().toUtc().millisecondsSinceEpoch ~/
                  Duration.millisecondsPerSecond,
            }, where: 'occurred_at = 0');
          }
          if (oldVersion < 3) {
            // Version 2 stored UTC Unix microseconds. Preserve queued event
            // occurrence times while migrating the API contract to seconds.
            await database.execute('''
UPDATE app_event_reports
SET occurred_at = occurred_at / 1000000
WHERE occurred_at >= 100000000000000
''');
          }
          if (oldVersion < 4) {
            await database.execute(
              'ALTER TABLE app_event_reports '
              'ADD COLUMN transaction_id TEXT',
            );
            await database.execute('''
UPDATE app_event_reports
SET transaction_id = CASE
  WHEN business_id LIKE 'gems:%' THEN substr(business_id, 6)
  WHEN business_id LIKE 'subscription:%' THEN substr(business_id, 14)
  ELSE business_id
END
WHERE business_id IS NOT NULL
''');
          }
        },
      ),
    );
  }

  @override
  Future<void> enqueue(AppEventReport report) async {
    await (await _db).insert('app_event_reports', <String, Object?>{
      'report_key': report.reportKey,
      'event_name': report.event,
      'environment': report.environment,
      'occurred_at': report.occurredAtSeconds,
      'transaction_id': report.transactionId,
      'params_json': jsonEncode(report.params),
      'delivered': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<AppEventReport>> pending({required int limit}) async {
    if (limit <= 0) return const <AppEventReport>[];
    final rows = await (await _db).query(
      'app_event_reports',
      where: 'delivered = 0',
      orderBy: 'sequence_id ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> markDelivered(String reportKey) async {
    await (await _db).update(
      'app_event_reports',
      const <String, Object?>{'delivered': 1},
      where: 'report_key = ?',
      whereArgs: <Object>[reportKey],
    );
  }

  @override
  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }

  AppEventReport _fromRow(Map<String, Object?> row) {
    final decoded = jsonDecode('${row['params_json']}');
    if (decoded is! Map) {
      throw const FormatException('Invalid app event params');
    }
    return AppEventReport(
      event: '${row['event_name']}',
      environment: '${row['environment']}',
      occurredAtSeconds: row['occurred_at'] as int,
      params: <String, String>{
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value.toString(),
      },
      reportKey: '${row['report_key']}',
      transactionId: row['transaction_id']?.toString(),
    );
  }
}

/// Durable, best-effort S2S event delivery for the Adjust event bridge.
///
/// A row is persisted before the HTTP call. Successful rows remain as compact
/// delivery markers so device-once and transaction-scoped events stay
/// idempotent across app restarts. Failed rows are retried in order.
class AppEventReporting {
  AppEventReporting({
    required AppEventReportSender sender,
    required AppEventReportEnvironmentProvider environmentProvider,
    AppEventReportStore? store,
    Duration initialRetryDelay = const Duration(seconds: 2),
    Duration maximumRetryDelay = const Duration(minutes: 1),
  }) : _sender = sender,
       _environmentProvider = environmentProvider,
       _store = store ?? SqfliteAppEventReportStore(),
       _initialRetryDelay = initialRetryDelay,
       _maximumRetryDelay = maximumRetryDelay,
       _retryDelay = initialRetryDelay;

  static const Set<String> supportedEvents = <String>{
    'login_first',
    'message_sent_first',
    'message_sent_10_first',
    'message_sent_20_first',
    'purchase',
    'purchase_first',
    'purchase_day0',
    'purchase_first_day0',
    'gems',
    'gems_first',
    'gems_day0',
    'gems_first_day0',
    'subscription',
    'subscription_first',
    'subscription_day0',
    'subscription_first_day0',
  };

  static const Set<String> transactionEvents = <String>{
    'purchase',
    'purchase_first',
    'purchase_day0',
    'purchase_first_day0',
    'gems',
    'gems_first',
    'gems_day0',
    'gems_first_day0',
    'subscription',
    'subscription_first',
    'subscription_day0',
    'subscription_first_day0',
  };

  final AppEventReportSender _sender;
  final AppEventReportEnvironmentProvider _environmentProvider;
  final AppEventReportStore _store;
  final Duration _initialRetryDelay;
  final Duration _maximumRetryDelay;
  Duration _retryDelay;
  Timer? _retryTimer;
  Future<void>? _flushTask;
  bool _disposed = false;

  Future<void> report({
    required String event,
    required int occurredAtSeconds,
    required Map<String, Object> parameters,
    String? transactionId,
  }) async {
    if (_disposed || !supportedEvents.contains(event)) return;
    if (occurredAtSeconds <= 0) {
      throw ArgumentError.value(
        occurredAtSeconds,
        'occurredAtSeconds',
        'must be a positive UTC Unix timestamp in seconds',
      );
    }
    final normalizedTransactionId = transactionId?.trim() ?? '';
    if (transactionEvents.contains(event) && normalizedTransactionId.isEmpty) {
      debugPrint(
        '[Telemetry][EventReport] $event skipped: missing transaction_id',
      );
      return;
    }
    final effectiveTransactionId = transactionEvents.contains(event)
        ? normalizedTransactionId
        : null;
    final params = <String, String>{
      for (final entry in parameters.entries)
        entry.key: _parameterValue(entry.value),
    };
    final environment = _environmentProvider();
    if (environment != 'sandbox' && environment != 'production') {
      throw StateError(
        'Event report environment must be sandbox or production, got: '
        '$environment',
      );
    }
    final reportKey = sha256
        .convert(
          utf8.encode(
            jsonEncode(<Object?>[
              environment,
              event,
              effectiveTransactionId ?? '',
            ]),
          ),
        )
        .toString();
    try {
      await _store.enqueue(
        AppEventReport(
          event: event,
          environment: environment,
          occurredAtSeconds: occurredAtSeconds,
          params: params,
          reportKey: reportKey,
          transactionId: effectiveTransactionId,
        ),
      );
      unawaited(_flushAfterEnqueue());
    } catch (error, stackTrace) {
      debugPrint('[Telemetry][EventReport] $event enqueue failed: $error');
      debugPrint('[Telemetry][EventReport] stacktrace:\n$stackTrace');
      _scheduleRetry();
    }
  }

  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    final current = _flushTask;
    if (current != null) return current;
    late final Future<void> task;
    task = _flush().whenComplete(() {
      if (identical(_flushTask, task)) _flushTask = null;
    });
    _flushTask = task;
    return task;
  }

  Future<void> _flushAfterEnqueue() async {
    await flush();
    // An enqueue can race with the final empty read of an existing flush.
    // Run one fresh pass after that task completes, unless it scheduled a
    // backoff for a retryable delivery failure.
    if (!_disposed && _retryTimer?.isActive != true) await flush();
  }

  Future<void> _flush() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    while (!_disposed) {
      late final List<AppEventReport> pending;
      try {
        pending = await _store.pending(limit: 20);
      } catch (error, stackTrace) {
        debugPrint('[Telemetry][EventReport] outbox read failed: $error');
        debugPrint('[Telemetry][EventReport] stacktrace:\n$stackTrace');
        _scheduleRetry();
        return;
      }
      if (pending.isEmpty) {
        _retryDelay = _initialRetryDelay;
        return;
      }
      for (final report in pending) {
        try {
          await _sender(report);
          await _store.markDelivered(report.reportKey);
          _retryDelay = _initialRetryDelay;
        } catch (error, stackTrace) {
          debugPrint(
            '[Telemetry][EventReport] ${report.event} delivery failed: $error',
          );
          debugPrint('[Telemetry][EventReport] stacktrace:\n$stackTrace');
          if (!_isRetryable(error)) {
            await _store.markDelivered(report.reportKey);
            continue;
          }
          _scheduleRetry();
          return;
        }
      }
    }
  }

  void _scheduleRetry() {
    if (_disposed || _retryTimer?.isActive == true) return;
    final delay = _retryDelay;
    final nextMilliseconds = (_retryDelay.inMilliseconds * 2).clamp(
      _initialRetryDelay.inMilliseconds,
      _maximumRetryDelay.inMilliseconds,
    );
    _retryDelay = Duration(milliseconds: nextMilliseconds);
    _retryTimer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _flushTask;
    await _store.close();
  }

  static String _parameterValue(Object value) => switch (value) {
    String value => value,
    num value => value.toString(),
    bool value => value.toString(),
    _ => value.toString(),
  };

  static bool _isRetryable(Object error) {
    if (error is! ApiException) return true;
    if (error.retryable) return true;
    return switch (error.kind) {
      ApiExceptionKind.transport ||
      ApiExceptionKind.timeout ||
      ApiExceptionKind.gatewayAuth ||
      ApiExceptionKind.response ||
      ApiExceptionKind.cancelled ||
      ApiExceptionKind.unknown => true,
      ApiExceptionKind.httpStatus =>
        error.statusCode == 408 ||
            error.statusCode == 429 ||
            (error.statusCode ?? 0) >= 500,
      ApiExceptionKind.business => false,
    };
  }
}
