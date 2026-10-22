import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

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

/// One observation per foreground outage, independent of retry and join work.
class ChatroomDisconnectMonitor with WidgetsBindingObserver {
  ChatroomDisconnectMonitor({
    this.threshold = const Duration(seconds: 15),
    Future<String> Function()? readNetworkType,
    DisconnectReport? report,
  }) : _readNetworkType = readNetworkType ?? NetworkTypeSnapshot.read,
       _report = report ?? _collect {
    try {
      _binding = WidgetsBinding.instance;
    } catch (_) {
      // Headless protocol tests may have no Flutter binding.
    }
    final state = _binding?.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _binding?.addObserver(this);
  }

  final Duration threshold;
  final Future<String> Function() _readNetworkType;
  final DisconnectReport _report;
  WidgetsBinding? _binding;
  bool _foreground = true;
  bool _needed = false;
  bool _connected = false;
  bool _everConnected = false;
  bool _disposed = false;
  bool _reported = false;
  int _generation = 0;
  int _attempt = 0;
  int _attempts = 0;
  String _worldId = '';
  String _owner = '';
  String? _cause;
  String? _errorCode;
  int? _closeCode;
  Timer? _timer;

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
      object3: cause,
      object4: networkType,
      extData: extData,
    );
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
    if (!_disposed && _needed && !_connected) {
      _observe();
      _attempts++;
    }
    return _attempt;
  }

  void succeeded(int attempt) {
    if (!_needed || _disposed || attempt != _attempt) return;
    _connected = true;
    _everConnected = true;
    _clearObservation();
  }

  void connectFailed(int attempt) {
    if (attempt != _attempt || _connected) return;
    lost('connect_error', errorCode: 'connect_failed');
  }

  void lost(String cause, {String? errorCode, int? closeCode, int? attempt}) {
    if (!_needed || _disposed || (attempt != null && attempt != _attempt)) {
      return;
    }
    _connected = false;
    _observe();
    _cause ??= cause;
    if (errorCode != null) _errorCode = errorCode;
    if (closeCode != null) _closeCode = closeCode;
  }

  void _observe() {
    if (!_foreground || _timer != null || _reported || !_needed || _disposed) {
      return;
    }
    final generation = _generation;
    _timer = Timer(threshold, () => unawaited(_emit(generation)));
  }

  Future<void> _emit(int generation) async {
    if (!_valid(generation)) return;
    String network;
    try {
      network = await _readNetworkType().timeout(const Duration(seconds: 1));
    } catch (_) {
      network = 'unknown';
    }
    // Recovery/background/account changes while native snapshot is pending cancel it.
    if (!_valid(generation)) return;
    _reported = true;
    final ext = <String, Object>{'connect_attempts': _attempts};
    if (_closeCode != null) ext['close_code'] = _closeCode!;
    if (_errorCode != null) ext['last_error_code'] = _errorCode!;
    try {
      _report(
        worldId: _worldId,
        phase: _everConnected ? 'reconnect' : 'initial_connect',
        cause: _cause ?? 'unknown',
        networkType: network,
        extData: jsonEncode(ext),
      );
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
    _timer?.cancel();
    _timer = null;
    _reported = false;
    _cause = null;
    _errorCode = null;
    _closeCode = null;
    _attempts = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _clearObservation();
    if (_foreground && _needed && !_connected) _observe();
  }

  void cancel() {
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
