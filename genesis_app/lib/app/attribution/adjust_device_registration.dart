import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:flutter/foundation.dart';
import '../../platform/device/gaid_reader.dart';

import '../privacy/privacy_consent_controller.dart';
import 'adjust_local_adid_store.dart';
import 'adid_availability_monitor.dart';

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
      required String appInstanceId,
      String? privacyConsent,
    });
typedef AdjustDeviceRegistrationRetryCallback = Future<void> Function();
typedef AdjustAdidFailureReporter =
    void Function(
      String source,
      TargetPlatform platform,
      Map<String, Object?> identifiers,
    );
typedef AdjustDeviceRegistrationRetryScheduler =
    VoidCallback Function(
      Duration delay,
      AdjustDeviceRegistrationRetryCallback callback,
    );

enum AdjustDeviceRegistrationResult {
  registered,
  alreadyRegistered,
  registeredWithoutAdid,
  registeredWithoutAdidReadError,
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
/// Registration never gates app startup. Explicit triggers such as startup or
/// foreground resume read Adjust's cached ADID once. A missing ADID is sent as
/// an empty value so available platform IDs can be registered immediately;
/// later triggers or a session callback still attempt to fill in the ADID.
/// Backend failures start a bounded automatic retry sequence.
class AdjustDeviceRegistration {
  AdjustDeviceRegistration({
    required this.platform,
    required this.registerDevice,
    required this.environmentProvider,
    this.readAdid = Adjust.getAdidWithTimeout,
    this.readGoogleAdId = Adjust.getGoogleAdId,
    this.readNativeGoogleAdId = readSystemGaid,
    this.readIdfa = Adjust.getIdfa,
    this.readIdfv = Adjust.getIdfv,
    this.readAppInstanceId = _emptyAppInstanceId,
    this.localAdidStore = const SharedPreferencesAdjustLocalAdidStore(),
    this.adidTimeout = const Duration(seconds: 5),
    this.optionalIdTimeout = const Duration(seconds: 3),
    this.retryDelays = _defaultRetryDelays,
    this.reportAdidFailure,
    AdidAvailabilityMonitor? adidAvailabilityMonitor,
    AdjustDeviceRegistrationRetryScheduler retryScheduler =
        _scheduleRetryWithTimer,
  }) : adidAvailabilityMonitor =
           adidAvailabilityMonitor ?? launchAdidAvailabilityMonitor,
       _retryScheduler = retryScheduler;

  final TargetPlatform platform;
  final AdjustDeviceRegistrationRequest registerDevice;
  final AdjustRegistrationEnvironmentProvider environmentProvider;
  final AdjustAdidReader readAdid;
  final AdjustOptionalIdReader readGoogleAdId;
  final AdjustOptionalIdReader? readNativeGoogleAdId;
  final AdjustOptionalIdReader readIdfa;
  final AdjustOptionalIdReader readIdfv;
  final AdjustOptionalIdReader readAppInstanceId;
  final AdjustLocalAdidStore localAdidStore;
  final Duration adidTimeout;
  final Duration optionalIdTimeout;
  final List<Duration> retryDelays;
  final AdjustAdidFailureReporter? reportAdidFailure;
  final AdidAvailabilityMonitor adidAvailabilityMonitor;
  final AdjustDeviceRegistrationRetryScheduler _retryScheduler;

  Future<void>? _inFlight;
  bool _rerunRequested = false;
  bool _forceRerunRequested = false;
  _AdjustDeviceIdentifiers? _lastRegistered;
  String? _lastRegisteredPrivacy;
  VoidCallback? _cancelScheduledRetry;
  int _nextRetryDelayIndex = 0;
  int _retryGeneration = 0;
  bool _disposed = false;
  bool _adidFailureReported = false;
  bool _adidFailureCheckPending = false;
  bool _lastAdidReadWasEmpty = false;
  bool _lastAdidReadFailed = false;
  AdjustDeviceRegistrationResult? _lastResult;
  String? _knownAdid;

  AdjustDeviceRegistrationResult? get lastResult => _lastResult;

  /// A network event retries only unfinished registration. A previous SDK read
  /// may have missed an ADID already persisted in this Adjust environment.
  Future<void> retryAfterNetworkRestored() async {
    if (_disposed ||
        _lastResult == AdjustDeviceRegistrationResult.registered ||
        _lastResult == AdjustDeviceRegistrationResult.alreadyRegistered) {
      return;
    }
    await register();
    if (_disposed || (_knownAdid?.isNotEmpty ?? false)) return;
    try {
      final cached = (await localAdidStore.read().timeout(
        const Duration(seconds: 2),
      ))?.trim();
      if (cached?.isNotEmpty == true) await registerKnownAdid(cached!);
    } catch (error) {
      debugPrint(
        '[Adjust][DeviceRegister] recovery ADID cache read failed: $error',
      );
    }
  }

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

    _adidFailureCheckPending = localReadSucceeded;
    try {
      await register();
    } finally {
      _adidFailureCheckPending = false;
    }
  }

  void _reportPendingAdidFailure(
    _AdjustDeviceIdentifiers identifiers, {
    String adjustGaid = '',
    String nativeGaid = '',
  }) {
    if (_disposed ||
        !_adidFailureCheckPending ||
        _adidFailureReported ||
        (_knownAdid?.isNotEmpty ?? false) ||
        !_lastAdidReadWasEmpty) {
      return;
    }
    _adidFailureReported = true;
    final payload = <String, Object?>{
      'adid': identifiers.adid,
      'app_instance_id': identifiers.appInstanceId,
      if (platform == TargetPlatform.android) 'adjust_gps_adid': adjustGaid,
      if (platform == TargetPlatform.android) 'native_gps_adid': nativeGaid,
      if (platform == TargetPlatform.iOS) 'idfa': identifiers.idfa,
      if (platform == TargetPlatform.iOS) 'idfv': identifiers.idfv,
    };
    adidAvailabilityMonitor.observe(
      available: false,
      adjustId:
          (payload[platform == TargetPlatform.android
                  ? 'adjust_gps_adid'
                  : 'idfa']
              as String?) ??
          '',
      nativeId:
          (payload[platform == TargetPlatform.android
                  ? 'native_gps_adid'
                  : 'idfv']
              as String?) ??
          '',
      appInstanceId: identifiers.appInstanceId,
    );
    try {
      reportAdidFailure?.call('startup_delayed_check', platform, payload);
    } catch (error) {
      debugPrint('[Adjust][DeviceRegister] ADID failure report failed: $error');
    }
  }

  Future<void> registerKnownAdid(String adid) {
    final normalizedAdid = adid.trim();
    if (normalizedAdid.isEmpty || _disposed) return Future<void>.value();
    _knownAdid = normalizedAdid;
    _lastAdidReadWasEmpty = false;
    _lastAdidReadFailed = false;
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

  /// Recheck once Firebase Analytics finishes configuring. If a registration
  /// is already in flight, drain another attempt so a late ID is not missed.
  Future<void> registerAfterFirebaseReady() {
    if (_disposed) return Future<void>.value();
    final current = _inFlight;
    if (current != null) {
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
      _lastAdidReadWasEmpty = false;
      _lastAdidReadFailed = false;
      try {
        // The SDK timeout covers ADID availability. The Dart deadline also
        // releases this registration if the platform channel never replies.
        adid =
            (await readAdid(
              adidTimeout.inMilliseconds,
            ).timeout(adidTimeout + const Duration(seconds: 1)))?.trim() ??
            '';
        if (adid.isNotEmpty) {
          _knownAdid = adid;
          unawaited(_persistAdid(adid));
        } else {
          _lastAdidReadWasEmpty = true;
        }
      } catch (error, stackTrace) {
        _lastAdidReadFailed = true;
        debugPrint('[Adjust][DeviceRegister] cached ADID read failed: $error');
        debugPrint('[Adjust][DeviceRegister] stacktrace:\n$stackTrace');
      }
    }
    if (adid.isEmpty) {
      debugPrint(
        '[Adjust][DeviceRegister] ADID unavailable; registering available identifiers',
      );
    }
    final missingAdidResult = _lastAdidReadFailed
        ? AdjustDeviceRegistrationResult.registeredWithoutAdidReadError
        : AdjustDeviceRegistrationResult.registeredWithoutAdid;

    try {
      final environment = environmentProvider();
      final googleAdId = platform == TargetPlatform.android
          ? await _readGoogleAdId(
              captureNative:
                  (_adidFailureCheckPending && adid.isEmpty) ||
                  adidAvailabilityMonitor.shouldCaptureNative,
            )
          : null;
      final appInstanceId = await _readOptional(
        readAppInstanceId,
        'Firebase app instance ID',
      );
      final idfa = platform == TargetPlatform.iOS ? await _readIdfa() : null;
      final idfv = platform == TargetPlatform.iOS
          ? await _readOptional(readIdfv, 'IDFV')
          : null;
      // A session callback may assign ADID while optional IDs are being read.
      adid = _knownAdid ?? adid;
      final identifiers = platform == TargetPlatform.android
          ? _AdjustDeviceIdentifiers(
              adid: adid,
              environment: environment,
              gpsAdid: googleAdId!.id,
              appInstanceId: appInstanceId,
            )
          : _AdjustDeviceIdentifiers(
              adid: adid,
              environment: environment,
              idfa: idfa,
              idfv: idfv,
              appInstanceId: appInstanceId,
            );
      // Attach the latest choice without restarting identifier reads.
      final consentJson = privacyConsent.registrationJson;
      _reportPendingAdidFailure(
        identifiers,
        adjustGaid: googleAdId?.adjustId ?? '',
        nativeGaid: googleAdId?.nativeId ?? '',
      );
      if (adid.isNotEmpty) {
        adidAvailabilityMonitor.observe(
          available: true,
          adjustId: adid,
          nativeId: '',
          appInstanceId: appInstanceId,
        );
      }
      if (!force &&
          identifiers == _lastRegistered &&
          consentJson == _lastRegisteredPrivacy) {
        return adid.isEmpty
            ? missingAdidResult
            : AdjustDeviceRegistrationResult.alreadyRegistered;
      }

      await registerDevice(
        adid: identifiers.adid,
        environment: identifiers.environment,
        gpsAdid: identifiers.gpsAdid,
        idfa: identifiers.idfa,
        idfv: identifiers.idfv,
        appInstanceId: identifiers.appInstanceId,
        privacyConsent: consentJson,
      );
      _lastRegistered = identifiers;
      _lastRegisteredPrivacy = consentJson;
      debugPrint(
        '[Adjust][DeviceRegister] registration succeeded; '
        'platform=${platform.name}, adidAvailable=${adid.isNotEmpty}',
      );
      return adid.isEmpty
          ? missingAdidResult
          : AdjustDeviceRegistrationResult.registered;
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
      case AdjustDeviceRegistrationResult.registeredWithoutAdid:
      case AdjustDeviceRegistrationResult.registeredWithoutAdidReadError:
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

  Future<String> _readOptional(
    AdjustOptionalIdReader reader,
    String name,
  ) async {
    try {
      final value = await reader().timeout(optionalIdTimeout);
      final normalized = value?.trim();
      return normalized ?? '';
    } catch (error) {
      debugPrint('[Adjust][DeviceRegister] $name unavailable: $error');
      return '';
    }
  }

  Future<String> _readIdfa() async {
    final idfa = await _readOptional(readIdfa, 'IDFA');
    return _isUsableAdvertisingId(idfa) ? idfa : '';
  }

  Future<({String id, String adjustId, String nativeId})> _readGoogleAdId({
    bool captureNative = false,
  }) async {
    final result = await readGaid(
      adjustReader: readGoogleAdId,
      systemReader: readNativeGoogleAdId ?? readSystemGaid,
      timeout: optionalIdTimeout,
      captureNative: captureNative,
    );
    return (
      id: result.id,
      adjustId: result.adjustId,
      nativeId: result.nativeId,
    );
  }

  bool _isUsableAdvertisingId(String value) =>
      value.isNotEmpty &&
      value.toLowerCase() != '00000000-0000-0000-0000-000000000000';
}

@immutable
class _AdjustDeviceIdentifiers {
  const _AdjustDeviceIdentifiers({
    required this.adid,
    required this.environment,
    required this.appInstanceId,
    this.gpsAdid,
    this.idfa,
    this.idfv,
  });

  final String adid;
  final String environment;
  final String appInstanceId;
  final String? gpsAdid;
  final String? idfa;
  final String? idfv;

  @override
  bool operator ==(Object other) {
    return other is _AdjustDeviceIdentifiers &&
        other.adid == adid &&
        other.environment == environment &&
        other.appInstanceId == appInstanceId &&
        other.gpsAdid == gpsAdid &&
        other.idfa == idfa &&
        other.idfv == idfv;
  }

  @override
  int get hashCode =>
      Object.hash(adid, environment, appInstanceId, gpsAdid, idfa, idfv);
}

Future<String?> _emptyAppInstanceId() async => null;
