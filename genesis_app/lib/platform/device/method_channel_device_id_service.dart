import 'dart:io';

import '../channels/genesis_method_channels.dart';
import 'device_id_service.dart';

class NativeDeviceIdService
    implements
        DeviceIdService,
        DeviceIdDiagnosticsService,
        DeviceIdentitySnapshotService {
  const NativeDeviceIdService();

  @override
  Future<String> getDeviceId() async {
    final method = Platform.isAndroid
        ? GenesisMethodChannels.getAndroidId
        : GenesisMethodChannels.getDeviceId;
    final id = await GenesisMethodChannels.device.invokeMethod<String>(method);
    final value = (id ?? '').trim();
    return value.isEmpty ? 'unknown' : value;
  }

  @override
  Future<DeviceIdDiagnostics> getDeviceIdDiagnostics() async {
    if (!Platform.isAndroid) {
      return DeviceIdDiagnostics(deviceId: await getDeviceId());
    }

    final details = await GenesisMethodChannels.device
        .invokeMapMethod<String, String>(
          GenesisMethodChannels.getAndroidDeviceIdDiagnostics,
        );
    if (details == null) {
      return DeviceIdDiagnostics(deviceId: await getDeviceId());
    }

    return DeviceIdDiagnostics(
      androidId: _displayValue(details['android_id']),
      aaid: _displayValue(details['aaid']),
      deviceId: _displayValue(details['device_id']) ?? 'unknown',
    );
  }

  @override
  Future<DeviceIdentitySnapshot> getDeviceIdentitySnapshot() async {
    final details = await GenesisMethodChannels.device
        .invokeMapMethod<String, Object?>(
          GenesisMethodChannels.getDeviceIdentitySnapshot,
        );
    if (details == null) {
      return DeviceIdentitySnapshot(
        platform: Platform.isAndroid ? 'android' : 'ios',
        deviceId: await getDeviceId(),
        fields: const <String, Object?>{},
      );
    }
    final deviceId = '${details['device_id'] ?? ''}'.trim();
    final platform = '${details['platform'] ?? ''}'.trim();
    return DeviceIdentitySnapshot(
      platform: platform.isEmpty
          ? (Platform.isAndroid ? 'android' : 'ios')
          : platform,
      deviceId: deviceId.isEmpty ? await getDeviceId() : deviceId,
      fields: <String, Object?>{
        for (final entry in details.entries)
          if (entry.key != 'platform' && entry.key != 'device_id')
            entry.key: entry.value,
      },
    );
  }

  String? _displayValue(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
