import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:flutter/foundation.dart';

import '../telemetry/genesis_telemetry.dart';
import 'adjust_local_adid_store.dart';

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
typedef AdjustAdidFailureReporter =
    void Function(String source, TargetPlatform platform);
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

void _reportAdidFailure(String source, TargetPlatform platform) {
  GenesisTelemetry.collectLog(
    actionType: 'monitor',
    action: 'get_adid_failed',
    object1: source,
    object2: platform.name,
  );
}

/// Best-effort bridge between the Adjust SDK identity and Worldo's device
/// registration endpoint.
///
/// Registration never gates app startup. Explicit triggers such as startup or
/// foreground resume read Adjust's cached ADID once. A missing ADID waits for a
/// later explicit trigger or an Adjust session callback. Once an ADID is known,
/// backend failures start a bounded automatic retry sequence.
class AdjustDeviceRegistration {
  AdjustDeviceRegistration({
    required this.platform,
    required this.registerDevice,
    required this.environmentProvider,
    this.readAdid = Adjust.getAdidWithTimeout,
    this.readGoogleAdId = Adjust.getGoogleAdId,
    this.readIdfa = Adjust.getIdfa,
    this.readIdfv = Adjust.getIdfv,
    this.localAdidStore = const SharedPreferencesAdjustLocalAdidStore(),
    this.adidTimeout = const Duration(seconds: 5),
    this.retryDelays = _defaultRetryDelays,
    this.reportAdidFailure = _reportAdidFailure,
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
  final AdjustLocalAdidStore localAdidStore;
  final Duration adidTimeout;
  final List<Duration> retryDelays;
  final AdjustAdidFailureReporter reportAdidFailure;
  final AdjustDeviceRegistrationRetryScheduler _retryScheduler;

  Future<void>? _inFlight;
  bool _rerunRequested = false;
  bool _forceRerunRequested = false;
  _AdjustDeviceIdentifiers? _lastRegistered;
  VoidCallback? _cancelScheduledRetry;
  int _nextRetryDelayIndex = 0;
  int _retryGeneration = 0;
  bool _disposed = false;
  bool _adidFailureReported = false;
  AdjustDeviceRegistrationResult? _lastResult;
  String? _knownAdid;

  AdjustDeviceRegistrationResult? get lastResult => _lastResult;

  /// After a session outcome without an ADID, try one bounded SDK read.
  Future<void> registerAfterSessionWithoutAdid() async {
    if (_disposed) return;
    final active = _inFlight;
    if (active != null) await active;
    if (_disposed || (_knownAdid?.isNotEmpty ?? false)) return;
    await register();
  }

  /// Check the current process, persisted cache, and then the Adjust SDK.
  /// Report only if both local storage and the SDK were readable but empty.
  Future<void> checkAdidAfterStartup() async {
    if (_disposed || (_knownAdid?.isNotEmpty ?? false)) return;
    final active = _inFlight;
    if (active != null) await active;
    if (_disposed || (_knownAdid?.isNotEmpty ?? false)) return;

    var localReadSucceeded = true;
    String? localAdid;
    try {
      localAdid = (await localAdidStore.read().timeout(
        const Duration(seconds: 2),
      ))?.trim();
    } catch (error) {
      localReadSucceeded = false;
      debugPrint('[Adjust][DeviceRegister] local ADID read failed: $error');
    }
    if (_disposed || (_knownAdid?.isNotEmpty ?? false)) return;
    if (localAdid?.isNotEmpty == true) {
      await registerKnownAdid(localAdid!);
      return;
    }

    await register();
    if (_disposed ||
        !localReadSucceeded ||
        _adidFailureReported ||
        (_knownAdid?.isNotEmpty ?? false) ||
        _lastResult != AdjustDeviceRegistrationResult.deferredNoAdid) {
      return;
    }
    _adidFailureReported = true;
    try {
      reportAdidFailure('startup_delayed_check', platform);
    } catch (error) {
      debugPrint('[Adjust][DeviceRegister] ADID failure report failed: $error');
    }
  }

  Future<void> registerKnownAdid(String adid) {
    final normalizedAdid = adid.trim();
    if (normalizedAdid.isEmpty || _disposed) return Future<void>.value();
    _knownAdid = normalizedAdid;
    unawaited(_persistAdid(normalizedAdid));
    final current = _inFlight;
    if (current != null) {
      // A session callback proves that Adjust has assigned the ADID. Drain one
      // fresh attempt if the active read started before that callback arrived.
      _rerunRequested = true;
      return current;
    }
    return register();
  }

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

    return _startRegistration(force: force, readCachedAdid: true);
  }

  Future<void> _startRegistration({
    required bool force,
    required bool readCachedAdid,
  }) {
    if (_disposed) return Future<void>.value();

    late final Future<void> operation;
    operation = _registerAndDrain(force: force, readCachedAdid: readCachedAdid)
        .whenComplete(() {
          if (identical(_inFlight, operation)) _inFlight = null;
        });
    _inFlight = operation;
    return operation;
  }

  Future<void> _registerAndDrain({
    required bool force,
    required bool readCachedAdid,
  }) async {
    var result = await _registerOnce(
      force: force,
      readCachedAdid: readCachedAdid,
    );
    while (_rerunRequested || _forceRerunRequested) {
      final forceRerun = _forceRerunRequested;
      _rerunRequested = false;
      _forceRerunRequested = false;
      result = await _registerOnce(force: forceRerun, readCachedAdid: false);
    }
    _lastResult = result;
    _handleResult(result);
  }

  Future<AdjustDeviceRegistrationResult> _registerOnce({
    required bool force,
    required bool readCachedAdid,
  }) async {
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return AdjustDeviceRegistrationResult.failed;
    }

    var adid = _knownAdid ?? '';
    if (adid.isEmpty && readCachedAdid) {
      try {
        adid = (await readAdid(adidTimeout.inMilliseconds))?.trim() ?? '';
        if (adid.isNotEmpty) {
          _knownAdid = adid;
          unawaited(_persistAdid(adid));
        }
      } catch (error, stackTrace) {
        debugPrint('[Adjust][DeviceRegister] cached ADID read failed: $error');
        debugPrint('[Adjust][DeviceRegister] stacktrace:\n$stackTrace');
      }
    }
    if (adid.isEmpty) {
      debugPrint(
        '[Adjust][DeviceRegister] ADID unavailable; waiting for session callback',
      );
      return AdjustDeviceRegistrationResult.deferredNoAdid;
    }

    try {
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
        _cancelRetry(resetBudget: true);
        return;
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
      await _startRegistration(force: false, readCachedAdid: false);
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

  Future<void> _persistAdid(String adid) async {
    try {
      await localAdidStore.write(adid);
    } catch (error) {
      debugPrint('[Adjust][DeviceRegister] local ADID save failed: $error');
    }
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
