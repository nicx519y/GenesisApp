import 'dart:io';

import '../channels/genesis_method_channels.dart';
import 'device_id_service.dart';

class NativeDeviceIdService implements DeviceIdService {
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
}
