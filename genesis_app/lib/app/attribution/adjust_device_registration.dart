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

/// Best-effort bridge between the Adjust SDK identity and Worldo's device
/// registration endpoint.
///
/// Registration never gates app startup. A missing ADID or a network failure
/// is retried by the next explicit trigger (login or foreground resume).
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
  });

  final TargetPlatform platform;
  final AdjustDeviceRegistrationRequest registerDevice;
  final AdjustRegistrationEnvironmentProvider environmentProvider;
  final AdjustAdidReader readAdid;
  final AdjustOptionalIdReader readGoogleAdId;
  final AdjustOptionalIdReader readIdfa;
  final AdjustOptionalIdReader readIdfv;
  final Duration adidTimeout;

  Future<void>? _inFlight;
  bool _forceRerunRequested = false;
  _AdjustDeviceIdentifiers? _lastRegistered;

  Future<void> register({bool force = false}) {
    final current = _inFlight;
    if (current != null) {
      if (force) _forceRerunRequested = true;
      return current;
    }

    late final Future<void> operation;
    operation = _registerAndDrain(force: force).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<void> _registerAndDrain({required bool force}) async {
    await _registerOnce(force: force);
    while (_forceRerunRequested) {
      _forceRerunRequested = false;
      await _registerOnce(force: true);
    }
  }

  Future<void> _registerOnce({required bool force}) async {
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }

    try {
      final adid = (await readAdid(adidTimeout.inMilliseconds))?.trim() ?? '';
      if (adid.isEmpty) {
        debugPrint(
          '[Adjust][DeviceRegister] ADID unavailable; registration deferred',
        );
        return;
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
      if (!force && identifiers == _lastRegistered) return;

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
    } catch (error, stackTrace) {
      debugPrint('[Adjust][DeviceRegister] registration failed: $error');
      debugPrint('[Adjust][DeviceRegister] stacktrace:\n$stackTrace');
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
