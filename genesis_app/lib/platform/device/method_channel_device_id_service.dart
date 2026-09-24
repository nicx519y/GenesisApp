import 'dart:io';

import 'package:adjust_sdk/adjust.dart';

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
      final identifiers = await Future.wait<String?>([
        _readAdjustIdentifier(Adjust.getIdfa),
        _readAdjustIdentifier(Adjust.getIdfv),
      ]);
      return DeviceIdDiagnostics(
        deviceId: await getDeviceId(),
        idfa: identifiers[0],
        idfv: identifiers[1],
      );
    }

    final results = await Future.wait<Object?>([
      GenesisMethodChannels.device.invokeMapMethod<String, String>(
        GenesisMethodChannels.getAndroidDeviceIdDiagnostics,
      ),
      _readAdjustIdentifier(Adjust.getGoogleAdId),
    ]);
    final details = results[0] as Map<String, String>?;
    final gaid = results[1] as String?;
    if (details == null) {
      return DeviceIdDiagnostics(deviceId: await getDeviceId(), gaid: gaid);
    }

    return DeviceIdDiagnostics(
      androidId: _displayValue(details['android_id']),
      gaid: gaid,
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

  Future<String?> _readAdjustIdentifier(
    Future<String?> Function() reader,
  ) async {
    try {
      return _displayValue(await reader());
    } catch (_) {
      return null;
    }
  }
}
