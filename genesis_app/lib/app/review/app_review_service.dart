import 'package:flutter/foundation.dart';

import '../../platform/channels/genesis_method_channels.dart';

enum AppReviewOutcome { completed, deferred }

/// Requests in-app review only. Visibility and submitted ratings are not exposed.
class AppReviewService {
  AppReviewService({Future<void> Function()? request, TargetPlatform? platform})
    : _request =
          request ??
          (() => GenesisMethodChannels.device.invokeMethod<void>(
            GenesisMethodChannels.requestAppReview,
          )),
      _platform = platform ?? defaultTargetPlatform;

  final Future<void> Function() _request;
  final TargetPlatform _platform;
  bool _busy = false;

  Future<AppReviewOutcome?> requestFor(
    String owner, {
    bool Function()? isCurrent,
  }) async {
    if (_busy || isCurrent?.call() == false) return null;
    _busy = true;
    try {
      await _request();
      return _platform == TargetPlatform.iOS
          ? AppReviewOutcome.deferred
          : AppReviewOutcome.completed;
    } finally {
      _busy = false;
    }
  }
}
