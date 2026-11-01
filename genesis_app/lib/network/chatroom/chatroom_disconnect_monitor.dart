import 'chatroom_connect_deadline.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../../platform/network/network_type_snapshot.dart';

typedef DisconnectReport =
    void Function({
      required String worldId,
      required String phase,
      required String cause,
      required String networkType,
      required String extData,
    });

typedef ReconnectSuccessReport =
    void Function({
      required String worldId,
      required String phase,
      required String recoveryId,
      required int retryCount,
      required int durationMs,
      required int connectAttempts,
    });

/// One disconnect and, only after that report, one success per recovery round.
class ChatroomDisconnectMonitor with WidgetsBindingObserver {
  ChatroomDisconnectMonitor({
    this.retryFailureThreshold = 5,
    this.timeoutThreshold = 2,
    Future<String> Function()? readNetworkType,
    DisconnectReport? report,
    ReconnectSuccessReport? reportSuccess,
    DateTime Function()? now,
  }) : _readNetworkType = readNetworkType ?? NetworkTypeSnapshot.read,
       _report = report ?? _collect,
       _reportSuccess = reportSuccess ?? _collectSuccess,
       _now = now ?? DateTime.now {
    try {
      _binding = WidgetsBinding.instance;
    } catch (_) {
      // Headless protocol tests may have no Flutter binding.
    }
    final state = _binding?.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _binding?.addObserver(this);
  }

  final int retryFailureThreshold;
  final int timeoutThreshold;
  int _retryFailures = 0;
  int _timeouts = 0;
  int _completedAttempt = -1;
  bool _attemptForeground = true;
  bool _attemptIsRetry = false;
  final Future<String> Function() _readNetworkType;
  final DisconnectReport _report;
  final ReconnectSuccessReport _reportSuccess;
  final DateTime Function() _now;
  DateTime? _recoveryForegroundSince;
  Duration _recoveryElapsed = Duration.zero;
  bool _hasAttempt = false;
  bool _initialAttemptCounted = false;
  int _recoveryAttempts = 0;
  String? _recoveryId;
  bool _recovering = false;

  WidgetsBinding? _binding;
  bool _foreground = true;
  bool _needed = false;
  bool _connected = false;
  bool _everConnected = false;
  bool _disposed = false;
  bool _reported = false;
  int _generation = 0;
  int _networkGeneration = -1;
  int _attempt = 0;
  String _worldId = '';
  String _owner = '';
  String _networkType = 'unknown';
  String? _cause;
  String? _errorCode;
  int? _closeCode;
  final _details = <Map<String, Object?>>[];
  Stopwatch? _attemptClock;

  static void _collect({
    required String worldId,
    required String phase,
    required String cause,
    required String networkType,
    required String extData,
  }) {
    GenesisTelemetry.collectLog(
      actionType: 'monitor',
      action: 'websocket_disconnect',
      object1: worldId,
      object2: phase,
      object4: networkType,
      extData: extData,
    );
  }

  static void _collectSuccess({
    required String worldId,
    required String phase,
    required String recoveryId,
    required int retryCount,
    required int durationMs,
    required int connectAttempts,
  }) {
    GenesisTelemetry.collectLog(
      actionType: 'monitor',
      action: 'websocket_reconnect_success',
      object1: worldId,
      object2: retryCount.toString(),
      object3: durationMs.toString(),
      object4: phase,
      extData: jsonEncode({
        'recovery_id': recoveryId,
        'connect_attempts': connectAttempts,
        'duration_unit': 'ms',
        'duration_scope': 'foreground_recovery',
        'attempts_scope': 'foreground',
        'success_stage': 'ws_connected',
      }),
    );
  }

  void _startRecovery() {
    if (_recovering) return;
    _recovering = true;
    _recoveryId = const Uuid().v4();
    if (_foreground) _recoveryForegroundSince = _now();
  }

  void _resetRecovery() {
    _recovering = false;
    _recoveryForegroundSince = null;
    _recoveryElapsed = Duration.zero;
    _hasAttempt = false;
    _initialAttemptCounted = false;
    _recoveryAttempts = 0;
    _retryFailures = 0;
    _timeouts = 0;
    _recoveryId = null;
  }

  void activate(String worldId, String owner) {
    if (_disposed) return;
    if (_worldId != worldId || _owner != owner) {
      cancel();
      _worldId = worldId;
      _owner = owner;
    }
    _needed = true;
  }

  int beginAttempt() {
    _attempt++;
    _attemptClock = Stopwatch()..start();
    if (!_disposed && _needed && !_connected) {
      _startRecovery();
      _attemptForeground = _foreground;
      _attemptIsRetry = _everConnected || _hasAttempt;
      if (!_hasAttempt) {
        _hasAttempt = true;
        _initialAttemptCounted = _foreground;
      }
      if (_foreground) _recoveryAttempts++;
      _observe();
    }
    return _attempt;
  }

  void succeeded(int attempt) {
    if (!_needed || _disposed || attempt != _attempt) return;
    if (_connected) return;
    if (_recovering && _reported) {
      final elapsed =
          _recoveryElapsed +
          (_recoveryForegroundSince == null
              ? Duration.zero
              : _now().difference(_recoveryForegroundSince!));
      try {
        _reportSuccess(
          recoveryId: _recoveryId!,
          worldId: _worldId,
          phase: _everConnected ? 'reconnect' : 'initial_connect',
          retryCount: _everConnected
              ? _recoveryAttempts
              : (_recoveryAttempts - (_initialAttemptCounted ? 1 : 0)).clamp(
                  0,
                  _recoveryAttempts,
                ),
          durationMs: elapsed.inMilliseconds.clamp(0, 1 << 53),
          connectAttempts: _recoveryAttempts,
        );
      } catch (_) {
        /* Diagnostics must not affect reconnect. */
      }
    }
    _resetRecovery();
    _connected = true;
    _everConnected = true;
    _clearObservation();
  }

  void connectFailed(
    int attempt, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?> connectionDetails = const {},
  }) {
    if (attempt != _attempt ||
        _connected ||
        attempt == _completedAttempt ||
        !_needed ||
        _disposed) {
      return;
    }
    _completedAttempt = attempt;
    final timedOut = error is ChatroomConnectDeadlineExceeded;
    if (_foreground && _attemptForeground) {
      if (timedOut) {
        _timeouts++;
      } else if (_attemptIsRetry) {
        _retryFailures++;
      }
    }
    lost(
      timedOut ? 'connect_timeout' : 'connect_error',
      errorCode: timedOut ? 'connect_timeout' : 'connect_failed',
      error: error,
      stack: stack,
      connectDurationMs: _attemptClock?.elapsedMilliseconds,
      connectionDetails: connectionDetails,
    );
    if (_timeouts >= timeoutThreshold) {
      _emit(_generation, 'connect_stalled');
    } else if (_retryFailures >= retryFailureThreshold) {
      _emit(_generation, 'retry_exhausted');
    }
  }

  void lost(
    String cause, {
    String? errorCode,
    int? closeCode,
    int? attempt,
    Object? error,
    StackTrace? stack,
    String? stackSummary,
    int? connectDurationMs,
    Map<String, Object?> closeDetails = const {},
    Map<String, Object?> connectionDetails = const {},
  }) {
    if (!_needed || _disposed || (attempt != null && attempt != _attempt)) {
      return;
    }
    _startRecovery();
    _details.add({
      'attempt': _attempt,
      'cause': cause,
      'foreground': _foreground,
      ...connectionDetails,
      'time': DateTime.now().toUtc().toIso8601String(),
      if (connectDurationMs != null) 'connect_duration_ms': connectDurationMs,
      if (error != null) 'error_type': error.runtimeType.toString(),
      if (error != null) 'error_message': _bounded(error.toString(), 400),
      if (error is WebSocketException && error.httpStatusCode != null)
        'http_status_code': error.httpStatusCode,
      if (error is TlsException) ...{
        if (error.osError != null) 'os_error_code': error.osError!.errorCode,
        if (error.osError != null)
          'os_error_message': _bounded(error.osError!.message, 400),
      },
      if (error is SocketException) ...{
        'os_error_code': error.osError?.errorCode,
        'os_error_message': error.osError?.message,
        if (error.address != null) 'socket_address': error.address!.address,
        if (error.port != null) 'socket_port': error.port,
      },
      if (stack != null || stackSummary != null)
        'stack_summary': _bounded(
          (stack?.toString() ?? stackSummary!).split('\n').take(8).join('\n'),
          600,
        ),
      'ws_close_code': closeCode,
      ...closeDetails,
    });
    if (_details.length > 10) _details.removeAt(0);
    _connected = false;
    _observe();
    _cause ??= cause;
    if (errorCode != null) _errorCode = errorCode;
    if (closeCode != null) _closeCode = closeCode;
  }

  void _observe() {
    if (!_recovering || !_foreground || _reported || !_needed || _disposed) {
      return;
    }
    final generation = _generation;
    if (_networkGeneration == generation) return;
    _networkGeneration = generation;
    unawaited(_refreshNetworkType(generation));
  }

  Future<void> _refreshNetworkType(int generation) async {
    String network;
    try {
      network = await _readNetworkType().timeout(const Duration(seconds: 1));
    } catch (_) {
      network = 'unknown';
    }
    if (_valid(generation)) _networkType = network;
  }

  void _emit(int generation, String reportCause) {
    if (!_valid(generation)) return;
    final ext = <String, Object>{
      'recovery_id': _recoveryId!,
      'connect_attempts': _recoveryAttempts,
      'attempts_scope': 'foreground',
      'cause': reportCause,
      'initial_cause': _cause ?? 'unknown',
      'retry_count': _everConnected
          ? _recoveryAttempts
          : (_recoveryAttempts - (_initialAttemptCounted ? 1 : 0)).clamp(
              0,
              _recoveryAttempts,
            ),
      'retry_failure_count': _retryFailures,
      'timeout_count': _timeouts,
      'retry_failure_threshold': retryFailureThreshold,
      'timeout_threshold': timeoutThreshold,
      'attempt_details': List.of(_details),
    };
    if (_closeCode != null) ext['close_code'] = _closeCode!;
    if (_errorCode != null) ext['last_error_code'] = _errorCode!;
    try {
      _report(
        worldId: _worldId,
        phase: _everConnected ? 'reconnect' : 'initial_connect',
        cause: reportCause,
        networkType: _networkType,
        extData: _fitDiagnostics(ext, 4000),
      );
      _reported = true;
    } catch (_) {
      // Diagnostics must never affect the connection or retry path.
    }
  }

  bool _valid(int generation) =>
      !_disposed &&
      _needed &&
      _foreground &&
      !_connected &&
      !_reported &&
      generation == _generation;

  void _clearObservation() {
    _generation++;
    _reported = false;
    _networkType = 'unknown';
    _cause = null;
    _errorCode = null;
    _closeCode = null;
    _details.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    if (!foreground && _recoveryForegroundSince != null) {
      _recoveryElapsed += _now().difference(_recoveryForegroundSince!);
      _recoveryForegroundSince = null;
    } else if (foreground && _recovering) {
      _recoveryForegroundSince = _now();
    }
    _foreground = foreground;
    // Background pauses observation, but never opens a second reporting round.
    // Preserve the round ID, report flag and attempts until success/cancellation.
    _generation++;
    if (_foreground && _needed && !_connected) _observe();
  }

  void cancel() {
    _resetRecovery();
    _needed = false;
    _connected = false;
    _everConnected = false;
    _attempt++;
    _clearObservation();
  }

  void dispose() {
    cancel();
    _disposed = true;
    _binding?.removeObserver(this);
  }
}

String _bounded(String value, int limit) =>
    value.length <= limit ? value : value.substring(0, limit);

String _fitDiagnostics(Map<String, dynamic> source, int limit) {
  final data = Map<String, dynamic>.of(source);
  final details = List<Object?>.of((data['attempt_details'] as List?) ?? []);
  data['attempt_details'] = details;
  while (jsonEncode(data).length > limit && details.length > 1) {
    details.removeAt(0);
    data['history_truncated'] = true;
  }
  if (jsonEncode(data).length > limit) {
    data['attempt_details'] = [];
    data['detail_truncated'] = true;
  }
  return jsonEncode(data);
}
