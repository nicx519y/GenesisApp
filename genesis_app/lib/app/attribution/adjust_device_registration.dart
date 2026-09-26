import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:flutter/foundation.dart';

typedef AdjustAdidReader = Future<String?> Function(int timeoutMilliseconds);
typedef AdjustOptionalIdReader = Future<String?> Function();
typedef AdjustRegistrationEnvironmentProvider = String Function();
typedef AdjustDeviceRegistrationRequest =
    Future<void> Function({
      required String adid,
      required String environment,
      String? gpsAdid,
      String? idfa,
      String? idfv,
    });
typedef AdjustDeviceRegistrationRetryCallback = Future<void> Function();
typedef AdjustDeviceRegistrationRetryScheduler =
    VoidCallback Function(
      Duration delay,
      AdjustDeviceRegistrationRetryCallback callback,
    );

enum AdjustDeviceRegistrationResult {
  registered,
  alreadyRegistered,
  deferredNoAdid,
  failed,
}

const _defaultRetryDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
];

VoidCallback _scheduleRetryWithTimer(
  Duration delay,
  AdjustDeviceRegistrationRetryCallback callback,
) {
  final timer = Timer(delay, () => unawaited(callback()));
  return timer.cancel;
}

/// Best-effort bridge between the Adjust SDK identity and Worldo's device
/// registration endpoint.
///
/// Registration never gates app startup. A missing ADID or a network failure
/// starts a bounded automatic retry sequence. Explicit triggers such as login
/// or foreground resume reset that retry budget and try immediately.
class AdjustDeviceRegistration {
  AdjustDeviceRegistration({
    required this.platform,
    required this.registerDevice,
    required this.environmentProvider,
    this.readAdid = Adjust.getAdidWithTimeout,
    this.readGoogleAdId = Adjust.getGoogleAdId,
    this.readIdfa = Adjust.getIdfa,
    this.readIdfv = Adjust.getIdfv,
    this.adidTimeout = const Duration(seconds: 5),
    this.retryDelays = _defaultRetryDelays,
    AdjustDeviceRegistrationRetryScheduler retryScheduler =
        _scheduleRetryWithTimer,
  }) : _retryScheduler = retryScheduler;

  final TargetPlatform platform;
  final AdjustDeviceRegistrationRequest registerDevice;
  final AdjustRegistrationEnvironmentProvider environmentProvider;
  final AdjustAdidReader readAdid;
  final AdjustOptionalIdReader readGoogleAdId;
  final AdjustOptionalIdReader readIdfa;
  final AdjustOptionalIdReader readIdfv;
  final Duration adidTimeout;
  final List<Duration> retryDelays;
  final AdjustDeviceRegistrationRetryScheduler _retryScheduler;

  Future<void>? _inFlight;
  bool _forceRerunRequested = false;
  _AdjustDeviceIdentifiers? _lastRegistered;
  VoidCallback? _cancelScheduledRetry;
  int _nextRetryDelayIndex = 0;
  int _retryGeneration = 0;
  bool _disposed = false;
  AdjustDeviceRegistrationResult? _lastResult;

  AdjustDeviceRegistrationResult? get lastResult => _lastResult;

  Future<void> register({bool force = false}) {
    if (_disposed) return Future<void>.value();

    // An explicit lifecycle or session trigger should try immediately and get
    // a fresh bounded retry budget, even if an automatic attempt is in flight.
    _cancelRetry(resetBudget: true);
    final current = _inFlight;
    if (current != null) {
      if (force) _forceRerunRequested = true;
      return current;
    }

    return _startRegistration(force: force);
  }

  Future<void> _startRegistration({required bool force}) {
    if (_disposed) return Future<void>.value();

    late final Future<void> operation;
    operation = _registerAndDrain(force: force).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<void> _registerAndDrain({required bool force}) async {
    var result = await _registerOnce(force: force);
    while (_forceRerunRequested) {
      _forceRerunRequested = false;
      result = await _registerOnce(force: true);
    }
    _lastResult = result;
    _handleResult(result);
  }

  Future<AdjustDeviceRegistrationResult> _registerOnce({
    required bool force,
  }) async {
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return AdjustDeviceRegistrationResult.failed;
    }

    try {
      final adid = (await readAdid(adidTimeout.inMilliseconds))?.trim() ?? '';
      if (adid.isEmpty) {
        debugPrint(
          '[Adjust][DeviceRegister] ADID unavailable; registration deferred',
        );
        return AdjustDeviceRegistrationResult.deferredNoAdid;
      }

      final identifiers = platform == TargetPlatform.android
          ? _AdjustDeviceIdentifiers(
              adid: adid,
              environment: environmentProvider(),
              gpsAdid: await _readOptional(readGoogleAdId, 'GPS ADID'),
            )
          : _AdjustDeviceIdentifiers(
              adid: adid,
              environment: environmentProvider(),
              idfa: await _readOptional(readIdfa, 'IDFA'),
              idfv: await _readOptional(readIdfv, 'IDFV'),
            );
      if (!force && identifiers == _lastRegistered) {
        return AdjustDeviceRegistrationResult.alreadyRegistered;
      }

      await registerDevice(
        adid: identifiers.adid,
        environment: identifiers.environment,
        gpsAdid: identifiers.gpsAdid,
        idfa: identifiers.idfa,
        idfv: identifiers.idfv,
      );
      _lastRegistered = identifiers;
      debugPrint(
        '[Adjust][DeviceRegister] registration succeeded; '
        'platform=${platform.name}',
      );
      return AdjustDeviceRegistrationResult.registered;
    } catch (error, stackTrace) {
      debugPrint('[Adjust][DeviceRegister] registration failed: $error');
      debugPrint('[Adjust][DeviceRegister] stacktrace:\n$stackTrace');
      return AdjustDeviceRegistrationResult.failed;
    }
  }

  void _handleResult(AdjustDeviceRegistrationResult result) {
    switch (result) {
      case AdjustDeviceRegistrationResult.registered:
      case AdjustDeviceRegistrationResult.alreadyRegistered:
        _cancelRetry(resetBudget: true);
        return;
      case AdjustDeviceRegistrationResult.deferredNoAdid:
      case AdjustDeviceRegistrationResult.failed:
        _scheduleRetry();
        return;
    }
  }

  void _scheduleRetry() {
    if (_disposed ||
        _cancelScheduledRetry != null ||
        _nextRetryDelayIndex >= retryDelays.length) {
      if (!_disposed &&
          _cancelScheduledRetry == null &&
          _nextRetryDelayIndex >= retryDelays.length) {
        debugPrint(
          '[Adjust][DeviceRegister] automatic retry budget exhausted; '
          'waiting for the next startup, foreground, or session trigger',
        );
      }
      return;
    }

    final delay = retryDelays[_nextRetryDelayIndex++];
    final generation = ++_retryGeneration;
    debugPrint(
      '[Adjust][DeviceRegister] retry scheduled in '
      '${delay.inMilliseconds}ms '
      '($_nextRetryDelayIndex/${retryDelays.length})',
    );
    _cancelScheduledRetry = _retryScheduler(delay, () async {
      if (_disposed || generation != _retryGeneration) return;
      _cancelScheduledRetry = null;
      await _startRegistration(force: false);
    });
  }

  void _cancelRetry({required bool resetBudget}) {
    _retryGeneration++;
    _cancelScheduledRetry?.call();
    _cancelScheduledRetry = null;
    if (resetBudget) _nextRetryDelayIndex = 0;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelRetry(resetBudget: true);
  }

  Future<String?> _readOptional(
    AdjustOptionalIdReader reader,
    String name,
  ) async {
    try {
      final value = await reader();
      return value?.trim();
    } catch (error) {
      // Omit an unreadable optional value so the server preserves the last
      // successfully registered identifier.
      debugPrint('[Adjust][DeviceRegister] $name unavailable: $error');
      return null;
    }
  }
}

@immutable
class _AdjustDeviceIdentifiers {
  const _AdjustDeviceIdentifiers({
    required this.adid,
    required this.environment,
    this.gpsAdid,
    this.idfa,
    this.idfv,
  });

  final String adid;
  final String environment;
  final String? gpsAdid;
  final String? idfa;
  final String? idfv;

  @override
  bool operator ==(Object other) {
    return other is _AdjustDeviceIdentifiers &&
        other.adid == adid &&
        other.environment == environment &&
        other.gpsAdid == gpsAdid &&
        other.idfa == idfa &&
        other.idfv == idfv;
  }

  @override
  int get hashCode => Object.hash(adid, environment, gpsAdid, idfa, idfv);
}
