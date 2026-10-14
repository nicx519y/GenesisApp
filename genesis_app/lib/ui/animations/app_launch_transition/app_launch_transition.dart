import 'dart:math' as math;

import 'package:flutter/material.dart';

part 'app_launch_source.dart';
part 'app_launch_transition_host.dart';

/// Visual policy shared by all launches. No routing or business state lives here.
class AppLaunchTransitionSpec {
  const AppLaunchTransitionSpec({
    this.openDuration = const Duration(milliseconds: 360),
    this.closeDuration = const Duration(milliseconds: 280),
    this.fadeDuration = const Duration(milliseconds: 120),
    this.curve = Curves.easeOutCubic,
    this.homeScale = .96,
    this.homeDim = .12,
  });

  final Duration openDuration;
  final Duration closeDuration;
  final Duration fadeDuration;
  final Curve curve;
  final double homeScale;
  final double homeDim;
}

enum AppLaunchTransitionStatus { home, opening, open, closing }

/// Commands are accepted synchronously so callers can run business effects only
/// after a launch has been accepted and its source geometry has been captured.
class AppLaunchTransitionController extends ChangeNotifier {
  AppLaunchTransitionController({bool initiallyOpen = false})
    : _status = initiallyOpen
          ? AppLaunchTransitionStatus.open
          : AppLaunchTransitionStatus.home;

  _AppLaunchTransitionHostState? _host;
  AppLaunchTransitionStatus _status;

  AppLaunchTransitionStatus get status => _status;
  bool get hasPage => status != AppLaunchTransitionStatus.home;
  bool get isAnimating =>
      status == AppLaunchTransitionStatus.opening ||
      status == AppLaunchTransitionStatus.closing;

  bool open({Object? sourceId}) => _host?._open(sourceId) ?? false;

  /// An omitted source uses the last launch source; [fallbackSourceId] is tried
  /// when that source is gone or clipped. A restored page always fades out.
  bool close({Object? fallbackSourceId}) =>
      _host?._close(fallbackSourceId) ?? false;

  /// Settle the current transition at its destination, e.g. before an outer
  /// route is dismissed. This controller never manipulates a Navigator.
  void finish() => _host?._finish();

  void _setStatus(AppLaunchTransitionStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _host = null;
    super.dispose();
  }
}
