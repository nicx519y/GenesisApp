import '../channels/genesis_method_channels.dart';

/// Reads the current Google Play services Advertising ID from Android.
Future<String?> readGoogleAdvertisingIdFromPlatform() => GenesisMethodChannels
    .device
    .invokeMethod<String>(GenesisMethodChannels.getGoogleAdvertisingId);
