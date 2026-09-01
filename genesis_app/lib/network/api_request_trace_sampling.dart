import 'dart:math';

import 'package:flutter/foundation.dart';

/// Process-lifetime sampling decision for ordinary business API traces.
///
/// The decision starts disabled and is configured once the startup global
/// config request succeeds. The config request itself bypasses this decision.
class ApiRequestTraceSampling {
  ApiRequestTraceSampling._();

  static final Random _random = Random();
  static bool _enabledForLaunch = false;
  static bool _configuredForLaunch = false;

  static bool get enabledForLaunch => _enabledForLaunch;

  static void configureForLaunch(double samplingRate, {double? randomValue}) {
    if (_configuredForLaunch) return;
    _configuredForLaunch = true;
    final rate = _normalizeRate(samplingRate);
    final sample = randomValue ?? _random.nextDouble();
    final normalizedSample = sample.isFinite
        ? sample.clamp(0.0, 1.0).toDouble()
        : 1.0;
    _enabledForLaunch = normalizedSample < rate;
  }

  @visibleForTesting
  static void resetForTesting() {
    _enabledForLaunch = false;
    _configuredForLaunch = false;
  }

  static double _normalizeRate(double value) {
    if (!value.isFinite) return 0;
    return value.clamp(0.0, 1.0).toDouble();
  }
}
