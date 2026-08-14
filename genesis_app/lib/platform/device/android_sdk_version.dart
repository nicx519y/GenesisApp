import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channels/genesis_method_channels.dart';

int? _cachedAndroidSdkInt;
Future<int?>? _pendingAndroidSdkInt;

int? get cachedAndroidSdkInt => _cachedAndroidSdkInt;

Future<int?> loadAndroidSdkInt() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return SynchronousFuture<int?>(null);
  }
  final cached = _cachedAndroidSdkInt;
  if (cached != null) return SynchronousFuture<int?>(cached);
  return _pendingAndroidSdkInt ??= _readAndroidSdkInt();
}

Future<int?> _readAndroidSdkInt() async {
  try {
    final sdkInt = await GenesisMethodChannels.device.invokeMethod<int>(
      GenesisMethodChannels.getAndroidSdkInt,
    );
    if (sdkInt != null && sdkInt > 0) _cachedAndroidSdkInt = sdkInt;
    return _cachedAndroidSdkInt;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } finally {
    _pendingAndroidSdkInt = null;
  }
}

@visibleForTesting
void resetAndroidSdkIntForTesting() {
  _cachedAndroidSdkInt = null;
  _pendingAndroidSdkInt = null;
}
