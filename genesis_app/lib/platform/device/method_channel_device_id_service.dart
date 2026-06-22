import 'dart:io';

import '../channels/genesis_method_channels.dart';
import 'device_id_service.dart';

class NativeDeviceIdService
    implements DeviceIdService, DeviceIdDiagnosticsService {
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

  String? _displayValue(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
