import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channels/genesis_method_channels.dart';

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
    MethodChannel channel = GenesisMethodChannels.device,
    TargetPlatform? platform,
  }) async {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    if (resolvedPlatform != TargetPlatform.iOS) {
      return AppTrackingAuthorizationStatus.notSupported;
    }
    try {
      final status = await channel.invokeMethod<String>(
        GenesisMethodChannels.requestTrackingAuthorization,
      );
      return AppTrackingAuthorizationStatus.fromNativeValue(status);
    } on MissingPluginException {
      return AppTrackingAuthorizationStatus.unknown;
    } on PlatformException {
      return AppTrackingAuthorizationStatus.unknown;
    }
  }
}
