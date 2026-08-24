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

class DeviceIdentitySnapshot {
  const DeviceIdentitySnapshot({
    required this.platform,
    required this.deviceId,
    required this.fields,
  });

  final String platform;
  final String deviceId;
  final Map<String, Object?> fields;
}

abstract interface class DeviceIdentitySnapshotService {
  Future<DeviceIdentitySnapshot> getDeviceIdentitySnapshot();
}
