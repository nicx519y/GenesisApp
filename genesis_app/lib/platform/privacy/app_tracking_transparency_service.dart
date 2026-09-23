import 'package:adjust_sdk/adjust.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channels/genesis_method_channels.dart';

typedef AdjustTrackingAuthorizationRequester = Future<num> Function();

enum AppTrackingAuthorizationStatus {
  notSupported,
  notDetermined,
  restricted,
  denied,
  authorized,
  unknown;

  bool get allowsTracking =>
      this == AppTrackingAuthorizationStatus.authorized ||
      this == AppTrackingAuthorizationStatus.notSupported;

  static AppTrackingAuthorizationStatus fromNativeValue(String? value) {
    switch ((value ?? '').trim()) {
      case 'notSupported':
        return AppTrackingAuthorizationStatus.notSupported;
      case 'notDetermined':
        return AppTrackingAuthorizationStatus.notDetermined;
      case 'restricted':
        return AppTrackingAuthorizationStatus.restricted;
      case 'denied':
        return AppTrackingAuthorizationStatus.denied;
      case 'authorized':
        return AppTrackingAuthorizationStatus.authorized;
      default:
        return AppTrackingAuthorizationStatus.unknown;
    }
  }

  static AppTrackingAuthorizationStatus fromAdjustValue(num? value) {
    switch (value) {
      case 0:
        return AppTrackingAuthorizationStatus.notDetermined;
      case 1:
        return AppTrackingAuthorizationStatus.restricted;
      case 2:
        return AppTrackingAuthorizationStatus.denied;
      case 3:
        return AppTrackingAuthorizationStatus.authorized;
      default:
        return AppTrackingAuthorizationStatus.unknown;
    }
  }
}

class AppTrackingTransparencyService {
  const AppTrackingTransparencyService._();

  static Future<AppTrackingAuthorizationStatus> authorizationStatus({
    MethodChannel channel = GenesisMethodChannels.device,
    TargetPlatform? platform,
  }) async {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    if (resolvedPlatform != TargetPlatform.iOS) {
      return AppTrackingAuthorizationStatus.notSupported;
    }
    try {
      final status = await channel.invokeMethod<String>(
        GenesisMethodChannels.trackingAuthorizationStatus,
      );
      return AppTrackingAuthorizationStatus.fromNativeValue(status);
    } on MissingPluginException {
      return AppTrackingAuthorizationStatus.unknown;
    } on PlatformException {
      return AppTrackingAuthorizationStatus.unknown;
    }
  }

  static Future<AppTrackingAuthorizationStatus> requestAuthorization({
    TargetPlatform? platform,
    AdjustTrackingAuthorizationRequester request =
        Adjust.requestAppTrackingAuthorization,
  }) async {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    if (resolvedPlatform != TargetPlatform.iOS) {
      return AppTrackingAuthorizationStatus.notSupported;
    }
    try {
      final status = await request();
      return AppTrackingAuthorizationStatus.fromAdjustValue(status);
    } on MissingPluginException {
      return AppTrackingAuthorizationStatus.unknown;
    } on PlatformException {
      return AppTrackingAuthorizationStatus.unknown;
    }
  }
}
