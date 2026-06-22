abstract interface class DeviceIdService {
  Future<String> getDeviceId();
}

class DeviceIdDiagnostics {
  const DeviceIdDiagnostics({
    required this.deviceId,
    this.androidId,
    this.aaid,
  });

  final String deviceId;
  final String? androidId;
  final String? aaid;

  bool get hasAndroidBreakdown => androidId != null || aaid != null;
}

abstract interface class DeviceIdDiagnosticsService {
  Future<DeviceIdDiagnostics> getDeviceIdDiagnostics();
}
